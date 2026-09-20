import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Loading state for the analyze screen: an indeterminate bar plus the
/// pipeline stages ticking over, so a two second wait still feels informative.
class AnalysisProgress extends StatefulWidget {
  const AnalysisProgress({super.key});

  @override
  State<AnalysisProgress> createState() => _AnalysisProgressState();
}

class _AnalysisProgressState extends State<AnalysisProgress> {
  static List<String> _stages(AppL10n l10n) => [
        l10n.progressPreparing,
        l10n.progressNormalising,
        l10n.progressInference,
        l10n.progressReport,
      ];

  /// How long each label stays up. The stages are indicative: inference is one
  /// opaque call into ONNX Runtime, so the UI cannot observe its real phases.
  static const _stageDuration = Duration(milliseconds: 550);
  static const _stageCount = 4;

  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_stageDuration, (timer) {
      if (_current >= _stageCount - 1) {
        timer.cancel();
        return;
      }
      setState(() => _current++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final stages = _stages(l10n);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: context.colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.progressRunning,
                  style: context.texts.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const LinearProgressIndicator(minHeight: 6),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < stages.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      i < _current
                          ? Icons.check_circle
                          : i == _current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 17,
                      color: i <= _current
                          ? context.colors.primary
                          : context.colors.outline,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      stages[i],
                      style: context.texts.bodyMedium?.copyWith(
                        color: i <= _current
                            ? context.colors.onSurface
                            : context.colors.onSurfaceVariant,
                        fontWeight: i == _current
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
