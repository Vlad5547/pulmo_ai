import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';

/// PulmoAI wordmark: a lung glyph in a soft container plus the product name.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 44, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Icon(
        Icons.monitor_heart_outlined,
        size: size * 0.58,
        color: colors.onPrimary,
      ),
    );

    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Pulmo'),
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(color: colors.primary),
                  ),
                ],
              ),
              style: context.texts.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              AppL10n.of(context).appTagline,
              style: context.texts.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
