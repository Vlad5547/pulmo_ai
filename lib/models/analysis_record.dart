import 'package:flutter/foundation.dart';

import 'analysis_result.dart';

/// One entry of the analysis history.
///
/// [imagePath] points at the copy the history repository owns, not at the file
/// the user picked: a gallery item or a shared DICOM can be moved or deleted,
/// and the entry has to survive that. It is null only for records built in
/// memory (tests) whose file is not on this device.
@immutable
class AnalysisRecord {
  const AnalysisRecord({
    required this.id,
    required this.imageName,
    required this.createdAt,
    required this.result,
    this.imagePath,
    this.heatmapPath,
    this.isDicom = false,
  });

  final String id;
  final String imageName;

  /// Displayable radiograph (PNG/JPEG). A DICOM is rendered to PNG before it
  /// gets here, so the UI never has to decode a medical container.
  final String? imagePath;

  /// The stored class activation map, next to [imagePath].
  final String? heatmapPath;

  /// True when the analysed file was a DICOM rather than a PNG/JPEG export.
  /// Worth recording: it is the difference between the pixels the model was
  /// trained on and a re-encoded copy of them.
  final bool isDicom;

  final DateTime createdAt;
  final AnalysisResult result;

  AnalysisRecord copyWith({
    String? imagePath,
    String? heatmapPath,
    AnalysisResult? result,
  }) =>
      AnalysisRecord(
        id: id,
        imageName: imageName,
        createdAt: createdAt,
        result: result ?? this.result,
        imagePath: imagePath ?? this.imagePath,
        heatmapPath: heatmapPath ?? this.heatmapPath,
        isDicom: isDicom,
      );
}
