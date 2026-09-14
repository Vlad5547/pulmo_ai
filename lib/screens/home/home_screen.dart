import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/service_locator.dart';
import '../../app/theme.dart';
import '../../models/analysis_record.dart';
import '../../models/xray_image.dart';
import '../../widgets/analysis_tile.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/info_note.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/section_title.dart';
import 'widgets/hero_card.dart';
import 'widgets/stat_tile.dart';
import 'widgets/workflow_steps.dart';

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
    final history = AppServices.of(context).historyRepository;

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(),
        titleSpacing: 20,
        actions: [
          IconButton(
            tooltip: 'About PulmoAI',
            onPressed: () => _showAbout(context),
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
                  const SectionTitle('How it works'),
                  const WorkflowSteps(),
                  const SizedBox(height: 24),
                  if (records.isNotEmpty) ...[
                    SectionTitle(
                      'Recent analyses',
                      trailing: TextButton(
                        onPressed: onOpenHistory,
                        child: const Text('See all'),
                      ),
                    ),
                    for (final record in records.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnalysisTile(
                          record: record,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.result,
                            arguments: record,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                  ],
                  const InfoNote(
                    icon: Icons.health_and_safety_outlined,
                    title: 'Research prototype',
                    text:
                        'PulmoAI is a decision-support prototype built for a '
                        'master’s thesis on the RSNA Pneumonia Detection '
                        'Challenge dataset. It is not a medical device and '
                        'must not be used for diagnosis.',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'PulmoAI',
      applicationVersion: '1.0.0 (UI preview)',
      applicationIcon: const AppLogo(size: 40, showWordmark: false),
      children: const [
        SizedBox(height: 12),
        Text(
          'AI-based pneumonia detection from chest X-ray images. '
          'Analysis runs entirely on this device with PulmoNet-7M, a '
          'convolutional network trained from scratch on the RSNA '
          'Pneumonia Detection Challenge dataset. No image leaves the '
          'phone and no network connection is required.',
        ),
      ],
    );
  }
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

    final tiles = [
      StatTile(
        value: '${records.length}',
        label: 'Studies analysed',
        icon: Icons.folder_open_outlined,
      ),
      StatTile(
        value: '$findings',
        label: 'Findings flagged',
        icon: Icons.warning_amber_rounded,
        color: context.clinical.finding,
      ),
      StatTile(
        value: '${(avgConfidence * 100).round()}%',
        label: 'Avg. confidence',
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
