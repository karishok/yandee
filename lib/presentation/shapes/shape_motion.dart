import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../domain/shapes/shape_picture.dart';

/// How long [motion] plays, once.
Duration motionDuration(PictureMotion motion) => Duration(
      milliseconds: switch (motion) {
        PictureMotion.wiggle => 1500,
        PictureMotion.hop => 1800,
        PictureMotion.chug => 2100,
        PictureMotion.drive => 2800,
        PictureMotion.launch => 3000,
        PictureMotion.swim => 2800,
        PictureMotion.rock => 3300,
        PictureMotion.sway => 3600,
        PictureMotion.pulse => 3000,
      },
    );

double _frac(double v) => v - v.floorToDouble();

/// Rounding can leave a curve input a hair outside 0…1.
double _unit(double v) => v.clamp(0.0, 1.0);

/// Where a finished picture is [t] (0…1) of the way through [motion]: a
/// transform in card units. Every motion starts and ends at rest; turning
/// motions turn around [pivot].
Matrix4 pictureMotion(PictureMotion motion, double t, ({double x, double y}) pivot) {
  Matrix4 turn(double degrees) => Matrix4.translationValues(pivot.x, pivot.y, 0)
    ..multiply(Matrix4.rotationZ(degrees * math.pi / 180))
    ..multiply(Matrix4.translationValues(-pivot.x, -pivot.y, 0));
  Matrix4 move(double x, double y) => Matrix4.translationValues(x, y, 0);

  switch (motion) {
    case PictureMotion.wiggle || PictureMotion.rock || PictureMotion.sway:
      return turn(-5 * math.sin(t * 3 * 2 * math.pi));
    case PictureMotion.hop:
      return move(0, -18 * math.sin(math.pi * _frac(t * 4)));
    case PictureMotion.chug:
      return move(0, -5 * math.sin(math.pi * _frac(t * 7)));
    case PictureMotion.drive:
      if (t < .42) return move(360 * Curves.easeIn.transform(_unit(t / .42)), 0);
      if (t < .43) return move(-360, 0);
      return move(-360 * (1 - Curves.easeOut.transform(_unit((t - .43) / .57))), 0);
    case PictureMotion.launch:
      if (t < .18) return move(2 * math.sin(t / .18 * 4 * math.pi), 0);
      if (t < .48) return move(0, -360 * Curves.easeIn.transform(_unit((t - .18) / .3)));
      if (t < .49) return move(0, 360);
      return move(0, 360 * (1 - Curves.easeOut.transform(_unit((t - .49) / .51))));
    case PictureMotion.swim:
      final a = _frac(t * 2) * 2 * math.pi;
      return move(12 * (1 - math.cos(a)), -10 * math.sin(a));
    case PictureMotion.pulse:
      return Matrix4.identity();
  }
}

/// How big a pulsing piece is [t] (0…1) of the way through: three swells.
double pulseScale(double t) => 1 + .12 * math.sin(math.pi * _frac(t * 3)).abs();
