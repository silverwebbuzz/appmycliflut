import 'dart:math' as math;

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
  search,
  pin,
  calendar,
  chevronLeft,
  star,
  cart,
  heart,
  heartFilled,
  check,
  trash,
  attach,
  close,
  truck,
  phone,
  people,
  clock,
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
    final fill = Paint()
      ..style = PaintingStyle.fill
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

      case AppGlyph.star:
        // Filled five-point star. Neither Sora nor Manrope ships U+2605,
        // so the rating mark is drawn rather than typed.
        final star = Path();
        const cx = 12.0, cy = 12.0, outer = 8.4, inner = 3.6;
        for (var i = 0; i < 10; i++) {
          final r = i.isEven ? outer : inner;
          final a = -math.pi / 2 + i * math.pi / 5;
          final x = cx + r * math.cos(a);
          final y = cy + r * math.sin(a);
          i == 0 ? star.moveTo(x, y) : star.lineTo(x, y);
        }
        star.close();
        canvas.drawPath(star, fill);

      case AppGlyph.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 5.5)
            ..lineTo(8, 12)
            ..lineTo(14.5, 18.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color,
        );

      case AppGlyph.search:
        canvas.drawCircle(const Offset(11, 11), 6.5, stroke);
        canvas.drawLine(const Offset(16, 16), const Offset(21, 21), stroke);

      case AppGlyph.pin:
        // Map pin: teardrop body with an inner circle.
        canvas.drawPath(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(12, 21, 18.5, 14.8, 18.5, 10.5)
            ..cubicTo(18.5, 6.9, 15.6, 4, 12, 4)
            ..cubicTo(8.4, 4, 5.5, 6.9, 5.5, 10.5)
            ..cubicTo(5.5, 14.8, 12, 21, 12, 21)
            ..close(),
          stroke,
        );
        canvas.drawCircle(const Offset(12, 10.3), 2.4, stroke);

      case AppGlyph.calendar:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(4, 5.5, 16, 15),
            const Radius.circular(2.5),
          ),
          stroke,
        );
        canvas.drawLine(const Offset(8, 3.5), const Offset(8, 7), stroke);
        canvas.drawLine(const Offset(16, 3.5), const Offset(16, 7), stroke);
        canvas.drawLine(const Offset(4, 10), const Offset(20, 10), stroke);

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

      case AppGlyph.cart:
        // Prototype: M4 5h2.2l2.2 10.5h9.1L20 8H7 + two wheels.
        canvas.drawPath(
          Path()
            ..moveTo(4, 5)
            ..lineTo(6.2, 5)
            ..lineTo(8.4, 15.5)
            ..lineTo(17.5, 15.5)
            ..lineTo(20, 8)
            ..lineTo(7, 8),
          stroke,
        );
        canvas.drawCircle(const Offset(10, 19.2), 1.4, fill);
        canvas.drawCircle(const Offset(17, 19.2), 1.4, fill);

      case AppGlyph.heart:
      case AppGlyph.heartFilled:
        final heart = Path()
          ..moveTo(12, 20)
          ..cubicTo(12, 20, 3.5, 14.8, 3.5, 9)
          ..cubicTo(3.5, 6.2, 5.6, 4.2, 8.1, 4.2)
          ..cubicTo(9.8, 4.2, 11.2, 5.1, 12, 6.5)
          ..cubicTo(12.8, 5.1, 14.2, 4.2, 15.9, 4.2)
          ..cubicTo(18.4, 4.2, 20.5, 6.2, 20.5, 9)
          ..cubicTo(20.5, 14.8, 12, 20, 12, 20)
          ..close();
        canvas.drawPath(heart, glyph == AppGlyph.heartFilled ? fill : stroke);

      case AppGlyph.check:
        // Prototype success tick: M4.5 12.5l5 5 10-11
        canvas.drawPath(
          Path()
            ..moveTo(4.5, 12.5)
            ..lineTo(9.5, 17.5)
            ..lineTo(19.5, 6.5),
          stroke,
        );

      case AppGlyph.trash:
        canvas.drawLine(const Offset(4.5, 6.5), const Offset(19.5, 6.5), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(9, 6.5)
            ..lineTo(9, 4)
            ..lineTo(15, 4)
            ..lineTo(15, 6.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(6.5, 6.5)
            ..lineTo(7.4, 19)
            ..cubicTo(7.5, 19.9, 8.2, 20.5, 9.1, 20.5)
            ..lineTo(14.9, 20.5)
            ..cubicTo(15.8, 20.5, 16.5, 19.9, 16.6, 19)
            ..lineTo(17.5, 6.5),
          stroke,
        );

      case AppGlyph.attach:
        // Paperclip.
        canvas.drawPath(
          Path()
            ..moveTo(19, 11.5)
            ..lineTo(12.2, 18.3)
            ..cubicTo(10.2, 20.3, 7, 20.3, 5, 18.3)
            ..cubicTo(3, 16.3, 3, 13.1, 5, 11.1)
            ..lineTo(11.8, 4.3)
            ..cubicTo(13.2, 2.9, 15.4, 2.9, 16.8, 4.3)
            ..cubicTo(18.2, 5.7, 18.2, 7.9, 16.8, 9.3)
            ..lineTo(10.1, 16)
            ..cubicTo(9.4, 16.7, 8.3, 16.7, 7.6, 16)
            ..cubicTo(6.9, 15.3, 6.9, 14.2, 7.6, 13.5)
            ..lineTo(13.8, 7.3),
          stroke,
        );

      case AppGlyph.close:
        canvas.drawLine(const Offset(6.5, 6.5), const Offset(17.5, 17.5), stroke);
        canvas.drawLine(const Offset(17.5, 6.5), const Offset(6.5, 17.5), stroke);

      case AppGlyph.truck:
        // Prototype order glyph: M3 7h11v9H3zM14 10h4l3 3v3h-7z + wheels.
        canvas.drawPath(
          Path()
            ..addRect(const Rect.fromLTRB(3, 7, 14, 16))
            ..moveTo(14, 10)
            ..lineTo(18, 10)
            ..lineTo(21, 13)
            ..lineTo(21, 16)
            ..lineTo(14, 16)
            ..close(),
          stroke,
        );
        canvas.drawCircle(const Offset(7, 18), 1.6, fill);
        canvas.drawCircle(const Offset(17.5, 18), 1.6, fill);

      case AppGlyph.phone:
        canvas.drawPath(
          Path()
            ..moveTo(5, 4.5)
            ..lineTo(8.5, 4.5)
            ..lineTo(10, 8.5)
            ..lineTo(8, 10)
            ..cubicTo(9, 12.2, 11.8, 15, 14, 16)
            ..lineTo(15.5, 14)
            ..lineTo(19.5, 15.5)
            ..lineTo(19.5, 19)
            ..cubicTo(19.5, 19.8, 18.8, 20.5, 18, 20.5)
            ..cubicTo(10.5, 20, 4, 13.5, 3.5, 6)
            ..cubicTo(3.5, 5.2, 4.2, 4.5, 5, 4.5)
            ..close(),
          stroke,
        );

      case AppGlyph.people:
        canvas.drawCircle(const Offset(9, 8.5), 3.2, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(3, 19.5)
            ..cubicTo(4, 16.3, 6.3, 14.8, 9, 14.8)
            ..cubicTo(11.7, 14.8, 14, 16.3, 15, 19.5),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(15.5, 5.6)
            ..cubicTo(17.3, 5.9, 18.5, 7.3, 18.5, 9)
            ..cubicTo(18.5, 10.7, 17.3, 12.1, 15.5, 12.4)
            ..moveTo(17.5, 15.2)
            ..cubicTo(19.2, 15.8, 20.4, 17.3, 21, 19.5),
          stroke,
        );

      case AppGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8.5, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(12, 7.5)
            ..lineTo(12, 12)
            ..lineTo(15, 14),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.glyph != glyph;
}
