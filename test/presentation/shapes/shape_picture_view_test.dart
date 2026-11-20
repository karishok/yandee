import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/presentation/shapes/shape_picture_view.dart';

Widget _host(Widget child) => MaterialApp(home: Center(child: SizedBox(width: 300, height: 300, child: child)));

void main() {
  final house = shapePictures[1];

  testWidgets('draws a layer for every slot, square in its box', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {0})));
    for (var i = 0; i < house.slots.length; i++) {
      expect(find.byKey(ValueKey('shapes_slot_$i')), findsOneWidget);
    }
    expect(tester.getSize(find.byType(ShapePictureView)), const Size(300, 300));
  });

  testWidgets('without a painted background it draws the stand-in one', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {})));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(SvgPicture), findsWidgets);
  });

  testWidgets('comes alive and settles back when the motion ends', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: shapePictures[2], filled: const {0, 1, 2})));
    await tester.pumpWidget(_host(ShapePictureView(picture: shapePictures[2], filled: const {0, 1, 2}, alive: true)));
    await tester.pump(const Duration(milliseconds: 1000));
    final moving = tester.getTopLeft(find.byKey(const ValueKey('shapes_slot_0')));
    expect(moving.dx, isNot(closeTo(tester.getTopLeft(find.byType(ShapePictureView)).dx, .5)));
    await tester.pump(const Duration(seconds: 3));
    expect(tester.getTopLeft(find.byKey(const ValueKey('shapes_slot_0'))),
        tester.getTopLeft(find.byType(ShapePictureView)));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a hint pulses its slots and stops', (tester) async {
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {})));
    await tester.pumpWidget(_host(ShapePictureView(picture: house, filled: const {}, hinting: const {2}, hintRun: 1)));
    await tester.pump(const Duration(milliseconds: 200));
    final size = tester.getSize(find.byKey(const ValueKey('shapes_slot_2')));
    expect(size.width, 300);
    await tester.pumpAndSettle();
  });
}
