import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Builds a class activation map from the model's own feature map.
///
/// The network ends in *global average pooling → Linear(512, 1)*, so the
/// contribution of each spatial position to the logit is available directly:
///
/// ```
/// cam[y, x] = Σ_k weight[k] · features[k, y, x]
/// ```
///
/// where `weight` are the 512 classifier weights shipped in the model card.
/// The map is then ReLU-ed (only evidence *for* the positive class is shown),
/// divided by its own maximum and upsampled to the size of the radiograph.
/// This is the same computation as `ai/src/analysis/cam.py`; the Python and
/// Dart results agree to ~1e-06.
///
/// **What the map is:** the regions the model's decision function responded to.
/// **What it is not:** evidence of disease localisation, a lesion outline, or a
/// diagnosis. Its native resolution is 7×7 — about 32 px of the 224 px input —
/// so it can indicate a region, never a boundary.
class CamService {
  const CamService({required this.weights, this.gridSize = 7});

  /// Classifier weights, one per feature channel.
  final Float32List weights;

  /// Native CAM resolution (the feature map is `gridSize × gridSize`).
  final int gridSize;

  /// `features` is the flattened `[1, C, gridSize, gridSize]` ONNX output.
  ///
  /// Returns the normalised map in `[0, 1]`, `gridSize × gridSize`, row major.
  Float32List computeMap(List<double> features) {
    final channels = weights.length;
    final area = gridSize * gridSize;
    if (features.length != channels * area) {
      throw CamException(
        'Feature map has ${features.length} values, expected '
        '${channels * area} for $channels x $gridSize x $gridSize.',
      );
    }

    final map = Float32List(area);
    for (var c = 0; c < channels; c++) {
      final weight = weights[c];
      if (weight == 0) continue;
      final offset = c * area;
      for (var i = 0; i < area; i++) {
        map[i] += weight * features[offset + i];
      }
    }

    var peak = 0.0;
    for (var i = 0; i < area; i++) {
      if (map[i] < 0) map[i] = 0; // ReLU: evidence for the positive class only
      if (map[i] > peak) peak = map[i];
    }
    if (peak > 0) {
      for (var i = 0; i < area; i++) {
        map[i] /= peak;
      }
    }
    if (map.any((value) => !value.isFinite)) {
      throw const CamException('The activation map contains NaN or Inf.');
    }
    return map;
  }

  /// Renders the map as a translucent PNG the UI can lay over the radiograph.
  ///
  /// The output keeps the **aspect ratio of the source image**, so the overlay
  /// lines up with the X-ray under the same `BoxFit`. Alpha grows with the
  /// activation, so cold regions stay transparent instead of tinting the whole
  /// radiograph.
  Uint8List renderOverlayPng(
    Float32List map, {
    required int sourceWidth,
    required int sourceHeight,
    int maxSide = 448,
  }) {
    final scale = maxSide / math.max(sourceWidth, sourceHeight);
    final width = math.max(1, (sourceWidth * scale).round());
    final height = math.max(1, (sourceHeight * scale).round());

    final image = img.Image(width: width, height: height, numChannels: 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final value = _sampleBilinear(
          map,
          (x + 0.5) / width * gridSize - 0.5,
          (y + 0.5) / height * gridSize - 0.5,
        );
        final colour = _inferno(value);
        image.setPixelRgba(
          x,
          y,
          colour.$1,
          colour.$2,
          colour.$3,
          // 0 at the cold end, ~0.72 at the peak
          (value.clamp(0.0, 1.0) * 184).round(),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  double _sampleBilinear(Float32List map, double fx, double fy) {
    final x0 = fx.floor();
    final y0 = fy.floor();
    final tx = fx - x0;
    final ty = fy - y0;

    double at(int x, int y) {
      final cx = x.clamp(0, gridSize - 1);
      final cy = y.clamp(0, gridSize - 1);
      return map[cy * gridSize + cx];
    }

    final top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx;
    final bottom = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx;
    return (top * (1 - ty) + bottom * ty).clamp(0.0, 1.0);
  }

  /// Perceptually ordered dark→bright ramp, matching the Python figures.
  (int, int, int) _inferno(double t) {
    const stops = <(double, int, int, int)>[
      (0.00, 0, 0, 4),
      (0.25, 87, 16, 110),
      (0.50, 188, 55, 84),
      (0.75, 249, 142, 9),
      (1.00, 252, 255, 164),
    ];
    final value = t.clamp(0.0, 1.0);
    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      if (value <= b.$1) {
        final span = b.$1 - a.$1;
        final k = span == 0 ? 0.0 : (value - a.$1) / span;
        return (
          (a.$2 + (b.$2 - a.$2) * k).round(),
          (a.$3 + (b.$3 - a.$3) * k).round(),
          (a.$4 + (b.$4 - a.$4) * k).round(),
        );
      }
    }
    final last = stops.last;
    return (last.$2, last.$3, last.$4);
  }
}

/// Raised when the activation map cannot be built. Classification is never
/// blocked by it — the caller reports the probability regardless.
class CamException implements Exception {
  const CamException(this.message);

  final String message;

  @override
  String toString() => message;
}
