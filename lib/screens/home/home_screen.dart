import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/locale_controller.dart';
import '../../app/routes.dart';
import '../../app/service_locator.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/analysis_record.dart';
import '../../models/xray_image.dart';
import '../../widgets/analysis_tile.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/info_note.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/section_title.dart';
import 'widgets/hero_card.dart';
import 'widgets/stat_tile.dart';
import 'widgets/workflow_steps.dart';

/// Kept in step with `version:` in pubspec.yaml by hand. Reading it at
/// runtime would mean pulling in package_info_plus for one string on the
/// About dialog, which is not worth a platform channel.
const String _appVersion = '1.0.0';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenHistory});

  final VoidCallback onOpenHistory;

  Future<void> _startAnalysis(BuildContext context, {XRayImage? image}) async {
    await Navigator.pushNamed(context, AppRoutes.analyze, arguments: image);
  }

  Future<void> _pickThenAnalyze(BuildContext context) async {
    final image = await pickXRayImage(context);
    if (image == null || !context.mounted) return;
    await _startAnalysis(context, image: image);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final history = AppServices.of(context).historyRepository;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        titleSpacing: 20,
        actions: [
          const _LanguageButton(),
          IconButton(
            tooltip: l10n.aboutTooltip,
            onPressed: () => unawaited(_showAbout(context)),
            icon: const Icon(Icons.info_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: history,
        builder: (context, _) {
          final records = history.records;
          return SingleChildScrollView(
            child: ResponsiveContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HeroCard(
                    onAnalyze: () => _startAnalysis(context),
                    onPickFromGallery: () => _pickThenAnalyze(context),
                  ),
                  const SizedBox(height: 24),
                  _SummaryRow(records: records),
                  const SizedBox(height: 24),
                  SectionTitle(l10n.homeHowItWorks),
                  const WorkflowSteps(),
                  const SizedBox(height: 24),
                  if (records.isNotEmpty) ...[
                    SectionTitle(
                      l10n.homeRecentAnalyses,
                      trailing: TextButton(
                        onPressed: onOpenHistory,
                        child: Text(l10n.homeSeeAll),
                      ),
                    ),
                    for (final record in records.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnalysisTile(
                          record: record,
                          onTap: () => unawaited(
                            Navigator.pushNamed(
                              context,
                              AppRoutes.result,
                              arguments: record,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  InfoNote(
                    icon: Icons.health_and_safety_outlined,
                    title: l10n.homePrototypeTitle,
                    text: l10n.homePrototypeText,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Plain dialog rather than `showAboutDialog`: that one always adds a
  /// "View licences" button and a full licence browser, which is Flutter's
  /// own page, cannot be removed, is not translated into the app's languages,
  /// and has nothing to say to a clinician looking at a screening result.
  Future<void> _showAbout(BuildContext context) => showDialog<void>(
        context: context,
        builder: (context) {
          final l10n = AppL10n.of(context);
          return AlertDialog(
            icon: const AppLogo(size: 40, showWordmark: false),
            title: Text(l10n.appTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aboutVersion(_appVersion),
                  style: context.texts.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.aboutText),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.actionClose),
              ),
            ],
          );
        },
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.records});

  final List<AnalysisRecord> records;

  @override
  Widget build(BuildContext context) {
    final findings = records.where((r) => r.result.isPositive).length;
    final avgConfidence = records.isEmpty
        ? 0.0
        : records.map((r) => r.result.confidence).reduce((a, b) => a + b) /
              records.length;

    final l10n = AppL10n.of(context);
    final tiles = [
      StatTile(
        value: '${records.length}',
        label: l10n.homeStudiesAnalysed,
        icon: Icons.folder_open_outlined,
      ),
      StatTile(
        value: '$findings',
        label: l10n.homeFindingsFlagged,
        icon: Icons.warning_amber_rounded,
        color: context.clinical.finding,
      ),
      StatTile(
        value: '${(avgConfidence * 100).round()}%',
        label: l10n.homeAvgConfidence,
        icon: Icons.speed_outlined,
        color: context.clinical.clear,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

/// Language picker in the app bar.
///
/// The app follows the device language by default; a thesis demo often has to
/// be shown in Ukrainian on a phone set to something else, so the choice is
/// also offered explicitly.
class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final controller = AppServices.of(context).localeController;
    final current = controller.locale?.languageCode;

    String name(String code) => switch (code) {
          'uk' => l10n.languageUkrainian,
          'de' => l10n.languageGerman,
          _ => l10n.languageEnglish,
        };

    return PopupMenuButton<String>(
      tooltip: l10n.languageTitle,
      icon: const Icon(Icons.translate),
      initialValue: current ?? '',
      onSelected: (code) => controller.setLocale(
        code.isEmpty ? null : Locale(code),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(value: '', child: Text(l10n.languageSystem)),
        const PopupMenuDivider(),
        for (final locale in LocaleController.supported)
          PopupMenuItem(
            value: locale.languageCode,
            child: Text(name(locale.languageCode)),
          ),
      ],
    );
  }
}
