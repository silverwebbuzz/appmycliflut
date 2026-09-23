import 'package:flutter/material.dart';

/// The design's stroked line-icon set.
///
/// The prototype draws every glyph as a 24x24 stroked SVG at 1.9px. Material's
/// filled/rounded icons read noticeably heavier next to the monochrome
/// surfaces, so the handful of glyphs the app needs are drawn here instead,
/// keeping one visual language across the nav bar and the screens.
enum AppGlyph {
  person,
  chevronRight,
  plus,
  flask,
  document,
  prescription,
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.glyph, {super.key, this.size = 20, this.color});

  final AppGlyph glyph;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: glyph,
          color: color ?? IconTheme.of(context).color ?? const Color(0xFF0E0E0F),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.glyph, required this.color});

  final AppGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24.0);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    switch (glyph) {
      case AppGlyph.person:
        // circle(12,8,4) + M4.5 20.5c1.5-4 4.5-5.5 7.5-5.5s6 1.5 7.5 5.5
        canvas.drawCircle(const Offset(12, 8), 4, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 20.5)
            ..cubicTo(6, 16.5, 9, 15, 12, 15)
            ..cubicTo(15, 15, 18, 16.5, 19.5, 20.5),
          stroke,
        );

      case AppGlyph.chevronRight:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 5.5)
            ..lineTo(16, 12)
            ..lineTo(9.5, 18.5),
          // Chevrons read thin at small sizes, so this one is heavier.
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color,
        );

      case AppGlyph.plus:
        canvas.drawLine(const Offset(12, 6), const Offset(12, 18), stroke);
        canvas.drawLine(const Offset(6, 12), const Offset(18, 12), stroke);

      case AppGlyph.flask:
        canvas.drawPath(
          Path()
            ..moveTo(9.5, 3)
            ..lineTo(9.5, 9)
            ..lineTo(4.8, 17.6)
            ..cubicTo(4.1, 18.9, 5.1, 20.5, 6.6, 20.5)
            ..lineTo(17.4, 20.5)
            ..cubicTo(18.9, 20.5, 19.9, 18.9, 19.2, 17.6)
            ..lineTo(14.5, 9)
            ..lineTo(14.5, 3),
          stroke,
        );
        canvas.drawLine(const Offset(8, 3), const Offset(16, 3), stroke);

      case AppGlyph.document:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 3, 14, 18),
            const Radius.circular(2.5),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(9, 8), const Offset(15, 8), stroke);
        canvas.drawLine(const Offset(9, 12), const Offset(15, 12), stroke);
        canvas.drawLine(const Offset(9, 16), const Offset(13, 16), stroke);

      case AppGlyph.prescription:
        // Rx mark: stem, bowl and the descending stroke.
        canvas.drawPath(
          Path()
            ..moveTo(7, 20)
            ..lineTo(7, 5)
            ..lineTo(11.5, 5)
            ..cubicTo(14.5, 5, 14.5, 11, 11.5, 11)
            ..lineTo(7, 11),
          stroke,
        );
        canvas.drawLine(const Offset(11.5, 11), const Offset(18, 20), stroke);
        canvas.drawLine(const Offset(18, 12.5), const Offset(12.5, 20), stroke);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.glyph != glyph;
}
