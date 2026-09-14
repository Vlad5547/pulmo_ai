import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pulmo_ai/models/analysis_result.dart';
import 'package:pulmo_ai/models/xray_image.dart';
import 'package:pulmo_ai/services/onnx_analysis_service.dart';

/// End-to-end check of the on-device pipeline against the desktop reference.
///
/// The test body runs **on the target device**, so `test/fixtures` from the
/// host repository is not visible to it. On a phone push the fixtures once:
///
///     adb shell mkdir -p /data/local/tmp/pulmoai_fixtures
///     adb push test/fixtures/509903.png /data/local/tmp/pulmoai_fixtures/
///     ... (the six PNGs and expected.json)
///     flutter test integration_test -d <android-device-id>
///
/// `/data/local/tmp` is used rather than the app's own storage because
/// `flutter test` reinstalls the app on every run, which wipes app data.
///
/// On a desktop target the host path is used directly and no push is needed:
///
///     flutter test integration_test -d windows
///
/// The fixtures are lossless PNG exports of six test-split DICOM files, and
/// `expected.json` holds the probabilities the exported ONNX model produces for
/// them in Python. Any difference measured here comes from the Dart
/// preprocessing, since both sides run the same graph.
///
/// Nothing is trained, tuned or written: the model asset and the fixtures are
/// read-only inputs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> expected;
  late Directory fixtures;

  /// Where the fixtures can live, in priority order:
  /// the host repository (desktop targets) and the app's external files
  /// directory (Android, populated with `adb push`).
  setUpAll(() async {
    // The test body runs on the target device. On a desktop target the host
    // repository is the working directory; on Android the fixtures have to be
    // pushed into the app-specific storage directory, whose real path can only
    // come from the platform (a hard-coded /sdcard/... path is refused by
    // scoped storage on Android 11+).
    final candidates = <String>[
      'test/fixtures',
      // `flutter test` reinstalls the app for every run, which wipes the
      // app-specific storage, so the fixtures live in the shell tmp directory
      // instead: it survives reinstalls and the app can read it (the directory
      // is world-traversable and the files are world-readable).
      if (Platform.isAndroid) '/data/local/tmp/pulmoai_fixtures',
      if (Platform.isAndroid)
        '${(await getExternalStorageDirectory())?.path}/fixtures',
    ];

    Directory? found;
    for (final path in candidates) {
      final directory = Directory(path);
      if (directory.existsSync() && File('$path/expected.json').existsSync()) {
        found = directory;
        break;
      }
    }
    expect(
      found,
      isNotNull,
      reason: 'Fixtures not found. Looked in: ${candidates.join(", ")}. '
          'On Android push them first: adb push test/fixtures/<file> '
          '/data/local/tmp/pulmoai_fixtures/',
    );
    fixtures = found!;
    debugPrint('fixtures   : ${fixtures.path}');
    expected = jsonDecode(
      await File('${fixtures.path}/expected.json').readAsString(),
    ) as Map<String, dynamic>;
  });

  testWidgets('PNG -> preprocessing -> ONNX matches the desktop reference',
      (tester) async {
    final service = OnnxAnalysisService();

    // --- warm-up ---------------------------------------------------------
    final warmUpWatch = Stopwatch()..start();
    await service.warmUp();
    warmUpWatch.stop();
    expect(service.isReady, isTrue);
    final info = service.modelInfo!;

    // a second call must not open a second session
    final secondWatch = Stopwatch()..start();
    await service.warmUp();
    secondWatch.stop();

    debugPrint('=== PulmoAI on-device inference =========================');
    debugPrint('model      : ${info.displayName} (${info.technicalSummary})');
    debugPrint('threshold  : ${info.threshold}');
    debugPrint('warm-up    : ${warmUpWatch.elapsedMilliseconds} ms '
        '(second call ${secondWatch.elapsedMilliseconds} ms)');
    debugPrint('---------------------------------------------------------');

    // --- per-image comparison -------------------------------------------
    final images = (expected['images'] as List).cast<Map<String, dynamic>>();
    expect(images.length, greaterThanOrEqualTo(6));

    var maxDifference = 0.0;
    var totalDifference = 0.0;
    final inferenceMs = <int>[];

    for (final item in images) {
      final file = File('${fixtures.path}/${item['file']}');
      expect(file.existsSync(), isTrue, reason: '${item['file']} is missing');

      final watch = Stopwatch()..start();
      final result = await service.analyze(
        XRayImage(name: item['file'] as String, path: file.path),
      );
      watch.stop();
      inferenceMs.add(watch.elapsedMilliseconds);

      final reference = (item['probability_from_png'] as num).toDouble();
      final difference = (result.confidence - reference).abs();
      maxDifference = difference > maxDifference ? difference : maxDifference;
      totalDifference += difference;

      final expectedVerdict = reference >= info.threshold
          ? PneumoniaVerdict.pneumonia
          : PneumoniaVerdict.normal;

      debugPrint(
        '${(item['true_class'] as String).padRight(30)} '
        '${(item['file'] as String).padRight(15)} '
        'desktop ${reference.toStringAsFixed(6)}  '
        'flutter ${result.confidence.toStringAsFixed(6)}  '
        'diff ${difference.toStringAsExponential(2)}  '
        '${result.verdict.label}  ${watch.elapsedMilliseconds} ms',
      );

      expect(result.confidence, inInclusiveRange(0.0, 1.0));
      expect(result.modelName, 'PulmoNet-7M');
      expect(result.boxes, isEmpty);
      expect(result.processingTime.inMilliseconds, greaterThan(0));
      expect(result.verdict, expectedVerdict,
          reason: 'the verdict must not flip relative to the desktop run');
    }

    inferenceMs.sort();
    debugPrint('---------------------------------------------------------');
    debugPrint('images      : ${images.length}');
    debugPrint('max diff    : ${maxDifference.toStringAsExponential(3)}');
    debugPrint('mean diff   : '
        '${(totalDifference / images.length).toStringAsExponential(3)}');
    debugPrint('inference   : median ${inferenceMs[inferenceMs.length ~/ 2]} ms '
        '(min ${inferenceMs.first}, max ${inferenceMs.last})');
    debugPrint('=========================================================');

    // The Dart pipeline reproduces the desktop probability to ~8e-07 on these
    // fixtures; 1e-3 leaves room for platform float differences while still
    // catching any real drift.
    expect(maxDifference, lessThan(1e-3),
        reason: 'Dart preprocessing drifted from the Python pipeline');

    await service.dispose();
    expect(service.isReady, isFalse);
  });
}
