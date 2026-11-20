import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/presentation/shapes/shape_motion.dart';

void main() {
  const pivot = (x: 150.0, y: 280.0);
  Offset at(PictureMotion motion, double t, Offset point) =>
      MatrixUtils.transformPoint(pictureMotion(motion, t, pivot), point);

  test('every motion starts and ends where the picture stands', () {
    for (final motion in PictureMotion.values) {
      for (final t in [0.0, 1.0]) {
        final p = at(motion, t, const Offset(100, 100));
        expect(p.dx, closeTo(100, .01), reason: '$motion at $t');
        expect(p.dy, closeTo(100, .01), reason: '$motion at $t');
      }
      expect(motionDuration(motion), greaterThan(Duration.zero));
    }
  });

  test('a car drives off to the right before it comes back', () {
    expect(at(PictureMotion.drive, .4, const Offset(100, 100)).dx, greaterThan(300));
  });

  test('a rocket flies up', () {
    expect(at(PictureMotion.launch, .45, const Offset(100, 100)).dy, lessThan(-100));
  });

  test('turning motions keep the pivot still', () {
    for (final motion in [PictureMotion.wiggle, PictureMotion.rock, PictureMotion.sway]) {
      final p = at(motion, .1, Offset(pivot.x, pivot.y));
      expect(p.dx, closeTo(pivot.x, .01));
      expect(p.dy, closeTo(pivot.y, .01));
    }
  });

  test('pulsing stays between full size and a little bigger', () {
    for (var t = 0.0; t <= 1; t += .05) {
      expect(pulseScale(t), inInclusiveRange(1, 1.121));
    }
    expect(pulseScale(0), 1);
  });
}
