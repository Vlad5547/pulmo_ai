import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/analysis_record.dart';
import '../../widgets/detection_overlay.dart';
import '../../widgets/info_note.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/section_title.dart';
import '../../widgets/xray_viewer.dart';
import 'widgets/result_details.dart';
import 'widgets/verdict_card.dart';

/// How the model output is drawn on top of the scan. The heatmap mode is a
/// placeholder today; Grad-CAM output will render through the same widget.
enum OverlayMode {
  off('Original', Icons.visibility_off_outlined),
  boxes('Bounding box', Icons.crop_free),
  heatmap('Heatmap', Icons.blur_on);

  const OverlayMode(this.label, this.icon);

  final String label;
  final IconData icon;
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.record});

  final AnalysisRecord record;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  OverlayMode _mode = OverlayMode.heatmap;

  AnalysisRecord get _record => widget.record;

  @override
  Widget build(BuildContext context) {
    final result = _record.result;
    final clinical = context.clinical;
    final accent = result.isPositive ? clinical.finding : clinical.clear;
    final path = _record.imagePath;
    final hasBoxes = result.boxes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis result'),
        actions: [
          IconButton(
            tooltip: 'Back to home',
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
                  label: result.verdict.label,
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
                overlay: _mode == OverlayMode.off
                    ? null
                    : DetectionOverlay(
                        boxes: result.boxes,
                        color: accent,
                        showHeatmap: _mode == OverlayMode.heatmap,
                        showBoxes: true,
                      ),
              ),
              const SizedBox(height: 14),
              _OverlayModeSelector(
                mode: _mode,
                enabled: hasBoxes,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              const SizedBox(height: 8),
              Text(
                hasBoxes
                    ? 'Visualization layer — bounding boxes come from the '
                          'detector; the heatmap is a placeholder for the '
                          'Grad-CAM output of the trained model.'
                    : 'No region of interest was produced for this study, so '
                          'there is nothing to overlay.',
                style: context.texts.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              VerdictCard(result: result),
              const SizedBox(height: 24),
              const SectionTitle('What this means'),
              _Interpretation(record: _record),
              const SizedBox(height: 24),
              const SectionTitle('Study details'),
              ResultDetails(record: _record),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.analyze,
                ),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('Analyze another X-ray'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.popUntil(
                  context,
                  ModalRoute.withName(AppRoutes.root),
                ),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to home'),
              ),
              const SizedBox(height: 20),
              InfoNote(
                icon: Icons.gavel_outlined,
                title: 'Not a diagnosis',
                text:
                    'This output is generated by a research prototype '
                    '(currently a mock model) and must be confirmed by a '
                    'qualified radiologist before any clinical action.',
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
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final OverlayMode mode;
  final bool enabled;
  final ValueChanged<OverlayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<OverlayMode>(
      segments: [
        for (final option in OverlayMode.values)
          ButtonSegment(
            value: option,
            icon: Icon(option.icon, size: 17),
            label: Text(option.label),
          ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
    );
  }
}

class _Interpretation extends StatelessWidget {
  const _Interpretation({required this.record});

  final AnalysisRecord record;

  @override
  Widget build(BuildContext context) {
    final result = record.result;
    final positive = result.isPositive;
    final points = positive
        ? const [
            (
              Icons.search,
              'Finding',
              'The model found an area of increased opacity that resembles '
                  'the consolidation patterns of pneumonia in the training '
                  'data.',
            ),
            (
              Icons.route_outlined,
              'Suggested next step',
              'Correlate with symptoms, auscultation and inflammatory '
                  'markers; a radiologist read is required for a diagnosis.',
            ),
            (
              Icons.help_outline,
              'Limitations',
              'Other conditions (oedema, atelectasis, tumours) can produce a '
                  'similar appearance and may be reported as pneumonia.',
            ),
          ]
        : const [
            (
              Icons.check_circle_outline,
              'Finding',
              'No opacity typical of pneumonia was detected on this '
                  'radiograph.',
            ),
            (
              Icons.route_outlined,
              'Suggested next step',
              'A negative screen does not rule out infection. If symptoms '
                  'persist, repeat imaging or further tests may be needed.',
            ),
            (
              Icons.help_outline,
              'Limitations',
              'Early or subtle infiltrates and non-frontal projections can be '
                  'missed by the model.',
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
