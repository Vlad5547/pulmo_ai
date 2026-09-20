import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../app/routes.dart';
import '../../app/service_locator.dart';
import '../../app/theme.dart';
import '../../core/formatters.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/verdict_l10n.dart';
import '../../models/analysis_record.dart';
import '../../services/onnx_analysis_service.dart';
import '../../services/report_service.dart';
import '../../widgets/info_note.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/section_title.dart';
import '../../widgets/xray_viewer.dart';
import 'widgets/result_details.dart';
import 'widgets/verdict_card.dart';

/// How the model output is drawn on top of the scan.
///
/// [OverlayMode.heatmap] renders the class activation map that came out of the
/// same forward pass as the probability. It marks the regions the model's
/// decision responded to - it is not a localisation of disease.
enum OverlayMode {
  off(Icons.image_outlined),
  heatmap(Icons.blur_on);

  const OverlayMode(this.icon);

  final IconData icon;

  String label(AppL10n l10n) => switch (this) {
        OverlayMode.off => l10n.overlayOriginal,
        OverlayMode.heatmap => l10n.overlayHeatmap,
      };
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.record});

  final AnalysisRecord record;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  OverlayMode _mode = OverlayMode.off;
  bool _sharing = false;

  AnalysisRecord get _record => widget.record;

  /// Builds the PDF and hands it to the platform share sheet.
  ///
  /// Everything happens on the device: the document is assembled from the
  /// stored record and never uploaded. Where it goes afterwards is the user's
  /// decision, which is why this is a share sheet and not an automatic upload.
  Future<void> _shareReport() async {
    final l10n = AppL10n.of(context);
    final services = AppServices.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final threshold =
        (services.analysisService as OnnxAnalysisService?)?.modelInfo?.threshold;

    setState(() => _sharing = true);
    try {
      final bytes = await services.reportService.build(
        record: _record,
        labels: ReportLabels(
          title: l10n.reportTitle,
          subtitle: l10n.reportSubtitle,
          study: l10n.reportStudy,
          analysed: l10n.reportAnalysed,
          verdict: l10n.reportVerdict,
          verdictText: _record.result.verdict.label(l10n),
          probability: l10n.reportProbability,
          threshold: l10n.reportThreshold,
          model: l10n.reportModel,
          inferenceTime: l10n.reportInferenceTime,
          heatmapCaption: l10n.reportHeatmapCaption,
          disclaimer: l10n.reportDisclaimer,
          generatedBy: l10n.reportGeneratedBy,
          noImages: l10n.reportNoImages,
        ),
        formattedDate: formatDateTime(_record.createdAt, locale),
        formattedDuration: formatDuration(_record.result.processingTime),
        threshold: threshold ?? 0.5,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'pulmoai_${_record.id}.pdf',
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.resultReportFailed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final result = _record.result;
    final clinical = context.clinical;
    final accent = result.isPositive ? clinical.finding : clinical.clear;
    final path = _record.imagePath;
    final heatmap = result.heatmapPng;
    final modes = <OverlayMode>[
      OverlayMode.off,
      if (heatmap != null) OverlayMode.heatmap,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.resultTitle),
        actions: [
          IconButton(
            tooltip: l10n.resultBackHome,
            onPressed: () => Navigator.popUntil(
              context,
              ModalRoute.withName(AppRoutes.root),
            ),
            icon: const Icon(Icons.home_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              XRayViewer(
                image: path != null && path.isNotEmpty
                    ? FileImage(File(path))
                    : null,
                borderColor: accent.withValues(alpha: 0.45),
                topLeftBadge: ScanBadge(
                  label: result.verdict.label(l10n),
                  icon: result.isPositive
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: accent,
                ),
                topRightBadge: ScanBadge(
                  label: '${result.confidencePercent}%',
                  icon: Icons.query_stats,
                  color: accent,
                ),
                overlay: switch (_mode) {
                  OverlayMode.off => null,
                  OverlayMode.heatmap => heatmap == null
                      ? null
                      : Image.memory(
                          heatmap,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          gaplessPlayback: true,
                        ),
                },
              ),
              const SizedBox(height: 14),
              if (modes.length > 1)
                _OverlayModeSelector(
                  modes: modes,
                  mode: _mode,
                  onChanged: (mode) => setState(() => _mode = mode),
                ),
              if (modes.length > 1) const SizedBox(height: 8),
              Text(
                heatmap != null
                    ? l10n.resultHeatmapText
                    : l10n.resultNoHeatmapText,
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              VerdictCard(result: result),
              const SizedBox(height: 24),
              SectionTitle(l10n.resultWhatThisMeans),
              _Interpretation(record: _record),
              const SizedBox(height: 24),
              SectionTitle(l10n.resultStudyDetails),
              ResultDetails(record: _record),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => unawaited(
                  Navigator.pushReplacementNamed(context, AppRoutes.analyze),
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(l10n.resultAnalyzeAnother),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _sharing ? null : _shareReport,
                icon: _sharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(l10n.resultShareReport),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.popUntil(
                  context,
                  ModalRoute.withName(AppRoutes.root),
                ),
                icon: const Icon(Icons.home_outlined),
                label: Text(l10n.resultBackHome),
              ),
              const SizedBox(height: 20),
              InfoNote(
                icon: Icons.gavel_outlined,
                title: l10n.resultDisclaimerTitle,
                text: l10n.resultDisclaimerText,
                color: context.colors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayModeSelector extends StatelessWidget {
  const _OverlayModeSelector({
    required this.modes,
    required this.mode,
    required this.onChanged,
  });

  final List<OverlayMode> modes;
  final OverlayMode mode;
  final ValueChanged<OverlayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<OverlayMode>(
      segments: [
        for (final option in modes)
          ButtonSegment(
            value: option,
            icon: Icon(option.icon, size: 17),
            label: Text(option.label(AppL10n.of(context))),
          ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

class _Interpretation extends StatelessWidget {
  const _Interpretation({required this.record});

  final AnalysisRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final result = record.result;
    final positive = result.isPositive;
    final points = positive
        ? [
            (Icons.search, l10n.interpretationFinding, l10n.positiveFinding),
            (
              Icons.route_outlined,
              l10n.interpretationNextStep,
              l10n.positiveNextStep,
            ),
            (
              Icons.help_outline,
              l10n.interpretationLimitations,
              l10n.positiveLimitations,
            ),
          ]
        : [
            (
              Icons.check_circle_outline,
              l10n.interpretationFinding,
              l10n.negativeFinding,
            ),
            (
              Icons.route_outlined,
              l10n.interpretationNextStep,
              l10n.negativeNextStep,
            ),
            (
              Icons.help_outline,
              l10n.interpretationLimitations,
              l10n.negativeLimitations,
            ),
          ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < points.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      points[i].$1,
                      size: 19,
                      color: context.colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            points[i].$2,
                            style: context.texts.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            points[i].$3,
                            style: context.texts.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (result.notes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 16,
                      color: context.colors.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.notes!,
                        style: context.texts.labelSmall?.copyWith(
                          color: context.colors.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
