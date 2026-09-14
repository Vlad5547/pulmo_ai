import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/analysis_result.dart';
import '../models/model_info.dart';
import '../models/xray_image.dart';
import 'analysis_service.dart';
import 'cam_service.dart';
import 'image_preprocessor.dart';

/// Local, offline inference with the exported PulmoNet-7M model.
///
/// The ONNX file ships inside the app (`assets/models/pulmonet7m.onnx`); no
/// server, no network call. The session is created once in [warmUp] and reused
/// for every image — creating it per image would repeat the ~28 MB load.
///
/// The model emits one raw logit; sigmoid and the decision threshold from the
/// model card are applied here, exactly as in the Python evaluation.
///
/// The bundled graph also returns the last convolutional feature map, so a
/// class activation map comes out of the same forward pass at no extra
/// inference cost. Building it is best-effort: if anything about the map fails,
/// the classification result is still returned, without a heatmap.
class OnnxAnalysisService implements AnalysisService {
  OnnxAnalysisService({
    OnnxRuntime? runtime,
    ModelInfo? modelInfo,
    this.providers = const [OrtProvider.CPU],
  }) : _runtime = runtime ?? OnnxRuntime() {
    _modelInfo = modelInfo;
  }

  final OnnxRuntime _runtime;
  final List<OrtProvider> providers;

  ModelInfo? _modelInfo;
  OrtSession? _session;
  ImagePreprocessor? _preprocessor;
  CamService? _camService;
  Future<void>? _warmUpInFlight;

  /// How long the last activation map took to build, for diagnostics.
  Duration? lastCamDuration;

  /// Why the last activation map could not be built, if it could not.
  String? lastCamError;

  /// Time the one-off session creation took, for diagnostics and the UI.
  Duration? warmUpDuration;

  ModelInfo? get modelInfo => _modelInfo;

  bool get isReady => _session != null;

  @override
  String get modelName => _modelInfo?.name ?? 'PulmoNet-7M';

  // -- lifecycle ----------------------------------------------------------

  /// Loads the model card and opens the ONNX session. Idempotent, and safe to
  /// call from several places at once — concurrent callers await the same
  /// future instead of opening a second session.
  @override
  Future<void> warmUp() {
    if (_session != null) return Future.value();
    return _warmUpInFlight ??= _warmUp().whenComplete(() {
      _warmUpInFlight = null;
    });
  }

  Future<void> _warmUp() async {
    final stopwatch = Stopwatch()..start();
    try {
      final info = _modelInfo ??= await ModelInfo.load();
      _preprocessor = ImagePreprocessor(
        imageSize: info.imageSize,
        mean: info.mean,
        std: info.std,
      );
      _camService = CamService(
        weights: info.camWeights,
        gridSize: info.camGridSize,
      );
      _session = await _runtime.createSessionFromAsset(
        info.assetPath,
        options: OrtSessionOptions(providers: providers),
      );
      stopwatch.stop();
      warmUpDuration = stopwatch.elapsed;
      debugPrint(
        'PulmoAI: ${info.displayName} loaded in '
        '${stopwatch.elapsedMilliseconds} ms '
        '(inputs ${_session!.inputNames}, outputs ${_session!.outputNames})',
      );
    } catch (error, stackTrace) {
      _session = null;
      _preprocessor = null;
      _camService = null;
      debugPrint('PulmoAI: model load failed: $error');
      Error.throwWithStackTrace(
        ModelUnavailableException(
          'The analysis model could not be loaded on this device.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// Best-effort activation map. Never throws: a failure here must not cost
  /// the user the classification result, so it is logged and reported through
  /// [lastCamError] instead.
  Future<Uint8List?> _buildHeatmap(
    OrtValue? features, {
    required int sourceWidth,
    required int sourceHeight,
  }) async {
    final cam = _camService;
    lastCamDuration = null;
    lastCamError = null;
    if (cam == null || features == null) {
      lastCamError = 'the model returned no feature map';
      return null;
    }

    final watch = Stopwatch()..start();
    try {
      final flat = (await features.asFlattenedList())
          .map((value) => (value as num).toDouble())
          .toList(growable: false);
      final map = cam.computeMap(flat);
      final png = cam.renderOverlayPng(
        map,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
      );
      watch.stop();
      lastCamDuration = watch.elapsed;
      return png;
    } catch (error) {
      watch.stop();
      lastCamError = error.toString();
      debugPrint('PulmoAI: activation map unavailable: $error');
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    final session = _session;
    _session = null;
    _preprocessor = null;
    _camService = null;
    try {
      await session?.close();
    } catch (error) {
      // Releasing the native session is best-effort: the process is usually
      // going away anyway, and a failure here must not take the app with it.
      debugPrint('PulmoAI: closing the ONNX session failed: $error');
    }
  }

  // -- inference ----------------------------------------------------------

  @override
  Future<AnalysisResult> analyze(XRayImage image) async {
    await warmUp();
    final session = _session;
    final preprocessor = _preprocessor;
    final info = _modelInfo;
    if (session == null || preprocessor == null || info == null) {
      throw const ModelUnavailableException(
        'The analysis model is not loaded.',
      );
    }

    final stopwatch = Stopwatch()..start();
    final bytes = image.bytes ?? await File(image.path).readAsBytes();

    // Decoding and resizing a 1024x1024 radiograph is CPU-bound; keep it off
    // the UI isolate so the progress indicator stays smooth.
    final prepared = await compute(
      _preprocessInIsolate,
      _PreprocessRequest(
        bytes: bytes,
        imageSize: info.imageSize,
        mean: info.mean,
        std: info.std,
      ),
    );
    final input = prepared.tensor;

    OrtValue? inputValue;
    Map<String, OrtValue>? outputs;
    try {
      inputValue = await OrtValue.fromList(input, preprocessor.inputShape);
      outputs = await session.run({info.inputName: inputValue});
      final output = outputs[info.outputName];
      if (output == null) {
        throw ModelUnavailableException(
          'The model returned no "${info.outputName}" output.',
        );
      }
      final flat = await output.asFlattenedList();
      if (flat.isEmpty) {
        throw const ModelUnavailableException(
          'The model returned an empty output.',
        );
      }
      final logit = (flat.first as num).toDouble();
      final probability = 1.0 / (1.0 + math.exp(-logit));

      final heatmap = await _buildHeatmap(
        outputs[info.featuresOutputName],
        sourceWidth: prepared.sourceWidth,
        sourceHeight: prepared.sourceHeight,
      );
      stopwatch.stop();

      return AnalysisResult(
        verdict: probability >= info.threshold
            ? PneumoniaVerdict.pneumonia
            : PneumoniaVerdict.normal,
        confidence: probability,
        processingTime: stopwatch.elapsed,
        boxes: const [],
        modelName: info.name,
        modelVersion: info.version,
        notes: 'On-device inference, decision threshold '
            '${info.threshold.toStringAsFixed(2)}.',
        heatmapPng: heatmap,
      );
    } finally {
      await inputValue?.dispose();
      if (outputs != null) {
        for (final value in outputs.values) {
          await value.dispose();
        }
      }
    }
  }

}

/// Thrown when the model cannot be loaded or produces no usable output.
class ModelUnavailableException implements Exception {
  const ModelUnavailableException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Tensor plus the geometry of the source image, so the activation map can be
/// rendered with the same aspect ratio.
@immutable
class _PreparedImage {
  const _PreparedImage({
    required this.tensor,
    required this.sourceWidth,
    required this.sourceHeight,
  });

  final Float32List tensor;
  final int sourceWidth;
  final int sourceHeight;
}

@immutable
class _PreprocessRequest {
  const _PreprocessRequest({
    required this.bytes,
    required this.imageSize,
    required this.mean,
    required this.std,
  });

  final Uint8List bytes;
  final int imageSize;
  final double mean;
  final double std;
}

/// Top-level function so it can run in a background isolate.
_PreparedImage _preprocessInIsolate(_PreprocessRequest request) {
  final preprocessor = ImagePreprocessor(
    imageSize: request.imageSize,
    mean: request.mean,
    std: request.std,
  );
  final size = preprocessor.sourceSize(request.bytes);
  return _PreparedImage(
    tensor: preprocessor.toModelInput(request.bytes),
    sourceWidth: size.$1,
    sourceHeight: size.$2,
  );
}
