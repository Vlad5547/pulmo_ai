import 'package:flutter/material.dart';

import '../services/analysis_service.dart';
import '../services/history_repository.dart';
import '../services/image_source_service.dart';
import 'routes.dart';
import 'service_locator.dart';
import 'theme.dart';

class PulmoAiApp extends StatelessWidget {
  const PulmoAiApp({
    super.key,
    required this.analysisService,
    required this.historyRepository,
    required this.imageSourceService,
  });

  final AnalysisService analysisService;
  final HistoryRepository historyRepository;
  final ImageSourceService imageSourceService;

  @override
  Widget build(BuildContext context) {
    return AppServices(
      analysisService: analysisService,
      historyRepository: historyRepository,
      imageSourceService: imageSourceService,
      child: MaterialApp(
        title: 'PulmoAI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        initialRoute: AppRoutes.root,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
