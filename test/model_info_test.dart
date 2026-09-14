import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulmo_ai/models/model_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model card', () {
    test('parses the bundled asset', () async {
      final info = await ModelInfo.load();

      expect(info.name, 'PulmoNet-7M');
      expect(info.version, isNotEmpty);
      expect(info.parameterCount, 7065953);
      expect(info.threshold, 0.5);
      expect(info.imageSize, 224);
      expect(info.inputShape, [1, 1, 224, 224]);
      expect(info.inputName, 'input');
      expect(info.outputName, 'logit');
      expect(info.opset, 17);
      expect(info.precision, 'fp32');
    });

    test('carries the training normalisation statistics', () async {
      final info = await ModelInfo.load();
      // These must match ai/src/config.py - the model was trained with them.
      expect(info.mean, closeTo(0.4932, 1e-9));
      expect(info.std, closeTo(0.2458, 1e-9));
    });

    test('carries the measured test metrics unchanged', () async {
      final metrics = (await ModelInfo.load()).testMetrics;

      expect(metrics.rocAuc, closeTo(0.8739, 1e-9));
      expect(metrics.auprc, closeTo(0.6794, 1e-9));
      expect(metrics.accuracy, closeTo(0.7779, 1e-9));
      expect(metrics.recall, closeTo(0.8293, 1e-9));
      expect(metrics.precision, closeTo(0.5228, 1e-9));
      expect(metrics.f1, closeTo(0.6413, 1e-9));
    });

    test('the card describes the model file that actually ships', () async {
      final card = jsonDecode(
        await rootBundle.loadString(ModelInfo.defaultCardPath),
      ) as Map<String, dynamic>;
      final bytes = await rootBundle.load(ModelInfo.defaultAssetPath);

      expect(card['exported_file'], 'pulmonet7m.onnx');
      expect(bytes.lengthInBytes, greaterThan(20 * 1024 * 1024));
      expect(card['sha256'], isA<String>());
    });

    test('formats a display name and a technical summary', () async {
      final info = await ModelInfo.load();
      expect(info.displayName, startsWith('PulmoNet-7M v'));
      expect(info.technicalSummary, contains('opset 17'));
      expect(info.technicalSummary, contains('7 065 953'));
    });
  });
}
