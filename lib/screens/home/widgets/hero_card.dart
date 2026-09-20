import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Primary call-to-action block on the home screen.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.onAnalyze,
    required this.onPickFromGallery,
  });

  final VoidCallback onAnalyze;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.tertiary, 0.75)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 13, color: colors.onPrimary),
                const SizedBox(width: 6),
                Text(
                  l10n.heroBadge,
                  style: context.texts.labelSmall?.copyWith(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.heroTitle,
            style: context.texts.headlineSmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.heroSubtitle,
            style: context.texts.bodyMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.9),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onAnalyze,
            icon: const Icon(Icons.biotech_outlined),
            label: Text(l10n.heroAnalyze),
            style: FilledButton.styleFrom(
              backgroundColor: colors.onPrimary,
              foregroundColor: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(l10n.heroGallery),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onPrimary,
              side: BorderSide(color: colors.onPrimary.withValues(alpha: 0.55)),
            ),
          ),
        ],
      ),
    );
  }
}
