import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Minimal DICOM reader for single-frame grayscale radiographs.
///
/// This is deliberately not a general DICOM library. It reads exactly what the
/// model needs — geometry, bit depth, photometric interpretation and the pixel
/// plane — and refuses anything it cannot interpret correctly rather than
/// guessing. A wrong guess here would silently shift every pixel and change the
/// prediction, which is worse than a clear error message.
///
/// Supported transfer syntaxes:
///
/// * `1.2.840.10008.1.2`      implicit VR little endian, uncompressed
/// * `1.2.840.10008.1.2.1`    explicit VR little endian, uncompressed
/// * `1.2.840.10008.1.2.4.50` JPEG baseline (what the RSNA 2018 set uses)
///
/// The pixel plane is returned in `[0, 1]`, scaled by the maximum of the stored
/// bit depth and inverted for MONOCHROME1 — the same two rules as
/// `ai/src/data/preprocessing.py::dicom_to_float_tensor`, so a DICOM opened in
/// the app reaches the model as the identical tensor it would have during
/// training.
class DicomDecoder {
  const DicomDecoder();

  static const String _implicitVrLittleEndian = '1.2.840.10008.1.2';
  static const String _explicitVrLittleEndian = '1.2.840.10008.1.2.1';
  static const String _jpegBaseline = '1.2.840.10008.1.2.4.50';

  /// Transfer syntaxes this decoder can read.
  static const Set<String> supportedTransferSyntaxes = {
    _implicitVrLittleEndian,
    _explicitVrLittleEndian,
    _jpegBaseline,
  };

  /// True when [bytes] carries the "DICM" magic at offset 128.
  ///
  /// Used to route a picked file, so a `.dcm` extension is never trusted on its
  /// own and a DICOM without the extension still works.
  static bool looksLikeDicom(Uint8List bytes) {
    if (bytes.length < 132) return false;
    return bytes[128] == 0x44 && // D
        bytes[129] == 0x49 && // I
        bytes[130] == 0x43 && // C
        bytes[131] == 0x4D; //  M
  }

  /// Reads [bytes] into a grayscale plane in `[0, 1]`, row major.
  ///
  /// Throws [DicomException] with a message meant for the user when the file is
  /// not a DICOM, is truncated, or uses a feature this reader does not support.
  DicomImage decode(Uint8List bytes) {
    if (!looksLikeDicom(bytes)) {
      throw const DicomException(
        DicomError.notDicom,
        'The file is not a DICOM image (the DICM marker is missing).',
      );
    }

    final data = ByteData.sublistView(bytes);
    final header = _readDataSet(bytes, data);

    final rows = header.rows;
    final columns = header.columns;
    if (rows == null || columns == null || rows <= 0 || columns <= 0) {
      throw const DicomException(
        DicomError.malformed,
        'The DICOM file does not declare its image size.',
      );
    }
    if (header.samplesPerPixel != 1) {
      throw DicomException(
        DicomError.unsupported,
        'Only single-channel radiographs are supported; this file stores '
        '${header.samplesPerPixel} samples per pixel.',
      );
    }
    if (header.pixelData == null) {
      throw const DicomException(
        DicomError.malformed,
        'The DICOM file contains no pixel data.',
      );
    }
    if (!supportedTransferSyntaxes.contains(header.transferSyntaxUid)) {
      throw DicomException(
        DicomError.unsupported,
        'Transfer syntax ${header.transferSyntaxUid} is not supported. '
        'Supported: uncompressed little endian and JPEG baseline.',
      );
    }
    if (header.encapsulated && header.bitsStored > 8) {
      throw DicomException(
        DicomError.unsupported,
        'Compressed ${header.bitsStored}-bit pixel data is not supported.',
      );
    }

    final plane = header.encapsulated
        ? _decodeJpegPlane(header, rows, columns)
        : _decodeNativePlane(header, rows, columns);

    return DicomImage(
      plane: plane,
      width: columns,
      height: rows,
      bitsStored: header.bitsStored,
      photometricInterpretation: header.photometricInterpretation,
      transferSyntaxUid: header.transferSyntaxUid,
      patientId: header.patientId,
      studyDate: header.studyDate,
      viewPosition: header.viewPosition,
      modality: header.modality,
    );
  }

  // -- pixel decoding -----------------------------------------------------

  Float32List _decodeNativePlane(_Header header, int rows, int columns) {
    final pixels = header.pixelData!;
    final count = rows * columns;
    final bitsAllocated = header.bitsAllocated;
    final expected = count * (bitsAllocated ~/ 8);
    if (pixels.lengthInBytes < expected) {
      throw DicomException(
        DicomError.malformed,
        'The pixel data is truncated: expected $expected bytes for '
        '${columns}x$rows at $bitsAllocated bits, got ${pixels.lengthInBytes}.',
      );
    }

    final plane = Float32List(count);
    final maxValue = _maxValue(header, () {
      // Peek at the real maximum so a header that understates the bit depth
      // cannot brighten the whole image.
      var observed = 0.0;
      final view = ByteData.sublistView(pixels);
      for (var i = 0; i < count; i++) {
        final value = bitsAllocated == 16
            ? (header.signed
                    ? view.getInt16(i * 2, Endian.little)
                    : view.getUint16(i * 2, Endian.little))
                .toDouble()
            : pixels[i].toDouble();
        if (value > observed) observed = value;
      }
      return observed;
    });

    final view = ByteData.sublistView(pixels);
    for (var i = 0; i < count; i++) {
      final raw = bitsAllocated == 16
          ? (header.signed
                  ? view.getInt16(i * 2, Endian.little)
                  : view.getUint16(i * 2, Endian.little))
              .toDouble()
          : pixels[i].toDouble();
      plane[i] = (raw / maxValue).clamp(0.0, 1.0);
    }
    return _applyPhotometric(plane, header);
  }

  Float32List _decodeJpegPlane(_Header header, int rows, int columns) {
    final frame = header.pixelData!;
    final img.Image? decoded;
    try {
      decoded = img.decodeJpg(frame);
    } catch (error) {
      throw DicomException(
        DicomError.unsupported,
        'The embedded JPEG frame could not be decoded ($error).',
      );
    }
    if (decoded == null) {
      throw const DicomException(
        DicomError.unsupported,
        'The embedded JPEG frame could not be decoded.',
      );
    }
    if (decoded.width != columns || decoded.height != rows) {
      throw DicomException(
        DicomError.malformed,
        'The embedded frame is ${decoded.width}x${decoded.height} but the '
        'header declares ${columns}x$rows.',
      );
    }

    final count = rows * columns;
    final plane = Float32List(count);
    // A baseline JPEG inside a MONOCHROME1/2 DICOM is grayscale, so every
    // channel carries the same value and reading red is exact — and, unlike a
    // luminance weighting, it is lossless.
    final maxChannel = decoded.maxChannelValue.toDouble();
    var index = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        plane[index++] =
            (decoded.getPixel(x, y).r.toDouble() / maxChannel).clamp(0.0, 1.0);
      }
    }
    return _applyPhotometric(plane, header);
  }

  double _maxValue(_Header header, double Function() observedMax) {
    final declared = (1 << (header.bitsStored.clamp(1, 32))) - 1;
    var maxValue = declared.toDouble();
    final observed = observedMax();
    // Defensive, and the same rule as the Python pipeline: trust the data over
    // the header when the two disagree.
    if (observed > maxValue) maxValue = observed;
    return maxValue <= 0 ? 1.0 : maxValue;
  }

  Float32List _applyPhotometric(Float32List plane, _Header header) {
    if (header.photometricInterpretation.toUpperCase() == 'MONOCHROME1') {
      for (var i = 0; i < plane.length; i++) {
        plane[i] = 1.0 - plane[i];
      }
    }
    return plane;
  }

  // -- parsing ------------------------------------------------------------

  _Header _readDataSet(Uint8List bytes, ByteData data) {
    final header = _Header();
    var offset = 132; // 128-byte preamble + "DICM"

    // The file meta group (0002,xxxx) is always explicit VR little endian,
    // whatever the transfer syntax of the data set that follows it.
    var explicitVr = true;
    var inFileMeta = true;

    while (offset + 8 <= bytes.length) {
      final group = data.getUint16(offset, Endian.little);
      final element = data.getUint16(offset + 2, Endian.little);
      offset += 4;

      if (inFileMeta && group != 0x0002) {
        inFileMeta = false;
        explicitVr = header.transferSyntaxUid != _implicitVrLittleEndian;
      }

      String vr;
      int length;
      if (explicitVr) {
        if (offset + 4 > bytes.length) break;
        vr = String.fromCharCodes(bytes, offset, offset + 2);
        if (_vrWithLongLength.contains(vr)) {
          if (offset + 8 > bytes.length) break;
          length = data.getUint32(offset + 4, Endian.little);
          offset += 8;
        } else {
          length = data.getUint16(offset + 2, Endian.little);
          offset += 4;
        }
      } else {
        if (offset + 4 > bytes.length) break;
        vr = _implicitVrFor(group, element);
        length = data.getUint32(offset, Endian.little);
        offset += 4;
      }

      if (group == 0x7FE0 && element == 0x0010) {
        header.pixelData = length == 0xFFFFFFFF
            ? _readEncapsulatedFrame(bytes, data, offset)
            : Uint8List.sublistView(bytes, offset, offset + length);
        header.encapsulated = length == 0xFFFFFFFF;
        return header;
      }

      if (length == 0xFFFFFFFF) {
        // A sequence of undefined length; skip to its delimiter. Nothing the
        // model needs lives inside one for these images.
        offset = _skipUndefinedLengthItem(bytes, data, offset);
        continue;
      }
      if (offset + length > bytes.length) break;

      _assign(header, group, element, bytes, offset, length);
      offset += length;
      if (length.isOdd) offset += 1; // DICOM pads values to even length
    }

    return header;
  }

  void _assign(_Header header, int group, int element, Uint8List bytes,
      int offset, int length) {
    String text() =>
        String.fromCharCodes(bytes, offset, offset + length).trim().replaceAll(
              ' ',
              '',
            );
    int number() {
      if (length < 2) return 0;
      return ByteData.sublistView(bytes).getUint16(offset, Endian.little);
    }

    if (group == 0x0002 && element == 0x0010) {
      header.transferSyntaxUid = text();
    } else if (group == 0x0008 && element == 0x0060) {
      header.modality = text();
    } else if (group == 0x0008 && element == 0x0020) {
      header.studyDate = text();
    } else if (group == 0x0010 && element == 0x0020) {
      header.patientId = text();
    } else if (group == 0x0018 && element == 0x5101) {
      header.viewPosition = text();
    } else if (group == 0x0028) {
      switch (element) {
        case 0x0002:
          header.samplesPerPixel = number();
        case 0x0004:
          header.photometricInterpretation = text();
        case 0x0010:
          header.rows = number();
        case 0x0011:
          header.columns = number();
        case 0x0100:
          header.bitsAllocated = number();
        case 0x0101:
          header.bitsStored = number();
        case 0x0103:
          header.signed = number() == 1;
      }
    }
  }

  /// Concatenated fragments of the first frame of encapsulated pixel data.
  ///
  /// Layout per PS3.5 A.4: the first item is always the basic offset table
  /// (often zero-length), then one item per fragment. Single-frame radiographs
  /// use one fragment; the loop still joins several, which the standard allows.
  Uint8List _readEncapsulatedFrame(
      Uint8List bytes, ByteData data, int offset) {
    final fragments = <Uint8List>[];
    var cursor = offset;
    var isOffsetTable = true;
    while (cursor + 8 <= bytes.length) {
      final group = data.getUint16(cursor, Endian.little);
      final element = data.getUint16(cursor + 2, Endian.little);
      final length = data.getUint32(cursor + 4, Endian.little);
      cursor += 8;
      if (group == 0xFFFE && element == 0xE0DD) break; // sequence delimiter
      if (group != 0xFFFE || element != 0xE000) break; // not an item
      if (cursor + length > bytes.length) break;
      if (isOffsetTable) {
        isOffsetTable = false;
      } else if (length > 0) {
        fragments.add(Uint8List.sublistView(bytes, cursor, cursor + length));
      }
      cursor += length;
    }

    if (fragments.isEmpty) {
      throw const DicomException(
        DicomError.malformed,
        'The DICOM file declares compressed pixel data but contains no frame.',
      );
    }
    if (fragments.length == 1) return fragments.first;

    final total = fragments.fold<int>(0, (sum, f) => sum + f.length);
    final joined = Uint8List(total);
    var at = 0;
    for (final fragment in fragments) {
      joined.setAll(at, fragment);
      at += fragment.length;
    }
    return joined;
  }

  int _skipUndefinedLengthItem(Uint8List bytes, ByteData data, int offset) {
    var cursor = offset;
    var depth = 1;
    while (cursor + 8 <= bytes.length && depth > 0) {
      final group = data.getUint16(cursor, Endian.little);
      final element = data.getUint16(cursor + 2, Endian.little);
      final length = data.getUint32(cursor + 4, Endian.little);
      cursor += 8;
      if (group == 0xFFFE && element == 0xE0DD) {
        depth -= 1;
      } else if (length == 0xFFFFFFFF) {
        depth += 1;
      } else {
        cursor += length;
      }
    }
    return cursor;
  }

  static String _implicitVrFor(int group, int element) {
    if (group == 0x7FE0 && element == 0x0010) return 'OW';
    if (group == 0x0028) return 'US';
    return 'UN';
  }

  /// VRs whose explicit form carries a 32-bit length after two reserved bytes.
  static const Set<String> _vrWithLongLength = {
    'OB',
    'OD',
    'OF',
    'OL',
    'OW',
    'SQ',
    'UC',
    'UR',
    'UT',
    'UN',
  };
}

/// The handful of header fields this reader needs, filled in while parsing.
///
/// Defaults match the DICOM standard's own defaults, so a file that omits an
/// optional attribute is still read the way a conforming viewer would read it.
class _Header {
  int? rows;
  int? columns;
  int samplesPerPixel = 1;
  int bitsAllocated = 8;
  int bitsStored = 8;
  bool signed = false;
  String photometricInterpretation = 'MONOCHROME2';
  String transferSyntaxUid = DicomDecoder._explicitVrLittleEndian;
  String? patientId;
  String? studyDate;
  String? viewPosition;
  String? modality;

  /// Raw pixel bytes (uncompressed) or the joined compressed frame.
  Uint8List? pixelData;

  /// True when [pixelData] holds a compressed frame rather than raw pixels.
  bool encapsulated = false;
}

/// One decoded single-frame radiograph plus the header fields worth showing.
class DicomImage {
  const DicomImage({
    required this.plane,
    required this.width,
    required this.height,
    required this.bitsStored,
    required this.photometricInterpretation,
    required this.transferSyntaxUid,
    this.patientId,
    this.studyDate,
    this.viewPosition,
    this.modality,
  });

  /// Grayscale pixels in `[0, 1]`, row major, photometric correction applied.
  final Float32List plane;
  final int width;
  final int height;
  final int bitsStored;
  final String photometricInterpretation;
  final String transferSyntaxUid;
  final String? patientId;
  final String? studyDate;
  final String? viewPosition;
  final String? modality;

  /// 8-bit PNG of the plane, so the radiograph can be shown and stored like any
  /// other image once the DICOM container is gone.
  Uint8List toPng() {
    final image = img.Image(width: width, height: height, numChannels: 1);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = (plane[y * width + x] * 255).round().clamp(0, 255);
        image.setPixelRgb(x, y, value, value, value);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }
}

/// What went wrong, so the UI can say something useful instead of "error".
enum DicomError {
  /// No DICM marker — the user picked some other file.
  notDicom,

  /// A DICOM, but broken or truncated.
  malformed,

  /// A valid DICOM this reader cannot handle (compression, multi-channel).
  unsupported,
}

class DicomException implements Exception {
  const DicomException(this.error, this.message);

  final DicomError error;
  final String message;

  @override
  String toString() => message;
}
