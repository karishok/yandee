import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/presentation/monsters/monster_art.dart';
import 'package:yandee/presentation/monsters/monster_figure.dart';

import '../../support/asset_image_finder.dart';

Future<GlobalKey<MonsterFigureState>> _pump(
  WidgetTester tester, {
  MonsterColor color = MonsterColor.red,
  MonsterMouth mouth = MonsterMouth.idle,
  Offset? look,
}) async {
  final key = GlobalKey<MonsterFigureState>();
  await tester.pumpWidget(MaterialApp(
    home: Center(
      child: SizedBox.square(
        dimension: 200,
        child: MonsterFigure(key: key, color: color, mouth: mouth, lookDirection: look),
      ),
    ),
  ));
  return key;
}

/// The turn, in degrees, of the `Transform` keyed [key].
double _degrees(WidgetTester tester, String key) {
  final m = tester.widget<Transform>(find.byKey(ValueKey(key))).transform;
  return math.atan2(m.entry(1, 0), m.entry(0, 0)) * 180 / math.pi;
}

const _faces = {
  MonsterMouth.idle: 'idle',
  MonsterMouth.open: 'open',
  MonsterMouth.chomp: 'chomp',
  MonsterMouth.yuck: 'yuck',
};

void main() {
  testWidgets('shows exactly the face that matches the mouth', (tester) async {
    for (final mouth in MonsterMouth.values) {
      await _pump(tester, mouth: mouth);
      for (final face in _faces.values) {
        final offstage = tester.widget<Offstage>(find.byKey(ValueKey('monster_face_$face'))).offstage;
        expect(offstage, face != _faces[mouth], reason: '$mouth: $face');
      }
    }
  });

  testWidgets('is drawn from the pictures of its own colour', (tester) async {
    await _pump(tester, color: MonsterColor.purple);
    for (final picture in [MonsterPicture.idle, MonsterPicture.open, MonsterPicture.chomp, MonsterPicture.yuck]) {
      expect(findAssetImage(monsterPictureAsset(MonsterColor.purple, picture), skipOffstage: false), findsOneWidget);
    }
    expect(findAssetImage(monsterPictureAsset(MonsterColor.purple, MonsterPicture.arm)), findsNWidgets(2));
  });

  testWidgets('at rest the arms hang a little apart', (tester) async {
    await _pump(tester);
    expect(_degrees(tester, 'monster_arm_left'), closeTo(10, .5));
    expect(_degrees(tester, 'monster_arm_right'), closeTo(-10, .5));
  });

  testWidgets('a clap swings both hands in front of the belly and back', (tester) async {
    final key = await _pump(tester);
    key.currentState!.clap();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 198)); // 22% of 900 ms: the first clap
    expect(_degrees(tester, 'monster_arm_left'), closeTo(-62, 1.5));
    expect(_degrees(tester, 'monster_arm_right'), closeTo(62, 1.5));
    await tester.pump(const Duration(milliseconds: 800));
    expect(_degrees(tester, 'monster_arm_left'), closeTo(10, .5));
    expect(_degrees(tester, 'monster_arm_right'), closeTo(-10, .5));
  });

  testWidgets('a wave lifts the right hand up and leaves the left one be', (tester) async {
    final key = await _pump(tester);
    key.currentState!.wave();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // 20% of 1000 ms: hand up
    expect(_degrees(tester, 'monster_arm_right'), closeTo(-160, 1.5));
    expect(_degrees(tester, 'monster_arm_left'), closeTo(10, .5));
  });

  testWidgets('leans a little toward where it looks', (tester) async {
    await _pump(tester, look: const Offset(1, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_degrees(tester, 'monster_lean'), closeTo(4, .1));

    await _pump(tester, look: const Offset(-.6, .8));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_degrees(tester, 'monster_lean'), closeTo(-2.4, .1));

    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_degrees(tester, 'monster_lean'), closeTo(0, .1));
  });
}
