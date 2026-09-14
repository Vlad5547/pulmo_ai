import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Standard frame for a chest X-ray: dark backdrop, fixed aspect ratio,
/// rounded corners and optional overlays (detections, loading, badges).
class XRayViewer extends StatelessWidget {
  const XRayViewer({
    super.key,
    this.image,
    this.aspectRatio = 4 / 5,
    this.overlay,
    this.topLeftBadge,
    this.topRightBadge,
    this.placeholder,
    this.borderColor,
  });

  final ImageProvider? image;
  final double aspectRatio;
  final Widget? overlay;
  final Widget? topLeftBadge;
  final Widget? topRightBadge;
  final Widget? placeholder;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final clinical = context.clinical;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: clinical.scanBackdrop,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor ?? context.colors.outlineVariant,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                Image(image: image!, fit: BoxFit.contain)
              else
                placeholder ?? const _ScanPlaceholder(),
              ?overlay,
              if (topLeftBadge != null)
                Positioned(top: 12, left: 12, child: topLeftBadge!),
              if (topRightBadge != null)
                Positioned(top: 12, right: 12, child: topRightBadge!),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanPlaceholder extends StatelessWidget {
  const _ScanPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 40,
            color: Colors.white.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            'Image not available on this device',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small translucent chip used for overlay labels on top of a scan.
class ScanBadge extends StatelessWidget {
  const ScanBadge({super.key, required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = (color ?? Colors.black).withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
