import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_outline.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/presentation/widgets/flashlight_darkness.dart';

/// The darkness is drawn on a canvas, so these look at the drawing itself:
/// how dark it is at a given point.
void main() {
  // A tall triangle standing in the left half of its zone: the zone's
  // right half is empty, where an oval over the zone would be lit.
  const outlined = SceneObject(
    id: 'fox',
    label: 'Лиса',
    audio: 'fox.wav',
    rect: ObjectRect(x: 0.5, y: 0.5, width: 0.4, height: 0.4),
    outline: ObjectOutline([(x: 0.5, y: 0.5), (x: 0.7, y: 0.9), (x: 0.5, y: 0.9)]),
  );
  const plain = SceneObject(
    id: 'fox',
    label: 'Лиса',
    audio: 'fox.wav',
    rect: ObjectRect(x: 0.5, y: 0.5, width: 0.4, height: 0.4),
  );

  /// Alpha (0..255) of the darkness at [point] (in shares of its size),
  /// once [object]'s reveal animation has finished.
  Future<int> darknessAlphaAt(WidgetTester tester, SceneObject object, Offset point, {bool found = true}) async {
    const side = 200.0;
    final key = GlobalKey();
    Widget build(bool isFound) => Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: side,
                height: side,
                child: FlashlightDarkness(
                  // The light itself is parked in the far corner.
                  lightCenter: Offset.zero,
                  objects: [object],
                  isFound: (_) => isFound,
                  lightsOn: false,
                ),
              ),
            ),
          ),
        );
    await tester.pumpWidget(build(false));
    await tester.pumpWidget(build(found));
    // Past the 500 ms reveal animation; the stopwatch behind it runs on
    // real time, hence runAsync.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final x = (point.dx * side).round();
    final y = (point.dy * side).round();
    final alpha = bytes.getUint8((y * image.width + x) * 4 + 3);
    // Unmount, so the repeating animation doesn't outlive the test.
    await tester.pumpWidget(const SizedBox.shrink());
    return alpha;
  }

  const insideSilhouette = Offset(0.55, 0.8);
  // Inside the zone (and inside the oval a zone-shaped hole would be), but
  // to the right of the triangle.
  const besideSilhouette = Offset(0.8, 0.62);

  testWidgets('a found target shows through the dark in the shape of its outline', (tester) async {
    expect(await darknessAlphaAt(tester, outlined, insideSilhouette), lessThan(30));
    expect(await darknessAlphaAt(tester, outlined, besideSilhouette), greaterThan(200));
  });

  testWidgets('a target not found yet stays in the dark', (tester) async {
    expect(await darknessAlphaAt(tester, outlined, insideSilhouette, found: false), greaterThan(200));
  });

  testWidgets('a found target with no outline on this picture falls back to a soft oval', (tester) async {
    expect(await darknessAlphaAt(tester, plain, const Offset(0.7, 0.7)), lessThan(30));
    expect(await darknessAlphaAt(tester, plain, besideSilhouette), lessThan(120));
  });
}
