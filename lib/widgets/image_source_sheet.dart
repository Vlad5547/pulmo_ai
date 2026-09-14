import 'package:flutter/material.dart';

import '../app/service_locator.dart';
import '../app/theme.dart';
import '../models/xray_image.dart';

enum _Source { gallery, camera }

/// Asks the user where the X-ray comes from and returns the picked image,
/// or null if the flow was cancelled.
Future<XRayImage?> pickXRayImage(BuildContext context) async {
  final services = AppServices.of(context);
  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _ImageSourceSheet(),
  );
  if (source == null) return null;

  try {
    return source == _Source.gallery
        ? await services.imageSourceService.pickFromGallery()
        : await services.imageSourceService.captureWithCamera();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the image source: $error')),
      );
    }
    return null;
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add chest X-ray',
              style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Use a PA or AP projection image for the most reliable result.',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              subtitle: 'PNG or JPEG export of the study',
              onTap: () => Navigator.pop(context, _Source.gallery),
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: Icons.photo_camera_outlined,
              title: 'Capture with camera',
              subtitle: 'Photograph a printed film or a monitor',
              onTap: () => Navigator.pop(context, _Source.camera),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: context.colors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.texts.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
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
