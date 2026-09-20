import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'dicom/dicom_decoder.dart';

/// A radiograph decoded to the one representation the model cares about:
/// a single grayscale plane in `[0, 1]`, row major, at full resolution.
class DecodedRadiograph {
  const DecodedRadiograph({
    required this.plane,
    required this.width,
    required this.height,
    required this.source,
    this.dicom,
  });

  /// Grayscale pixels in `[0, 1]`, row major, `width * height` long.
  final Float32List plane;
  final int width;
  final int height;
  final RadiographSource source;

  /// Header fields of the original DICOM, when the file was one.
  final DicomImage? dicom;

  bool get isDicom => source == RadiographSource.dicom;
}

enum RadiographSource { dicom, image }

/// Decides what a picked file actually is and decodes it.
///
/// Routing is by content, not by file extension: a `.dcm` that is really a PNG
/// and a DICOM saved without an extension both work. Everything the model sees
/// goes through here, so DICOM and PNG inputs cannot drift apart.
class RadiographDecoder {
  const RadiographDecoder({this._dicom = const DicomDecoder()});

  /// Injected so a test can make DICOM decoding fail on demand.
  final DicomDecoder _dicom;

  DecodedRadiograph decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const RadiographDecodeException(
        RadiographDecodeError.empty,
        'The file is empty.',
      );
    }

    if (DicomDecoder.looksLikeDicom(bytes)) {
      final DicomImage image;
      try {
        image = _dicom.decode(bytes);
      } on DicomException catch (error) {
        throw RadiographDecodeException(
          switch (error.error) {
            DicomError.notDicom => RadiographDecodeError.unsupportedFormat,
            DicomError.malformed => RadiographDecodeError.corrupt,
            DicomError.unsupported => RadiographDecodeError.unsupportedFormat,
          },
          error.message,
        );
      }
      return DecodedRadiograph(
        plane: image.plane,
        width: image.width,
        height: image.height,
        source: RadiographSource.dicom,
        dicom: image,
      );
    }

    final img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (error) {
      throw RadiographDecodeException(
        RadiographDecodeError.corrupt,
        'The file could not be decoded as an image ($error). '
        'Supported formats: DICOM, PNG, JPEG.',
      );
    }
    if (decoded == null) {
      throw const RadiographDecodeException(
        RadiographDecodeError.unsupportedFormat,
        'The file could not be decoded as an image. '
        'Supported formats: DICOM, PNG, JPEG.',
      );
    }
    if (decoded.width < 1 || decoded.height < 1) {
      throw const RadiographDecodeException(
        RadiographDecodeError.corrupt,
        'The image has no pixels.',
      );
    }

    return DecodedRadiograph(
      plane: readGrayscalePlane(decoded),
      width: decoded.width,
      height: decoded.height,
      source: RadiographSource.image,
    );
  }

  /// Full-resolution single channel in `[0, 1]`.
  ///
  /// Channel handling is explicit rather than delegated to
  /// `luminanceNormalized`: on a single-channel image that getter still weights
  /// three channels (g and b read as 0) and returns ~0.3 of the true value,
  /// while `img.grayscale()` truncates the weighted sum and biases every pixel
  /// by up to 1/255. A radiograph exported as 8-bit grayscale has to reach the
  /// model unchanged.
  static Float32List readGrayscalePlane(img.Image image) {
    final maxValue = image.maxChannelValue.toDouble();
    final single = image.numChannels == 1;
    final plane = Float32List(image.width * image.height);
    var index = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final value = single
            ? pixel.r.toDouble()
            : 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        plane[index++] = (value / maxValue).clamp(0.0, 1.0);
      }
    }
    return plane;
  }
}

/// Why a file could not be turned into a radiograph.
enum RadiographDecodeError {
  empty,

  /// Readable, but not a format this app understands.
  unsupportedFormat,

  /// The right format, but the bytes are damaged or truncated.
  corrupt,
}

class RadiographDecodeException implements Exception {
  const RadiographDecodeException(this.error, this.message);

  final RadiographDecodeError error;
  final String message;

  @override
  String toString() => message;
}
