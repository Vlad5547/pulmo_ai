import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/history_repository.dart';
import 'services/image_source_service.dart';
import 'services/onnx_analysis_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root. [OnnxAnalysisService] runs the exported PulmoNet-7M
  // locally, on device, with no network access. `MockAnalysisService` stays in
  // the project and can be injected here instead to run the UI without the
  // model (that is what the widget tests do).
  final analysisService = OnnxAnalysisService();

  // Opening the ~28 MB session takes a moment; start it now so the first
  // analysis does not pay for it. Failures surface later, on the Analyze
  // screen, instead of blocking start-up.
  unawaited(analysisService.warmUp().catchError((Object error) {
    debugPrint('PulmoAI: warm-up failed, retried on first analysis: $error');
  }));

  runApp(
    PulmoAiApp(
      analysisService: analysisService,
      historyRepository: HistoryRepository(),
      imageSourceService: ImageSourceService(),
    ),
  );
}
