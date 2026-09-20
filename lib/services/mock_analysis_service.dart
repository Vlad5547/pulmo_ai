import 'dart:async';
import 'dart:math';

import '../models/analysis_result.dart';
import '../models/xray_image.dart';
import 'analysis_service.dart';

/// Deterministic stand-in for the real model.
///
/// The verdict is derived from a hash of the file name, so the same image
/// always yields the same result — which keeps demos and screenshots stable.
class MockAnalysisService implements AnalysisService {
  MockAnalysisService({this.latency = const Duration(milliseconds: 2200)});

  final Duration latency;

  @override
  String get modelName => 'PulmoAI-Mock';

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<AnalysisResult> analyze(XRayImage image) async {
    final stopwatch = Stopwatch()..start();
    await Future<void>.delayed(latency);
    stopwatch.stop();

    final seed = image.name.hashCode ^ image.path.hashCode;
    final random = Random(seed);
    final positive = random.nextInt(100) < 45;

    final confidence = positive
        ? 0.72 + random.nextDouble() * 0.26
        : 0.80 + random.nextDouble() * 0.19;

    return AnalysisResult(
      verdict: positive
          ? PneumoniaVerdict.pneumonia
          : PneumoniaVerdict.normal,
      confidence: confidence,
      processingTime: stopwatch.elapsed,
      notes: 'Mock inference, not a real model output.',
    );
  }
}
