import 'package:flutter/material.dart';

import '../models/analysis_result.dart';

/// Draws model output on top of the X-ray: a soft heatmap blob plus a bounding
/// box per detection. Coordinates are normalised, so this widget works at any
/// size and is ready for real Grad-CAM / detector output later.
class DetectionOverlay extends StatelessWidget {
  const DetectionOverlay({
    super.key,
    required this.boxes,
    required this.color,
    this.showHeatmap = true,
    this.showBoxes = true,
  });

  final List<DetectionBox> boxes;
  final Color color;
  final bool showHeatmap;
  final bool showBoxes;

  @override
  Widget build(BuildContext context) {
    if (boxes.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _DetectionPainter(
          boxes: boxes,
          color: color,
          showHeatmap: showHeatmap,
          showBoxes: showBoxes,
          labelStyle: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DetectionPainter extends CustomPainter {
  _DetectionPainter({
    required this.boxes,
    required this.color,
    required this.showHeatmap,
    required this.showBoxes,
    required this.labelStyle,
  });

  final List<DetectionBox> boxes;
  final Color color;
  final bool showHeatmap;
  final bool showBoxes;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final rect = Rect.fromLTWH(
        box.left * size.width,
        box.top * size.height,
        box.width * size.width,
        box.height * size.height,
      );

      if (showHeatmap) {
        final blob = rect.inflate(rect.shortestSide * 0.35);
        canvas.drawRect(
          blob,
          Paint()
            ..shader = RadialGradient(
              colors: [
                color.withValues(alpha: 0.55),
                color.withValues(alpha: 0.22),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(blob)
            ..blendMode = BlendMode.plus,
        );
      }

      if (!showBoxes) continue;

      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: '${box.label} · ${(box.score * 100).round()}%',
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      final tag = Rect.fromLTWH(
        rect.left,
        (rect.top - painter.height - padding.vertical - 6).clamp(0, size.height),
        painter.width + padding.horizontal,
        painter.height + padding.vertical,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(tag, const Radius.circular(6)),
        Paint()..color = color,
      );
      painter.paint(canvas, Offset(tag.left + padding.left, tag.top + padding.top));
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter old) =>
      old.boxes != boxes ||
      old.color != color ||
      old.showHeatmap != showHeatmap ||
      old.showBoxes != showBoxes;
}
