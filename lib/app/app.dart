import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/generated/app_localizations.dart';
import '../services/analysis_service.dart';
import '../services/history_repository.dart';
import '../services/image_source_service.dart';
import '../services/report_service.dart';
import 'locale_controller.dart';
import 'routes.dart';
import 'service_locator.dart';
import 'theme.dart';

class PulmoAiApp extends StatefulWidget {
  const PulmoAiApp({
    super.key,
    required this.analysisService,
    required this.historyRepository,
    required this.imageSourceService,
    this.reportService = const ReportService(),
    this.localeController,
  });

  final AnalysisService analysisService;
  final HistoryRepository historyRepository;
  final ImageSourceService imageSourceService;
  final ReportService reportService;

  /// Injected by tests that want to start in a specific language.
  final LocaleController? localeController;

  @override
  State<PulmoAiApp> createState() => _PulmoAiAppState();
}

class _PulmoAiAppState extends State<PulmoAiApp> {
  late final LocaleController _locales =
      widget.localeController ?? LocaleController();

  @override
  void dispose() {
    if (widget.localeController == null) _locales.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppServices(
      analysisService: widget.analysisService,
      historyRepository: widget.historyRepository,
      imageSourceService: widget.imageSourceService,
      reportService: widget.reportService,
      localeController: _locales,
      child: ListenableBuilder(
        listenable: _locales,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppL10n.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: _locales.locale,
          supportedLocales: AppL10n.supportedLocales,
          localizationsDelegates: const [
            AppL10n.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: AppRoutes.root,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        ),
      ),
    );
  }
}
