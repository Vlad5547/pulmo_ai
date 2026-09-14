import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/formatters.dart';
import '../models/analysis_record.dart';

/// One row of the history list (also reused for "recent activity" on Home).
class AnalysisTile extends StatelessWidget {
  const AnalysisTile({
    super.key,
    required this.record,
    required this.onTap,
    this.onDelete,
  });

  final AnalysisRecord record;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final clinical = context.clinical;
    final positive = record.result.isPositive;
    final accent = positive ? clinical.finding : clinical.clear;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _Thumbnail(path: record.imagePath, accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.result.verdict.label,
                      style: context.texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.imageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _MetaChip(
                          icon: Icons.schedule,
                          label: formatRelative(record.createdAt),
                        ),
                        const SizedBox(width: 8),
                        _MetaChip(
                          icon: Icons.query_stats,
                          label: '${record.result.confidencePercent}%',
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.colors.onSurfaceVariant,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: context.colors.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path, required this.accent});

  final String? path;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final file = path;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: context.clinical.scanBackdrop,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: file != null && file.isNotEmpty
          ? Image.file(
              File(file),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(accent),
            )
          : _fallback(accent),
    );
  }

  Widget _fallback(Color accent) => Center(
    child: Icon(
      Icons.airline_seat_flat_outlined,
      size: 24,
      color: accent.withValues(alpha: 0.8),
    ),
  );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 5),
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
