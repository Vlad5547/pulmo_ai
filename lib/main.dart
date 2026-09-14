import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/mock_analysis_service.dart';
import 'services/history_repository.dart';
import 'services/image_source_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Composition root. Replace [MockAnalysisService] with the real inference
  // backend once the RSNA-trained model is ready — nothing else changes.
  runApp(
    PulmoAiApp(
      analysisService: MockAnalysisService(),
      historyRepository: HistoryRepository(),
      imageSourceService: ImageSourceService(),
    ),
  );
}
