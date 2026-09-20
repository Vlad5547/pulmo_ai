import 'package:flutter/material.dart';

import '../app/service_locator.dart';
import '../app/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/xray_image.dart';
import '../services/image_source_service.dart';
import '../services/radiograph_decoder.dart';

/// Asks the user where the X-ray comes from and returns the picked image,
/// or null if the flow was cancelled or the file could not be read.
///
/// Decoding happens here rather than at analysis time so an unreadable file is
/// rejected while the user still has the picker in mind, with a message that
/// says what was wrong with it.
Future<XRayImage?> pickXRayImage(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final services = AppServices.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final source = await showModalBottomSheet<XRaySource>(
    context: context,
    showDragHandle: true,
    builder: (context) => const _ImageSourceSheet(),
  );
  if (source == null) return null;

  try {
    return switch (source) {
      XRaySource.gallery => await services.imageSourceService.pickFromGallery(),
      XRaySource.camera =>
        await services.imageSourceService.captureWithCamera(),
      XRaySource.file => await services.imageSourceService.pickFile(),
    };
  } on RadiographDecodeException catch (error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message),
        duration: const Duration(seconds: 6),
      ),
    );
    return null;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.sheetOpenError('$error'))),
    );
    return null;
  }
}

class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sheetTitle,
              style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.sheetSubtitle,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _SourceTile(
              icon: Icons.folder_open_outlined,
              title: l10n.sheetDicomTitle,
              subtitle: l10n.sheetDicomSubtitle,
              onTap: () => Navigator.pop(context, XRaySource.file),
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: l10n.sheetGalleryTitle,
              subtitle: l10n.sheetGallerySubtitle,
              onTap: () => Navigator.pop(context, XRaySource.gallery),
            ),
            const SizedBox(height: 10),
            _SourceTile(
              icon: Icons.photo_camera_outlined,
              title: l10n.sheetCameraTitle,
              subtitle: l10n.sheetCameraSubtitle,
              onTap: () => Navigator.pop(context, XRaySource.camera),
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
