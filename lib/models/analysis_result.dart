
import 'package:flutter/foundation.dart';

/// High level outcome of a single chest X-ray analysis.
///
/// The wording lives in the localisations, not here: the same verdict has to
/// read correctly in three languages, and a model layer has no business
/// holding UI copy.
enum PneumoniaVerdict {
  pneumonia,
  normal;

  bool get isPositive => this == PneumoniaVerdict.pneumonia;
}

/// Result of one inference run: the probability the model assigned, the
/// verdict that the decision threshold turns it into, and the optional class
/// activation map.
///
/// PulmoNet-7M is a classifier, not a detector, so there are no bounding
/// boxes — localisation is only ever suggested by [heatmapPng].
@immutable
class AnalysisResult {
  const AnalysisResult({
    required this.verdict,
    required this.confidence,
    required this.processingTime,
    this.modelName = 'PulmoAI-Mock',
    this.modelVersion = '0.1.0',
    this.notes,
    this.heatmapPng,
  });

  final PneumoniaVerdict verdict;

  /// Model confidence in the reported [verdict], in the 0..1 range.
  final double confidence;

  final Duration processingTime;

  final String modelName;
  final String modelVersion;
  final String? notes;

  /// Class activation map rendered as a translucent PNG, ready to be laid over
  /// the radiograph. Null when the map could not be produced - the
  /// classification result stands on its own.
  final Uint8List? heatmapPng;

  bool get hasHeatmap => heatmapPng != null;

  int get confidencePercent => (confidence * 100).round();

  bool get isPositive => verdict.isPositive;
}
