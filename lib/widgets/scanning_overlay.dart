import 'package:flutter/material.dart';

/// Loading state drawn over the scan while inference runs: a sweeping scan
/// line plus a dimming veil.
class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key, this.color});

  final Color? color;

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Align(
                alignment: Alignment(0, _controller.value * 2 - 1),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.0),
                        color.withValues(alpha: 0.45),
                        color.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
