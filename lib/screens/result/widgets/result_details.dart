import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/formatters.dart';
import '../../../models/analysis_record.dart';

/// Key/value block with the technical metadata of the run.
class ResultDetails extends StatelessWidget {
  const ResultDetails({super.key, required this.record});

  final AnalysisRecord record;

  @override
  Widget build(BuildContext context) {
    final result = record.result;
    final rows = <(String, String)>[
      ('Study', record.imageName),
      ('Analysed', formatDateTime(record.createdAt)),
      ('Model', '${result.modelName} v${result.modelVersion}'),
      ('Inference time', formatDuration(result.processingTime)),
      (
        'Regions of interest',
        result.boxes.isEmpty ? 'None' : '${result.boxes.length}',
      ),
      (
        'Model heatmap',
        result.hasHeatmap ? 'Available' : 'Not available',
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
