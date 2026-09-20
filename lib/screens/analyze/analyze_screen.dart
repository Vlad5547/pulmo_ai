import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/service_locator.dart';
import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/analysis_record.dart';
import '../../models/xray_image.dart';
import '../../services/onnx_analysis_service.dart';
import '../../services/radiograph_decoder.dart';
import '../../widgets/image_source_sheet.dart';
import '../../widgets/info_note.dart';
import '../../widgets/responsive_content.dart';
import '../../widgets/scanning_overlay.dart';
import '../../widgets/section_title.dart';
import '../../widgets/xray_viewer.dart';
import 'widgets/analysis_progress.dart';

enum _Stage { idle, running, failed }

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key, this.initialImage});

  final XRayImage? initialImage;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  XRayImage? _image;
  _Stage _stage = _Stage.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage;
  }

  bool get _isRunning => _stage == _Stage.running;

  Future<void> _replaceImage() async {
    if (_isRunning) return;
    final picked = await pickXRayImage(context);
    if (picked == null || !mounted) return;
    setState(() {
      _image = picked;
      _stage = _Stage.idle;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null || _isRunning) return;

    setState(() {
      _stage = _Stage.running;
      _error = null;
    });

    final services = AppServices.of(context);
    try {
      await services.analysisService.warmUp();
      final result = await services.analysisService.analyze(image);
      if (!mounted) return;

      final record = AnalysisRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        imageName: image.name,
        imagePath: image.previewPath,
        isDicom: image.isDicom,
        createdAt: DateTime.now(),
        result: result,
      );
      // The record is stored before navigating, so a result the user can see
      // is also a result that survived the app being killed on the next screen.
      await services.historyRepository.add(record);
      if (!mounted) return;

      await Navigator.pushReplacementNamed(
        context,
        AppRoutes.result,
        arguments: record,
      );
    } catch (error) {
      if (!mounted) return;
      // The screen returns to the idle state, so the image stays selected and
      // the user can simply press Analyze again.
      setState(() {
        _stage = _Stage.failed;
        _error = _describe(error, AppL10n.of(context));
      });
    }
  }

  /// Turns backend exceptions into something worth showing on screen.
  String _describe(Object error, AppL10n l10n) {
    if (error is ModelUnavailableException) {
      return l10n.errorModelUnavailable(error.message);
    }
    if (error is RadiographDecodeException) {
      return switch (error.error) {
        RadiographDecodeError.empty => l10n.errorEmptyFile,
        RadiographDecodeError.unsupportedFormat =>
          l10n.errorUnsupported(error.message),
        RadiographDecodeError.corrupt => l10n.errorCorrupt(error.message),
      };
    }
    return l10n.errorAnalysisFailed('$error');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final image = _image;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analyzeTitle),
        actions: [
          if (image != null)
            TextButton.icon(
              onPressed: _isRunning ? null : _replaceImage,
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(l10n.analyzeReplace),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(l10n.analyzeSelectedStudy),
              XRayViewer(
                image: image?.provider,
                overlay: _isRunning ? const ScanningOverlay() : null,
                topLeftBadge: image == null
                    ? null
                    : ScanBadge(
                        label: _isRunning
                            ? l10n.analyzeStatusAnalysing
                            : l10n.analyzeStatusReady,
                        icon: _isRunning
                            ? Icons.blur_on
                            : Icons.check_circle_outline,
                        color: _isRunning
                            ? context.colors.primary
                            : Colors.black,
                      ),
                placeholder: _EmptyScanPlaceholder(onPick: _replaceImage),
              ),
              const SizedBox(height: 14),
              if (image != null) _FileMeta(image: image),
              const SizedBox(height: 20),
              if (_isRunning)
                const AnalysisProgress()
              else ...[
                FilledButton.icon(
                  onPressed: image == null ? null : _analyze,
                  icon: const Icon(Icons.biotech_outlined),
                  label: Text(l10n.analyzeRun),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _replaceImage,
                  icon: Icon(
                    image == null
                        ? Icons.add_photo_alternate_outlined
                        : Icons.swap_horiz,
                  ),
                  label: Text(
                    image == null
                        ? l10n.analyzeSelectImage
                        : l10n.analyzeReplaceImage,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                InfoNote(
                  icon: Icons.error_outline,
                  title: l10n.analyzeErrorTitle,
                  text: _error!,
                  color: context.clinical.finding,
                ),
              ],
              const SizedBox(height: 20),
              InfoNote(
                icon: Icons.tips_and_updates_outlined,
                title: l10n.analyzeTipsTitle,
                text: l10n.analyzeTipsText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyScanPlaceholder extends StatelessWidget {
  const _EmptyScanPlaceholder({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 42,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.analyzeNoImageTitle,
            style: context.texts.titleSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.analyzeNoImageText,
            style: context.texts.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onPick,
            child: Text(l10n.analyzeBrowse),
          ),
        ],
      ),
    );
  }
}

class _FileMeta extends StatelessWidget {
  const _FileMeta({required this.image});

  final XRayImage image;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.description_outlined,
          size: 16,
          color: context.colors.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            image.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.texts.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
