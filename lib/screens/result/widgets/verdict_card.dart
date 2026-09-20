import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/verdict_l10n.dart';
import '../../../models/analysis_result.dart';
import '../../../widgets/confidence_bar.dart';

/// Headline block of the result screen: verdict, confidence and a one-line
/// interpretation of what the number means.
class VerdictCard extends StatelessWidget {
  const VerdictCard({super.key, required this.result});

  final AnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final clinical = context.clinical;
    final positive = result.isPositive;
    final accent = positive ? clinical.finding : clinical.clear;
    final container = positive
        ? clinical.findingContainer
        : clinical.clearContainer;
    final onContainer = positive
        ? clinical.onFindingContainer
        : clinical.onClearContainer;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  positive
                      ? Icons.warning_amber_rounded
                      : Icons.verified_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.verdict.label(l10n),
                      style: context.texts.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: onContainer,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      result.verdict.description(l10n),
                      style: context.texts.bodySmall?.copyWith(
                        color: onContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ConfidenceBar(value: result.confidence, color: accent),
          const SizedBox(height: 14),
          Text(
            _confidenceHint(result, l10n),
            style: context.texts.bodySmall?.copyWith(
              color: onContainer.withValues(alpha: 0.85),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _confidenceHint(AnalysisResult result, AppL10n l10n) {
    final percent = result.confidencePercent;
    if (percent >= 90) return l10n.confidenceHigh;
    if (percent >= 75) return l10n.confidenceMedium;
    return l10n.confidenceLow;
  }
}
