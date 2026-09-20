import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/services/dicom/dicom_decoder.dart';
import 'package:pulmo_ai/services/radiograph_decoder.dart';

/// Parser-level tests on DICOM files built here, byte by byte.
///
/// They are deliberately synthetic: the RSNA files cover exactly one shape
/// (8-bit, MONOCHROME2, JPEG baseline, 1024x1024), and the cases that actually
/// break a reader — MONOCHROME1, 16-bit pixels, implicit VR, a truncated file,
/// an unsupported transfer syntax — do not occur in that dataset at all.
void main() {
  group('header parsing', () {
    test('a file without the DICM marker is rejected as not a DICOM', () {
      final bytes = Uint8List(400);
      expect(DicomDecoder.looksLikeDicom(bytes), isFalse);
      expect(
        () => const DicomDecoder().decode(bytes),
        throwsA(
          isA<DicomException>()
              .having((e) => e.error, 'error', DicomError.notDicom),
        ),
      );
    });

    test('a PNG renamed to .dcm still decodes, by content not extension', () {
      final png = _grayPng(8, 8, 200);
      final decoded = const RadiographDecoder().decode(png);
      expect(decoded.isDicom, isFalse);
      expect(decoded.width, 8);
    });

    test('explicit VR little endian, uncompressed 8-bit', () {
      final pixels = Uint8List.fromList([0, 85, 170, 255]);
      final decoded = const DicomDecoder().decode(
        _dicom(rows: 2, columns: 2, pixels: pixels),
      );

      expect(decoded.width, 2);
      expect(decoded.height, 2);
      expect(decoded.bitsStored, 8);
      expect(decoded.plane[0], closeTo(0.0, 1e-6));
      expect(decoded.plane[1], closeTo(85 / 255, 1e-6));
      expect(decoded.plane[3], closeTo(1.0, 1e-6));
    });

    test('implicit VR little endian is read too', () {
      final decoded = const DicomDecoder().decode(
        _dicom(
          rows: 2,
          columns: 2,
          pixels: Uint8List.fromList([0, 85, 170, 255]),
          implicitVr: true,
        ),
      );
      expect(decoded.plane[1], closeTo(85 / 255, 1e-6));
    });

    test('MONOCHROME1 is inverted, like the Python pipeline', () {
      final decoded = const DicomDecoder().decode(
        _dicom(
          rows: 2,
          columns: 2,
          pixels: Uint8List.fromList([0, 85, 170, 255]),
          photometric: 'MONOCHROME1',
        ),
      );
      expect(decoded.plane[0], closeTo(1.0, 1e-6));
      expect(decoded.plane[3], closeTo(0.0, 1e-6));
    });

    test('16-bit pixels are scaled by the stored bit depth, not by 65535', () {
      // 12 bits stored in 16 allocated: the maximum is 4095, so a sample of
      // 4095 has to come out as pure white. Dividing by 65535 instead would
      // render the whole radiograph almost black.
      final pixels = Uint8List(8);
      ByteData.sublistView(pixels)
        ..setUint16(0, 0, Endian.little)
        ..setUint16(2, 2048, Endian.little)
        ..setUint16(4, 4095, Endian.little)
        ..setUint16(6, 1024, Endian.little);

      final decoded = const DicomDecoder().decode(
        _dicom(
          rows: 2,
          columns: 2,
          pixels: pixels,
          bitsAllocated: 16,
          bitsStored: 12,
        ),
      );
      expect(decoded.plane[2], closeTo(1.0, 1e-6));
      expect(decoded.plane[1], closeTo(2048 / 4095, 1e-6));
    });

    test('a sample above the declared bit depth does not blow out the scale',
        () {
      // Defensive rule shared with the Python pipeline: trust the data over
      // the header, otherwise a wrong BitsStored clips half the image to white.
      final pixels = Uint8List(4);
      ByteData.sublistView(pixels)
        ..setUint16(0, 0, Endian.little)
        ..setUint16(2, 8000, Endian.little);

      final decoded = const DicomDecoder().decode(
        _dicom(
          rows: 1,
          columns: 2,
          pixels: pixels,
          bitsAllocated: 16,
          bitsStored: 12,
        ),
      );
      expect(decoded.plane[1], closeTo(1.0, 1e-6));
    });
  });

  group('compressed pixel data', () {
    test('JPEG baseline inside encapsulated pixel data is decoded', () {
      final source = img.Image(width: 16, height: 16, numChannels: 1);
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 16; x++) {
          final v = (x * 16).clamp(0, 255);
          source.setPixelRgb(x, y, v, v, v);
        }
      }
      final jpeg = Uint8List.fromList(img.encodeJpg(source));

      final decoded = const DicomDecoder().decode(
        _dicom(
          rows: 16,
          columns: 16,
          pixels: jpeg,
          transferSyntax: '1.2.840.10008.1.2.4.50',
          encapsulated: true,
        ),
      );

      expect(decoded.width, 16);
      // Lossy at the edges, so compare loosely: the point is that the frame was
      // found, decoded and laid out in the right orientation.
      expect(decoded.plane[0], lessThan(0.2));
      expect(decoded.plane[15], greaterThan(0.8));
    });

    test('an unsupported transfer syntax is refused, not guessed at', () {
      expect(
        () => const DicomDecoder().decode(
          _dicom(
            rows: 2,
            columns: 2,
            pixels: Uint8List(4),
            // JPEG 2000: a real syntax this reader does not implement.
            transferSyntax: '1.2.840.10008.1.2.4.90',
            encapsulated: true,
          ),
        ),
        throwsA(
          isA<DicomException>()
              .having((e) => e.error, 'error', DicomError.unsupported),
        ),
      );
    });
  });

  group('damaged files', () {
    test('truncated pixel data is reported as malformed', () {
      final bytes = _dicom(
        rows: 64,
        columns: 64,
        pixels: Uint8List(10), // far short of 64*64
      );
      expect(
        () => const DicomDecoder().decode(bytes),
        throwsA(
          isA<DicomException>()
              .having((e) => e.error, 'error', DicomError.malformed),
        ),
      );
    });

    test('a file that stops after the header has no pixel data', () {
      final full = _dicom(rows: 2, columns: 2, pixels: Uint8List(4));
      final cut = Uint8List.sublistView(full, 0, 150);
      expect(
        () => const DicomDecoder().decode(cut),
        throwsA(
          isA<DicomException>()
              .having((e) => e.error, 'error', DicomError.malformed),
        ),
      );
    });

    test('a colour DICOM is refused rather than silently averaged', () {
      expect(
        () => const DicomDecoder().decode(
          _dicom(
            rows: 2,
            columns: 2,
            pixels: Uint8List(12),
            samplesPerPixel: 3,
          ),
        ),
        throwsA(
          isA<DicomException>()
              .having((e) => e.error, 'error', DicomError.unsupported),
        ),
      );
    });
  });

  test('a decoded DICOM renders to a PNG of the same size', () {
    final decoded = const DicomDecoder().decode(
      _dicom(rows: 4, columns: 4, pixels: Uint8List(16)),
    );
    final png = img.decodePng(decoded.toPng())!;
    expect(png.width, 4);
    expect(png.height, 4);
  });
}

// ---------------------------------------------------------------------------
// builders
// ---------------------------------------------------------------------------

/// Assembles a minimal but standard-conforming DICOM file.
Uint8List _dicom({
  required int rows,
  required int columns,
  required Uint8List pixels,
  String photometric = 'MONOCHROME2',
  String transferSyntax = '1.2.840.10008.1.2.1',
  int bitsAllocated = 8,
  int bitsStored = 8,
  int samplesPerPixel = 1,
  bool implicitVr = false,
  bool encapsulated = false,
}) {
  final out = BytesBuilder();
  out.add(Uint8List(128)); // preamble
  out.add(const AsciiEncoder().convert('DICM'));

  // The file meta group is always explicit VR little endian.
  if (implicitVr) transferSyntax = '1.2.840.10008.1.2';
  out.add(_explicit(0x0002, 0x0010, 'UI', _pad(transferSyntax)));

  Uint8List element(int group, int element_, String vr, Uint8List value) =>
      implicitVr
          ? _implicit(group, element_, value)
          : _explicit(group, element_, vr, value);

  out.add(element(0x0008, 0x0060, 'CS', _pad('CR')));
  out.add(element(0x0010, 0x0020, 'LO', _pad('TEST-PATIENT')));
  out.add(element(0x0028, 0x0002, 'US', _u16(samplesPerPixel)));
  out.add(element(0x0028, 0x0004, 'CS', _pad(photometric)));
  out.add(element(0x0028, 0x0010, 'US', _u16(rows)));
  out.add(element(0x0028, 0x0011, 'US', _u16(columns)));
  out.add(element(0x0028, 0x0100, 'US', _u16(bitsAllocated)));
  out.add(element(0x0028, 0x0101, 'US', _u16(bitsStored)));
  out.add(element(0x0028, 0x0103, 'US', _u16(0)));

  if (encapsulated) {
    // (7FE0,0010) OB, undefined length, then the basic offset table item and
    // one fragment item.
    final header = BytesBuilder()
      ..add(_u16(0x7FE0))
      ..add(_u16(0x0010))
      ..add(const AsciiEncoder().convert('OB'))
      ..add(_u16(0))
      ..add(_u32(0xFFFFFFFF))
      // empty basic offset table
      ..add(_u16(0xFFFE))
      ..add(_u16(0xE000))
      ..add(_u32(0))
      // the frame
      ..add(_u16(0xFFFE))
      ..add(_u16(0xE000))
      ..add(_u32(pixels.length))
      ..add(pixels)
      // sequence delimiter
      ..add(_u16(0xFFFE))
      ..add(_u16(0xE0DD))
      ..add(_u32(0));
    out.add(header.toBytes());
  } else {
    out.add(element(0x7FE0, 0x0010, 'OW', pixels));
  }
  return out.toBytes();
}

Uint8List _explicit(int group, int element, String vr, Uint8List value) {
  final long = {'OB', 'OW', 'OF', 'SQ', 'UT', 'UN'}.contains(vr);
  final out = BytesBuilder()
    ..add(_u16(group))
    ..add(_u16(element))
    ..add(const AsciiEncoder().convert(vr));
  if (long) {
    out
      ..add(_u16(0))
      ..add(_u32(value.length));
  } else {
    out.add(_u16(value.length));
  }
  out.add(value);
  return out.toBytes();
}

Uint8List _implicit(int group, int element, Uint8List value) => (BytesBuilder()
      ..add(_u16(group))
      ..add(_u16(element))
      ..add(_u32(value.length))
      ..add(value))
    .toBytes();

Uint8List _u16(int value) =>
    (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();

Uint8List _u32(int value) =>
    (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();

/// DICOM values have even length; strings are space padded.
Uint8List _pad(String value) {
  final bytes = const AsciiEncoder().convert(value);
  if (bytes.length.isEven) return bytes;
  return Uint8List.fromList([...bytes, 0x20]);
}

Uint8List _grayPng(int width, int height, int value) {
  final image = img.Image(width: width, height: height, numChannels: 1);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}
