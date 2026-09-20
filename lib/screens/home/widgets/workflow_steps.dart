import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// "How it works" explainer shown on the home screen.
class WorkflowSteps extends StatelessWidget {
  const WorkflowSteps({super.key});

  static List<({IconData icon, String title, String description})> _steps(
    AppL10n l10n,
  ) =>
      [
        (
          icon: Icons.upload_file_outlined,
          title: l10n.stepAddTitle,
          description: l10n.stepAddText,
        ),
        (
          icon: Icons.memory_outlined,
          title: l10n.stepRunTitle,
          description: l10n.stepRunText,
        ),
        (
          icon: Icons.insights_outlined,
          title: l10n.stepReviewTitle,
          description: l10n.stepReviewText,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final steps = _steps(AppL10n.of(context));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0) const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        steps[i].icon,
                        size: 19,
                        color: context.colors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1}. ${steps[i].title}',
                            style: context.texts.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            steps[i].description,
                            style: context.texts.bodySmall?.copyWith(
                              color: context.colors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
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
