import 'dart:math' as math;

import '../../domain/shapes/shape_kind.dart';
import '../../domain/shapes/shape_picture.dart';

/// A number written into SVG: at most one decimal, no trailing `.0`.
String svgNumber(double value) {
  final text = value.toStringAsFixed(1);
  if (text == '-0.0') return '0';
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

String _n(double value) => svgNumber(value);

(double, double) _toward((double, double) p, (double, double) q, double r) {
  final dx = q.$1 - p.$1, dy = q.$2 - p.$2;
  final length = math.sqrt(dx * dx + dy * dy);
  final k = math.min(r, length / 2.2) / length;
  return (p.$1 + dx * k, p.$2 + dy * k);
}

/// A polygon with softly rounded corners.
String _roundPolygon(List<(double, double)> points, double radius) {
  final out = StringBuffer();
  for (var i = 0; i < points.length; i++) {
    final previous = points[(i - 1 + points.length) % points.length];
    final corner = points[i];
    final next = points[(i + 1) % points.length];
    final a = _toward(corner, previous, radius), b = _toward(corner, next, radius);
    out.write('${i == 0 ? 'M' : 'L'}${_n(a.$1)} ${_n(a.$2)}'
        'Q${_n(corner.$1)} ${_n(corner.$2)} ${_n(b.$1)} ${_n(b.$2)}');
  }
  return '${out}Z';
}

/// The outline of [kind] filling a box of [width] × [height], upright: a
/// triangle points up, a semicircle sits on its flat side, a crescent opens
/// to the right. The same shapes as `shapePath` in the prototype.
String shapePathData(ShapeKind kind, double width, double height) {
  final w = width, h = height, m = math.min(w, h);
  String x(double v) => _n(v * w / 100);
  String y(double v) => _n(v * h / 100);
  switch (kind) {
    case ShapeKind.circle || ShapeKind.oval:
      return 'M0 ${_n(h / 2)}A${_n(w / 2)} ${_n(h / 2)} 0 1 1 ${_n(w)} ${_n(h / 2)}'
          'A${_n(w / 2)} ${_n(h / 2)} 0 1 1 0 ${_n(h / 2)}Z';
    case ShapeKind.square || ShapeKind.rectangle:
      return _roundPolygon([(0, 0), (w, 0), (w, h), (0, h)], m * .16);
    case ShapeKind.triangle:
      return _roundPolygon([(w / 2, 0), (w, h), (0, h)], m * .14);
    case ShapeKind.rhombus:
      return _roundPolygon([(w / 2, 0), (w, h / 2), (w / 2, h), (0, h / 2)], m * .12);
    case ShapeKind.star:
      return _roundPolygon([
        for (var i = 0; i < 10; i++)
          (
            (math.cos(-math.pi / 2 + i * math.pi / 5) * (i.isOdd ? .5 : 1) + .951) / 1.902 * w,
            (math.sin(-math.pi / 2 + i * math.pi / 5) * (i.isOdd ? .5 : 1) + 1) / 1.809 * h,
          ),
      ], m * .06);
    case ShapeKind.heart:
      return 'M${x(50)} ${y(97)}C${x(22)} ${y(77)} ${x(1)} ${y(58)} ${x(1)} ${y(33)}'
          'C${x(1)} ${y(14)} ${x(15)} ${y(2)} ${x(29)} ${y(2)}'
          'C${x(39)} ${y(2)} ${x(46)} ${y(8)} ${x(50)} ${y(17)}'
          'C${x(54)} ${y(8)} ${x(61)} ${y(2)} ${x(71)} ${y(2)}'
          'C${x(85)} ${y(2)} ${x(99)} ${y(14)} ${x(99)} ${y(33)}'
          'C${x(99)} ${y(58)} ${x(78)} ${y(77)} ${x(50)} ${y(97)}Z';
    case ShapeKind.semicircle:
      return 'M0 ${_n(h)}A${_n(w / 2)} ${_n(h)} 0 0 1 ${_n(w)} ${_n(h)}Z';
    case ShapeKind.crescent:
      return 'M${x(62)} ${y(3)}A${x(47)} ${y(47)} 0 1 0 ${x(62)} ${y(97)}'
          'A${x(52)} ${y(52)} 0 0 1 ${x(62)} ${y(3)}Z';
  }
}

/// Moves the upright shape (drawn from 0,0) into its slot, turned.
String slotTransform(ShapeSlot slot) {
  final up = slot.upright;
  final center = slot.box.center;
  return 'translate(${_n(center.x)} ${_n(center.y)}) rotate(${slot.quarterTurns * 90}) '
      'translate(${_n(-up.width / 2)} ${_n(-up.height / 2)})';
}
