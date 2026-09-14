import 'package:flutter/foundation.dart';

import 'analysis_result.dart';

/// One entry of the analysis history.
///
/// [imagePath] may be null for seeded/demo entries whose file is not on this
/// device; the UI falls back to a placeholder in that case.
@immutable
class AnalysisRecord {
  const AnalysisRecord({
    required this.id,
    required this.imageName,
    required this.createdAt,
    required this.result,
    this.imagePath,
  });

  final String id;
  final String imageName;
  final String? imagePath;
  final DateTime createdAt;
  final AnalysisResult result;
}
