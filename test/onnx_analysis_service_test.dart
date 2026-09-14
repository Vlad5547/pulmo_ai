import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulmo_ai/models/analysis_result.dart';
import 'package:pulmo_ai/models/xray_image.dart';
import 'package:pulmo_ai/services/analysis_service.dart';
import 'package:pulmo_ai/services/mock_analysis_service.dart';
import 'package:pulmo_ai/services/onnx_analysis_service.dart';

/// Counts session creation without touching the platform channel, so the
/// lifecycle can be tested on the Dart VM. Real inference is covered by
/// `integration_test/inference_parity_test.dart`.
class _CountingRuntime extends OnnxRuntime {
  int createCalls = 0;
  bool fail = false;

  @override
  Future<OrtSession> createSessionFromAsset(
    String assetKey, {
    OrtSessionOptions? options,
  }) async {
    createCalls++;
    if (fail) throw StateError('no runtime in this test environment');
    return OrtSession.fromMap({
      'sessionId': 'test-session-$createCalls',
      'inputNames': ['input'],
      'outputNames': ['logit'],
    });
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalysisService contract', () {
    test('both backends implement the same interface', () {
      expect(MockAnalysisService(), isA<AnalysisService>());
      expect(OnnxAnalysisService(), isA<AnalysisService>());
    });

    test('the ONNX backend reports the model name before loading', () {
      expect(OnnxAnalysisService().modelName, 'PulmoNet-7M');
    });

    test('the mock still works and returns a usable result', () async {
      final mock = MockAnalysisService(latency: Duration.zero);
      await mock.warmUp();
      final result = await mock.analyze(
        const XRayImage(name: 'demo.png', path: 'demo.png'),
      );

      expect(result, isA<AnalysisResult>());
      expect(result.confidence, inInclusiveRange(0.0, 1.0));
      expect(result.verdict, isA<PneumoniaVerdict>());
      await mock.dispose();
    });
  });

  group('session lifecycle', () {
    test('warmUp creates exactly one session and is idempotent', () async {
      final runtime = _CountingRuntime();
      final service = OnnxAnalysisService(runtime: runtime);

      await service.warmUp();
      await service.warmUp();
      await service.warmUp();

      expect(runtime.createCalls, 1);
      expect(service.isReady, isTrue);
      expect(service.warmUpDuration, isNotNull);
      expect(service.modelInfo?.threshold, 0.5);
    });

    test('concurrent warmUp calls share a single session', () async {
      final runtime = _CountingRuntime();
      final service = OnnxAnalysisService(runtime: runtime);

      await Future.wait([
        service.warmUp(),
        service.warmUp(),
        service.warmUp(),
      ]);

      expect(runtime.createCalls, 1);
    });

    test('dispose releases the session and allows a fresh warmUp', () async {
      final runtime = _CountingRuntime();
      final service = OnnxAnalysisService(runtime: runtime);

      await service.warmUp();
      expect(service.isReady, isTrue);

      await service.dispose();
      expect(service.isReady, isFalse);

      await service.warmUp();
      expect(runtime.createCalls, 2);
    });

    test('a load failure surfaces as ModelUnavailableException, not a crash',
        () async {
      final runtime = _CountingRuntime()..fail = true;
      final service = OnnxAnalysisService(runtime: runtime);

      await expectLater(
        service.warmUp(),
        throwsA(isA<ModelUnavailableException>()),
      );
      expect(service.isReady, isFalse);

      // the failure must not poison the service - a later attempt retries
      runtime.fail = false;
      await service.warmUp();
      expect(service.isReady, isTrue);
    });

    test('analyze without a working session throws the same exception',
        () async {
      final runtime = _CountingRuntime()..fail = true;
      final service = OnnxAnalysisService(runtime: runtime);

      await expectLater(
        service.analyze(const XRayImage(name: 'x.png', path: 'x.png')),
        throwsA(isA<ModelUnavailableException>()),
      );
    });
  });
}
