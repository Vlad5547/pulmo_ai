import 'dart:typed_data';

import 'radiograph_decoder.dart';

/// Turns a DICOM / PNG / JPEG into exactly the tensor PulmoNet-7M was trained
/// on.
///
/// The contract comes from the model card and mirrors the Python pipeline
/// (`ai/src/data/preprocessing.py`), step for step:
///
/// 1. decode and read a single grayscale channel ([RadiographDecoder]; for a
///    DICOM this also applies the MONOCHROME1 inversion and divides by the
///    maximum of the stored bit depth, exactly as `dicom_to_float_tensor`);
/// 2. resize to 224x224 with an **antialiased bilinear (triangle) filter**;
/// 3. scale to `[0, 1]` (divide by the channel maximum);
/// 4. normalise with the dataset statistics `(x - mean) / std`;
/// 5. lay out as `[1, 1, 224, 224]`, NCHW.
///
/// The resize is implemented here rather than taken from the `image` package on
/// purpose. Training used `F.interpolate(..., antialias=True)`, which convolves
/// a triangle kernel whose support scales with the downscale factor. The
/// package offers `Interpolation.linear` (four nearest source pixels - discards
/// ~95 % of a 1024-pixel radiograph) and `Interpolation.average` (a box
/// filter). Measured against the PyTorch output on the project fixtures, the
/// box filter is off by up to 0.17 of the pixel range and moves the predicted
/// probability by as much as 2.1e-2; the triangle filter below reproduces
/// PyTorch to ~5e-06. See `ai/README.md`, "Flutter integration".
class ImagePreprocessor {
  const ImagePreprocessor({
    required this.imageSize,
    required this.mean,
    required this.std,
  });

  final int imageSize;
  final double mean;
  final double std;

  /// Decoded, resized grayscale plane in `[0, 1]` - the input to [normalise],
  /// exposed separately so tests can inspect it.
  ///
  /// Accepts DICOM as well as PNG/JPEG: the routing lives in
  /// [RadiographDecoder], so both formats share this resize and normalisation
  /// and cannot drift apart.
  Float32List toGrayscaleUnitRange(Uint8List encoded) =>
      resizeDecoded(const RadiographDecoder().decode(encoded));

  /// Resizes an already-decoded plane to the model's square input.
  ///
  /// The inference path decodes the file once and reuses the result for the
  /// preview and the heatmap geometry, so nothing is decoded twice.
  Float32List resizeDecoded(DecodedRadiograph radiograph) => _resizeTriangle(
        radiograph.plane,
        radiograph.width,
        radiograph.height,
        imageSize,
        imageSize,
      );

  /// `(x - mean) / std`, in place.
  Float32List normalise(Float32List plane) {
    for (var i = 0; i < plane.length; i++) {
      plane[i] = (plane[i] - mean) / std;
    }
    return plane;
  }

  /// Full pipeline: encoded bytes -> `[1, 1, size, size]` NCHW tensor data.
  Float32List toModelInput(Uint8List encoded) =>
      normalise(toGrayscaleUnitRange(encoded));

  /// The shape that goes with [toModelInput].
  List<int> get inputShape => [1, 1, imageSize, imageSize];

  /// Width and height of the encoded image, before the resize. The activation
  /// map is rendered with this aspect ratio so it lines up with the radiograph.
  (int, int) sourceSize(Uint8List encoded) {
    final decoded = const RadiographDecoder().decode(encoded);
    return (decoded.width, decoded.height);
  }

  // -- internals ----------------------------------------------------------

  /// Separable antialiased bilinear resize - the same filter as
  /// `torch.nn.functional.interpolate(..., mode='bilinear', antialias=True)`.
  ///
  /// For every output pixel the kernel spans `support = max(scale, 1)` input
  /// pixels on each side, with triangular weights normalised to sum to 1. When
  /// upscaling (`scale < 1`) the support collapses to 1 and this degenerates to
  /// ordinary bilinear interpolation, which is what PyTorch does too.
  static Float32List _resizeTriangle(
    Float32List source,
    int sourceWidth,
    int sourceHeight,
    int targetWidth,
    int targetHeight,
  ) {
    final horizontal = _Kernel(sourceWidth, targetWidth);
    final vertical = _Kernel(sourceHeight, targetHeight);

    // pass 1: width  -> (sourceHeight x targetWidth)
    final intermediate = Float32List(sourceHeight * targetWidth);
    for (var y = 0; y < sourceHeight; y++) {
      final rowStart = y * sourceWidth;
      final outStart = y * targetWidth;
      for (var x = 0; x < targetWidth; x++) {
        final from = horizontal.starts[x];
        final to = horizontal.ends[x];
        final weightStart = horizontal.offsets[x];
        var sum = 0.0;
        for (var i = from; i < to; i++) {
          sum +=
              source[rowStart + i] * horizontal.weights[weightStart + i - from];
        }
        intermediate[outStart + x] = sum;
      }
    }

    // pass 2: height -> (targetHeight x targetWidth)
    final result = Float32List(targetHeight * targetWidth);
    for (var y = 0; y < targetHeight; y++) {
      final from = vertical.starts[y];
      final to = vertical.ends[y];
      final weightStart = vertical.offsets[y];
      final outStart = y * targetWidth;
      for (var x = 0; x < targetWidth; x++) {
        var sum = 0.0;
        for (var i = from; i < to; i++) {
          sum += intermediate[i * targetWidth + x] *
              vertical.weights[weightStart + i - from];
        }
        result[outStart + x] = sum;
      }
    }
    return result;
  }
}

/// Precomputed triangle-filter weights for one axis.
class _Kernel {
  _Kernel(int inputSize, int outputSize)
      : starts = Int32List(outputSize),
        ends = Int32List(outputSize),
        offsets = Int32List(outputSize) {
    final scale = inputSize / outputSize;
    final support = scale > 1.0 ? scale : 1.0;
    final collected = <double>[];

    for (var i = 0; i < outputSize; i++) {
      final center = (i + 0.5) * scale;
      final start = (center - support + 0.5).floor().clamp(0, inputSize);
      final end = (center + support + 0.5).floor().clamp(0, inputSize);
      starts[i] = start;
      ends[i] = end;
      offsets[i] = collected.length;

      var total = 0.0;
      final row = <double>[];
      for (var j = start; j < end; j++) {
        var weight = 1.0 - ((j + 0.5 - center) / support).abs();
        if (weight < 0) weight = 0;
        row.add(weight);
        total += weight;
      }
      if (total > 0) {
        for (var k = 0; k < row.length; k++) {
          row[k] /= total;
        }
      }
      collected.addAll(row);
    }
    weights = Float64List.fromList(collected);
  }

  final Int32List starts;
  final Int32List ends;
  final Int32List offsets;
  late final Float64List weights;
}
