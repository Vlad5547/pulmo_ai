import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulmo_ai/services/image_preprocessor.dart';

/// Compares the Dart preprocessing with the Python pipeline the model was
/// trained and evaluated with, on the six fixture radiographs.
///
/// `test/fixtures/tensors/<name>.f32` holds the tensor produced by
/// `ai/src/data/preprocessing.py` for the same PNG — 50 176 little-endian
/// float32 values. Both sides then feed the same ONNX graph, so any difference
/// in the final probability originates here.
///
/// The test also writes the Dart tensors to `build/dart_tensors/` so the
/// Python side can measure their effect on the probability
/// (`ai` scripts, see ai/README.md).
void main() {
  const preprocessor = ImagePreprocessor(
    imageSize: 224,
    mean: 0.4932,
    std: 0.2458,
  );

  test('Dart preprocessing matches the Python pipeline', () async {
    final fixtures = Directory('test/fixtures');
    final expected = jsonDecode(
      File('${fixtures.path}/expected.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final images = (expected['images'] as List).cast<Map<String, dynamic>>();
    expect(images.length, greaterThanOrEqualTo(6));

    final dump = Directory('build/dart_tensors')..createSync(recursive: true);
    var worstElement = 0.0;
    var worstMean = 0.0;

    for (final item in images) {
      final name = item['file'] as String;
      final bytes = File('${fixtures.path}/$name').readAsBytesSync();
      final tensor = preprocessor.toModelInput(bytes);

      expect(tensor.length, 224 * 224);
      expect(tensor.every((v) => v.isFinite), isTrue);

      File('${dump.path}/$name.f32')
          .writeAsBytesSync(tensor.buffer.asUint8List());

      final referenceFile = File(
        '${fixtures.path}/tensors/${name.replaceAll('.png', '')}.f32',
      );
      expect(referenceFile.existsSync(), isTrue,
          reason: 'reference tensor for $name is missing');
      final reference = Float32List.view(
        Uint8List.fromList(referenceFile.readAsBytesSync()).buffer,
      );
      expect(reference.length, tensor.length);

      var maxDifference = 0.0;
      var sum = 0.0;
      for (var i = 0; i < tensor.length; i++) {
        final difference = (tensor[i] - reference[i]).abs();
        sum += difference;
        if (difference > maxDifference) maxDifference = difference;
      }
      final meanDifference = sum / tensor.length;
      worstElement = maxDifference > worstElement ? maxDifference : worstElement;
      worstMean = meanDifference > worstMean ? meanDifference : worstMean;

      debugPrint('$name  max |Δ| ${maxDifference.toStringAsExponential(3)}  '
          'mean |Δ| ${meanDifference.toStringAsExponential(3)}');
    }

    debugPrint('worst element difference: '
        '${worstElement.toStringAsExponential(3)}');
    debugPrint('worst mean difference   : '
        '${worstMean.toStringAsExponential(3)}');

    // The Dart triangle filter reproduces PyTorch to float32 rounding: the
    // measured worst element is ~5e-05 and the worst mean ~7e-07. The bounds
    // are set an order above that, so a regression in the resize (for example
    // falling back to the image package) fails the test immediately.
    expect(worstElement, lessThan(1e-3));
    expect(worstMean, lessThan(1e-5));
  });
}
