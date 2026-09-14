import 'package:flutter/foundation.dart';

/// High level outcome of a single chest X-ray analysis.
enum PneumoniaVerdict {
  pneumonia('Pneumonia detected', 'Opacity consistent with pneumonia'),
  normal('No signs of pneumonia', 'No opacity consistent with pneumonia');

  const PneumoniaVerdict(this.label, this.description);

  final String label;
  final String description;

  bool get isPositive => this == PneumoniaVerdict.pneumonia;
}

/// A region of interest returned by a detection model.
///
/// Coordinates are normalised (0..1) relative to the displayed image so the
/// overlay stays correct on any screen size. The RSNA challenge produces
/// exactly this shape of output, so a real model can fill this in unchanged.
@immutable
class DetectionBox {
  const DetectionBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.score,
    this.label = 'Opacity',
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double score;
  final String label;
}

/// Result of one inference run. Produced today by [MockAnalysisService],
/// later by a real TFLite / ONNX / remote model without touching the UI.
@immutable
class AnalysisResult {
  const AnalysisResult({
    required this.verdict,
    required this.confidence,
    required this.processingTime,
    this.boxes = const <DetectionBox>[],
    this.modelName = 'PulmoAI-Mock',
    this.modelVersion = '0.1.0',
    this.notes,
  });

  final PneumoniaVerdict verdict;

  /// Model confidence in the reported [verdict], in the 0..1 range.
  final double confidence;

  final Duration processingTime;

  /// Regions of interest for the heatmap / bounding-box overlay.
  final List<DetectionBox> boxes;

  final String modelName;
  final String modelVersion;
  final String? notes;

  int get confidencePercent => (confidence * 100).round();

  bool get isPositive => verdict.isPositive;
}
