import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/models/analysis_result.dart';
import 'package:pulmo_ai/models/model_info.dart';
import 'package:pulmo_ai/services/cam_service.dart';

const grid = 7;
const channels = 4;

CamService serviceWith(List<double> weights) =>
    CamService(weights: Float32List.fromList(weights), gridSize: grid);

/// `[C, 7, 7]` flattened, channel `c` filled with `values[c]`.
List<double> featuresOf(List<double> values) => [
      for (final value in values) ...List<double>.filled(grid * grid, value),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CAM computation', () {
    test('output has the native grid shape and finite values', () {
      final service = serviceWith([1, 1, 1, 1]);
      final map = service.computeMap(featuresOf([0.5, 1.0, 0.25, 2.0]));

      expect(map.length, grid * grid);
      expect(map.every((v) => v.isFinite), isTrue);
    });

    test('is normalised to [0, 1] with the maximum at 1', () {
      final service = serviceWith([1, 0, 0, 0]);
      final features = featuresOf([0, 0, 0, 0]);
      // one hot spot in channel 0
      features[3 * grid + 4] = 8.0;
      features[0] = 2.0;

      final map = service.computeMap(features);

      expect(map.reduce((a, b) => a > b ? a : b), closeTo(1.0, 1e-6));
      expect(map.every((v) => v >= 0.0 && v <= 1.0), isTrue);
      expect(map[3 * grid + 4], closeTo(1.0, 1e-6));
      expect(map[0], closeTo(0.25, 1e-6));
    });

    test('weights the channels: cam = sum_k w_k * features_k', () {
      final service = serviceWith([2.0, -1.0, 0.0, 0.5]);
      final features = featuresOf([1.0, 1.0, 1.0, 1.0]);
      features[0] = 3.0; // channel 0 is brighter in the first cell

      final map = service.computeMap(features);
      // cell 0: 2*3 - 1*1 + 0 + 0.5 = 5.5 ; others: 2 - 1 + 0.5 = 1.5
      expect(map[0], closeTo(1.0, 1e-6));
      expect(map[1], closeTo(1.5 / 5.5, 1e-6));
    });

    test('negative evidence is clipped away (ReLU)', () {
      final service = serviceWith([-1.0, 0.0, 0.0, 0.0]);
      final map = service.computeMap(featuresOf([1.0, 0, 0, 0]));
      expect(map.every((v) => v == 0.0), isTrue);
    });

    test('rejects a feature map of the wrong size', () {
      final service = serviceWith([1, 1, 1, 1]);
      expect(
        () => service.computeMap(List<double>.filled(10, 1)),
        throwsA(isA<CamException>()),
      );
    });
  });

  group('overlay rendering', () {
    final service = serviceWith([1, 1, 1, 1]);
    final map = service.computeMap(featuresOf([0.2, 0.4, 0.6, 0.8]));

    test('keeps the aspect ratio of the source image', () {
      final wide = service.renderOverlayPng(map,
          sourceWidth: 1024, sourceHeight: 512, maxSide: 448);
      final decoded = img.decodePng(wide)!;
      expect(decoded.width, 448);
      expect(decoded.height, 224);
      expect(decoded.width / decoded.height, closeTo(1024 / 512, 1e-6));
    });

    test('square source gives a square overlay', () {
      final decoded = img.decodePng(
        service.renderOverlayPng(map,
            sourceWidth: 1024, sourceHeight: 1024, maxSide: 448),
      )!;
      expect(decoded.width, 448);
      expect(decoded.height, 448);
    });

    test('alpha follows the activation, so cold regions stay transparent', () {
      final hot = serviceWith([1, 0, 0, 0]);
      final features = featuresOf([0, 0, 0, 0]);
      features[0] = 1.0; // single hot cell in the top-left
      final rendered = hot.renderOverlayPng(
        hot.computeMap(features),
        sourceWidth: 256,
        sourceHeight: 256,
        maxSide: 224,
      );
      final decoded = img.decodePng(rendered)!;

      expect(decoded.numChannels, 4);
      final topLeft = decoded.getPixel(1, 1).a;
      final bottomRight =
          decoded.getPixel(decoded.width - 2, decoded.height - 2).a;
      expect(topLeft, greaterThan(bottomRight));
      expect(bottomRight, lessThan(20));
      expect(topLeft, lessThan(255), reason: 'the overlay stays translucent');
    });
  });

  group('result model', () {
    test('a result without a heatmap is still a valid result', () {
      const result = AnalysisResult(
        verdict: PneumoniaVerdict.pneumonia,
        confidence: 0.9,
        processingTime: Duration(milliseconds: 200),
      );
      expect(result.hasHeatmap, isFalse);
      expect(result.heatmapPng, isNull);
      expect(result.confidence, 0.9);
      expect(result.verdict.isPositive, isTrue);
    });

    test('a result carries the heatmap when one was produced', () {
      final result = AnalysisResult(
        verdict: PneumoniaVerdict.normal,
        confidence: 0.1,
        processingTime: const Duration(milliseconds: 200),
        heatmapPng: Uint8List.fromList([1, 2, 3]),
      );
      expect(result.hasHeatmap, isTrue);
    });
  });

  group('model card', () {
    test('supplies the CAM weights and grid the service needs', () async {
      final info = await ModelInfo.load();
      final service = CamService(
        weights: info.camWeights,
        gridSize: info.camGridSize,
      );

      expect(info.camWeights.length, 512);
      expect(info.camGridSize, 7);
      expect(info.camWeights.every((w) => w.isFinite), isTrue);

      final map = service.computeMap(
        List<double>.filled(512 * 7 * 7, 0.5),
      );
      expect(map.length, 49);
      expect(map.every((v) => v.isFinite && v >= 0 && v <= 1), isTrue);
    });
  });
}
