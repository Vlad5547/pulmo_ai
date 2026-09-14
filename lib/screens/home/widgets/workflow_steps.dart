import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// "How it works" explainer shown on the home screen.
class WorkflowSteps extends StatelessWidget {
  const WorkflowSteps({super.key});

  static const _steps = <({IconData icon, String title, String description})>[
    (
      icon: Icons.upload_file_outlined,
      title: 'Add the study',
      description:
          'Pick a chest X-ray from the gallery or capture it with the camera.',
    ),
    (
      icon: Icons.memory_outlined,
      title: 'Run the model',
      description:
          'The image is normalised and passed to the pneumonia detection '
          'model.',
    ),
    (
      icon: Icons.insights_outlined,
      title: 'Review the result',
      description:
          'Get a verdict, a confidence score and the regions that drove it.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
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
                        _steps[i].icon,
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
                            '${i + 1}. ${_steps[i].title}',
                            style: context.texts.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _steps[i].description,
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
