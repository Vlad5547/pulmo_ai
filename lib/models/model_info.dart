import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Metrics measured once on the held-out test split.
@immutable
class ModelTestMetrics {
  const ModelTestMetrics({
    required this.rocAuc,
    required this.auprc,
    required this.accuracy,
    required this.recall,
    required this.precision,
    required this.f1,
  });

  factory ModelTestMetrics.fromJson(Map<String, dynamic> json) {
    double read(String key) => (json[key] as num).toDouble();
    return ModelTestMetrics(
      rocAuc: read('roc_auc'),
      auprc: read('auprc'),
      accuracy: read('accuracy'),
      recall: read('recall'),
      precision: read('precision'),
      f1: read('f1'),
    );
  }

  final double rocAuc;
  final double auprc;
  final double accuracy;
  final double recall;
  final double precision;
  final double f1;
}

/// Everything the app needs to know about the bundled model.
///
/// Read from `assets/models/model_card.json`, which is generated from the
/// export summary — the app never hard-codes the input contract or the
/// decision threshold.
@immutable
class ModelInfo {
  const ModelInfo({
    required this.name,
    required this.version,
    required this.assetPath,
    required this.inputName,
    required this.outputName,
    required this.featuresOutputName,
    required this.camWeights,
    required this.camGridSize,
    required this.inputShape,
    required this.imageSize,
    required this.mean,
    required this.std,
    required this.threshold,
    required this.parameterCount,
    required this.opset,
    required this.precision,
    required this.testMetrics,
  });

  factory ModelInfo.fromJson(
    Map<String, dynamic> json, {
    String assetPath = defaultAssetPath,
  }) {
    final input = json['input'] as Map<String, dynamic>;
    final preprocessing = input['preprocessing'] as Map<String, dynamic>;
    final output = json['output'] as Map<String, dynamic>;
    final format = json['format'] as Map<String, dynamic>;
    final logit = (output['logit'] as Map).cast<String, dynamic>();
    final features = (output['features'] as Map).cast<String, dynamic>();
    final cam = (json['cam'] as Map).cast<String, dynamic>();
    final grid = (cam['native_grid'] as List).cast<num>();
    final shape = (input['shape'] as List).cast<num>()
        .map((value) => value.toInt())
        .toList(growable: false);

    return ModelInfo(
      name: json['model_name'] as String,
      version: json['model_version'] as String,
      assetPath: assetPath,
      inputName: input['name'] as String,
      outputName: logit['name'] as String,
      featuresOutputName: features['name'] as String,
      camWeights: Float32List.fromList(
        (cam['weight'] as List).cast<num>().map((v) => v.toDouble()).toList(),
      ),
      camGridSize: grid.first.toInt(),
      inputShape: shape,
      imageSize: shape.last,
      mean: (preprocessing['normalisation_mean'] as num).toDouble(),
      std: (preprocessing['normalisation_std'] as num).toDouble(),
      threshold: (json['threshold'] as num).toDouble(),
      parameterCount: (json['parameter_count'] as num).toInt(),
      opset: (format['opset'] as num).toInt(),
      precision: format['precision'] as String,
      testMetrics: ModelTestMetrics.fromJson(
        (json['test_metrics'] as Map).cast<String, dynamic>(),
      ),
    );
  }

  static const defaultAssetPath = 'assets/models/pulmonet7m_cam.onnx';
  static const defaultCardPath = 'assets/models/model_card.json';

  /// Loads the model card that ships with the app.
  static Future<ModelInfo> load({
    String cardPath = defaultCardPath,
    String assetPath = defaultAssetPath,
  }) async {
    final raw = await rootBundle.loadString(cardPath);
    return ModelInfo.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      assetPath: assetPath,
    );
  }

  final String name;
  final String version;
  final String assetPath;

  /// ONNX graph input/output names, taken from the card rather than guessed.
  final String inputName;
  final String outputName;

  /// Second graph output: the last convolutional feature map, used for the
  /// class activation map.
  final String featuresOutputName;

  /// Classifier weights, one per feature channel - the CAM coefficients.
  final Float32List camWeights;

  /// Native CAM resolution (7 for PulmoNet-7M).
  final int camGridSize;

  /// `[1, 1, 224, 224]`, NCHW.
  final List<int> inputShape;
  final int imageSize;

  /// Normalisation statistics measured on the training split.
  final double mean;
  final double std;

  /// Decision threshold fixed on the validation split.
  final double threshold;

  final int parameterCount;
  final int opset;
  final String precision;
  final ModelTestMetrics testMetrics;

  String get displayName => '$name v$version';

  /// e.g. "ONNX opset 17 · fp32 · 7 065 953 parameters".
  String get technicalSummary {
    final formatted = parameterCount
        .toString()
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (match) => '${match[1]} ',
        );
    return 'ONNX opset $opset · $precision · $formatted parameters';
  }
}
