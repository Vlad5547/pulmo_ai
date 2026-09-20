import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/services/image_source_service.dart';
import 'package:pulmo_ai/services/radiograph_decoder.dart';

/// Covers the step between "the user picked a file" and "the app has something
/// it can both display and analyse" — which for a DICOM are two different
/// things, and that is where this can go wrong.
void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('pulmoai_source_test');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  ImageSourceService service(PickFile picker) => ImageSourceService(
        filePicker: picker,
        cacheDirectory: () async => temp,
      );

  test('cancelling the picker yields null, not an error', () async {
    final picked = await service(() async => null).pickFile();
    expect(picked, isNull);
  });

  test('a PNG is used as-is: no preview copy is made', () async {
    final file = File('${temp.path}/x.png')..writeAsBytesSync(_png(8, 8));
    final picked = await service(() async => _platformFile(file)).pickFile();

    expect(picked, isNotNull);
    expect(picked!.isDicom, isFalse);
    expect(picked.displayPath, isNull);
    expect(picked.previewPath, file.path);
  });

  test('a DICOM keeps its own path for the model and gains a PNG preview',
      () async {
    final file = File('${temp.path}/study.dcm')
      ..writeAsBytesSync(_dicom(16, 16));
    final picked = await service(() async => _platformFile(file)).pickFile();

    expect(picked, isNotNull);
    expect(picked!.isDicom, isTrue);
    // The model still reads the DICOM itself...
    expect(picked.path, file.path);
    // ...while the UI gets a PNG, because no widget can draw a DICOM.
    expect(picked.displayPath, isNotNull);
    expect(picked.previewPath, isNot(file.path));

    final preview = File(picked.displayPath!);
    expect(preview.existsSync(), isTrue);
    final decoded = img.decodePng(preview.readAsBytesSync())!;
    expect(decoded.width, 16);
    expect(decoded.height, 16);
  });

  test('DICOM header fields come through for the study details', () async {
    final file = File('${temp.path}/study.dcm')
      ..writeAsBytesSync(_dicom(8, 8));
    final picked = await service(() async => _platformFile(file)).pickFile();

    expect(picked!.patientId, 'TEST-PATIENT');
    expect(picked.modality, 'CR');
  });

  test('an unreadable file raises a typed error the UI can phrase', () async {
    final file = File('${temp.path}/notes.txt')
      ..writeAsStringSync('this is not a radiograph');

    expect(
      () => service(() async => _platformFile(file)).pickFile(),
      throwsA(isA<RadiographDecodeException>()),
    );
  });

  test('a file the picker returns without a path is ignored', () async {
    // Happens on the web and for some cloud providers: there is a name but no
    // local file to read.
    const noPath = (name: 'remote.dcm', path: null);
    final picked = await service(() async => noPath).pickFile();
    expect(picked, isNull);
  });
}

PickedFile _platformFile(File file) =>
    (name: file.uri.pathSegments.last, path: file.path);

Uint8List _png(int width, int height) {
  final image = img.Image(width: width, height: height, numChannels: 1);
  return Uint8List.fromList(img.encodePng(image));
}

/// A minimal explicit-VR little-endian DICOM, uncompressed 8-bit.
Uint8List _dicom(int rows, int columns) {
  Uint8List u16(int v) =>
      (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List();
  Uint8List u32(int v) =>
      (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List();
  Uint8List ascii(String v) => Uint8List.fromList(
        v.length.isEven ? v.codeUnits : [...v.codeUnits, 0x20],
      );

  Uint8List element(int group, int el, String vr, Uint8List value) {
    final long = {'OB', 'OW'}.contains(vr);
    final out = BytesBuilder()
      ..add(u16(group))
      ..add(u16(el))
      ..add(Uint8List.fromList(vr.codeUnits));
    if (long) {
      out
        ..add(u16(0))
        ..add(u32(value.length));
    } else {
      out.add(u16(value.length));
    }
    out.add(value);
    return out.toBytes();
  }

  final out = BytesBuilder()
    ..add(Uint8List(128))
    ..add(Uint8List.fromList('DICM'.codeUnits))
    ..add(element(0x0002, 0x0010, 'UI', ascii('1.2.840.10008.1.2.1')))
    ..add(element(0x0008, 0x0060, 'CS', ascii('CR')))
    ..add(element(0x0010, 0x0020, 'LO', ascii('TEST-PATIENT')))
    ..add(element(0x0028, 0x0002, 'US', u16(1)))
    ..add(element(0x0028, 0x0004, 'CS', ascii('MONOCHROME2')))
    ..add(element(0x0028, 0x0010, 'US', u16(rows)))
    ..add(element(0x0028, 0x0011, 'US', u16(columns)))
    ..add(element(0x0028, 0x0100, 'US', u16(8)))
    ..add(element(0x0028, 0x0101, 'US', u16(8)))
    ..add(element(0x0028, 0x0103, 'US', u16(0)))
    ..add(element(0x7FE0, 0x0010, 'OW', Uint8List(rows * columns)));
  return out.toBytes();
}
