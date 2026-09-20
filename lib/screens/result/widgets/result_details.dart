import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/analysis_record.dart';

/// Key/value block with the technical metadata of the run.
class ResultDetails extends StatelessWidget {
  const ResultDetails({super.key, required this.record});

  final AnalysisRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final result = record.result;
    final rows = <(String, String)>[
      (l10n.detailsStudy, record.imageName),
      (
        l10n.detailsSource,
        record.isDicom ? 'DICOM' : 'PNG / JPEG',
      ),
      (l10n.detailsAnalysed, formatDateTime(record.createdAt, locale)),
      (l10n.detailsModel, '${result.modelName} v${result.modelVersion}'),
      (l10n.detailsInferenceTime, formatDuration(result.processingTime)),
      (
        l10n.detailsHeatmap,
        result.hasHeatmap ? l10n.detailsAvailable : l10n.detailsNotAvailable,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        rows[i].$1,
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rows[i].$2,
                        textAlign: TextAlign.end,
                        style: context.texts.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
