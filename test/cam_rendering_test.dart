import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pulmo_ai/models/model_info.dart';
import 'package:pulmo_ai/services/cam_service.dart';

/// Renders the activation maps with the production Dart code, using the
/// feature maps the ONNX model produced on the desktop
/// (`build/cam_features/*.f32`, written by the Python side).
///
/// The PNGs land in `build/dart_cam/` so the Python check can compare them with
/// `ai/src/analysis/cam.py` pixel for pixel. Skipped when the features have not
/// been exported.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders the same activation map as the Python implementation', () async {
    final featureDir = Directory('build/cam_features');
    if (!featureDir.existsSync()) {
      markTestSkipped('run the Python feature export first');
      return;
    }

    final info = await ModelInfo.load();
    final service = CamService(
      weights: info.camWeights,
      gridSize: info.camGridSize,
    );
    final out = Directory('build/dart_cam')..createSync(recursive: true);

    final files = featureDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.f32'))
        .toList();
    expect(files, isNotEmpty);

    for (final file in files) {
      final name = file.uri.pathSegments.last.replaceAll('.f32', '');
      final raw = file.readAsBytesSync();
      final features = Float32List.view(
        Uint8List.fromList(raw).buffer,
      ).toList(growable: false);
      expect(features.length, 512 * 7 * 7);

      final map = service.computeMap(features);
      expect(map.length, 49);
      expect(map.every((v) => v.isFinite && v >= 0 && v <= 1), isTrue);

      final source = img.decodePng(File('test/fixtures/$name').readAsBytesSync())!;
      final png = service.renderOverlayPng(
        map,
        sourceWidth: source.width,
        sourceHeight: source.height,
      );
      File('${out.path}/$name').writeAsBytesSync(png);

      // the raw 7x7 map too, so the comparison is not clouded by rendering
      final mapBytes = Float32List.fromList(map).buffer.asUint8List();
      File('${out.path}/$name.map.f32').writeAsBytesSync(mapBytes);

      debugPrint('$name -> ${png.lengthInBytes ~/ 1024} KB overlay, '
          'peak ${map.reduce((a, b) => a > b ? a : b).toStringAsFixed(3)}');
    }
  });
}
