import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'shape_art.dart';

Color _hex(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

double _frac(double v) => v - v.floorToDouble();

/// Draws the little moving things of a finished picture — smoke, bubbles,
/// lights, a flame — in card units, [seconds] after it came alive.
class EffectsPainter extends CustomPainter {
  EffectsPainter(this.effects, this.seconds);

  final List<PictureEffect> effects;
  final double seconds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300);
    for (final effect in effects) {
      final t = seconds - effect.delay;
      if (t < 0) continue;
      _paint(canvas, effect, t);
    }
    canvas.restore();
  }

  // A value going 0 → 1 → 0 every [period] seconds.
  static double _swing(double t, double period) => .5 - .5 * math.cos(2 * math.pi * t / period);

  void _paint(Canvas canvas, PictureEffect e, double t) {
    final color = _hex(e.color);
    switch (e.kind) {
      case EffectKind.puff:
        final p = _frac(t / 1.6);
        canvas.drawCircle(Offset(e.x - 14 * p, e.y - 70 * p), 11 * (.6 + p),
            Paint()..color = const Color(0xFFEEF3F8).withValues(alpha: .95 * (1 - p)));
      case EffectKind.bubble:
        final p = _frac(t / 1.8);
        canvas.drawCircle(Offset(e.x + 10 * p, e.y - 90 * p), 6 * e.size * (.6 + .6 * p),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = Colors.white.withValues(alpha: 1 - p));
      case EffectKind.twinkle:
        final s = _swing(t, 1);
        final r = 9 * (.8 + .3 * s);
        canvas.drawCircle(Offset(e.x, e.y), r, Paint()..color = color.withValues(alpha: .3 + .7 * s));
        canvas.drawCircle(Offset(e.x, e.y), r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(alpha: .3 + .7 * s));
      case EffectKind.glow:
        canvas.drawCircle(Offset(e.x, e.y), 28, Paint()..color = const Color(0xFFFFF7B0).withValues(alpha: .3 + .45 * _swing(t, 1.8)));
      case EffectKind.flame:
        final stretch = .8 + .4 * _swing(t, .36);
        final flame = Path()
          ..moveTo(e.x - 24, e.y)
          ..quadraticBezierTo(e.x, e.y + 60 * stretch, e.x + 24, e.y)
          ..quadraticBezierTo(e.x, e.y + 16 * stretch, e.x - 24, e.y)
          ..close();
        canvas.drawPath(flame, Paint()..color = const Color(0xFFFFC929));
        canvas.drawPath(flame,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFFFF8A1F));
      case EffectKind.risingHeart:
        final p = _frac(t / 2.2);
        _heart(canvas, e.x + 16 * p, e.y - 60 * p, 22, 20, color.withValues(alpha: 1 - p));
      case EffectKind.zz:
        final p = _frac(t / 2.2);
        final text = TextPainter(
          text: TextSpan(
            text: 'z',
            style: TextStyle(fontSize: 26 * e.size, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 1 - p)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(canvas, Offset(e.x + 16 * p, e.y - 26 * e.size - 60 * p));
      case EffectKind.cherry:
        final drop = Curves.easeOutBack.transform(math.min(1, t / .7));
        final y = e.y - 120 * (1 - drop);
        canvas.drawPath(
            Path()
              ..moveTo(e.x, y - 8)
              ..quadraticBezierTo(e.x + 6, y - 30, e.x + 20, y - 38),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xFF3FAE4F));
        canvas.drawCircle(Offset(e.x, y), 15, Paint()..color = const Color(0xFFE2553F));
        canvas.drawCircle(Offset(e.x, y), 15,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = const Color(0xFFB8301F));
        canvas.drawCircle(Offset(e.x - 5, y - 5), 4, Paint()..color = Colors.white.withValues(alpha: .6));
      case EffectKind.sparkle:
        final s = _swing(t, 1);
        final r = 9 * (.8 + .3 * s);
        final sparkle = Path()
          ..moveTo(e.x, e.y - r)
          ..quadraticBezierTo(e.x + r * .17, e.y - r * .17, e.x + r, e.y)
          ..quadraticBezierTo(e.x + r * .17, e.y + r * .17, e.x, e.y + r)
          ..quadraticBezierTo(e.x - r * .17, e.y + r * .17, e.x - r, e.y)
          ..quadraticBezierTo(e.x - r * .17, e.y - r * .17, e.x, e.y - r)
          ..close();
        canvas.drawPath(sparkle, Paint()..color = color.withValues(alpha: .3 + .7 * s));
      case EffectKind.speedLines:
        final paint = Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white;
        canvas
          ..drawLine(Offset(e.x - 6, e.y - 30), Offset(e.x + 16, e.y - 30), paint)
          ..drawLine(Offset(e.x - 16, e.y), Offset(e.x + 12, e.y), paint)
          ..drawLine(Offset(e.x - 4, e.y + 30), Offset(e.x + 18, e.y + 30), paint);
    }
  }

  // The same heart as the shape, in a w × h box at (x, y).
  static void _heart(Canvas canvas, double x, double y, double w, double h, Color color) {
    double px(double v) => x + v * w / 100;
    double py(double v) => y + v * h / 100;
    final heart = Path()
      ..moveTo(px(50), py(97))
      ..cubicTo(px(22), py(77), px(1), py(58), px(1), py(33))
      ..cubicTo(px(1), py(14), px(15), py(2), px(29), py(2))
      ..cubicTo(px(39), py(2), px(46), py(8), px(50), py(17))
      ..cubicTo(px(54), py(8), px(61), py(2), px(71), py(2))
      ..cubicTo(px(85), py(2), px(99), py(14), px(99), py(33))
      ..cubicTo(px(99), py(58), px(78), py(77), px(50), py(97))
      ..close();
    canvas.drawPath(heart, Paint()..color = color);
  }

  @override
  bool shouldRepaint(EffectsPainter old) => old.seconds != seconds || old.effects != effects;
}
