import 'package:flutter/widgets.dart';

import '../services/analysis_service.dart';
import '../services/history_repository.dart';
import '../services/image_source_service.dart';
import '../services/report_service.dart';
import 'locale_controller.dart';

/// Single composition root for the app's dependencies.
///
/// Swapping the mock model for a real one is a one-line change in
/// `main.dart` — every screen resolves the service through
/// `AppServices.of(context).analysisService`.
class AppServices extends InheritedWidget {
  const AppServices({
    super.key,
    required this.analysisService,
    required this.historyRepository,
    required this.imageSourceService,
    required this.reportService,
    required this.localeController,
    required super.child,
  });

  final AnalysisService analysisService;
  final HistoryRepository historyRepository;
  final ImageSourceService imageSourceService;
  final ReportService reportService;
  final LocaleController localeController;

  static AppServices of(BuildContext context) {
    final services =
        context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(services != null, 'AppServices was not found above this widget');
    return services!;
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) =>
      analysisService != oldWidget.analysisService ||
      historyRepository != oldWidget.historyRepository ||
      imageSourceService != oldWidget.imageSourceService ||
      reportService != oldWidget.reportService ||
      localeController != oldWidget.localeController;
}
