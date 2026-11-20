import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/presentation/monsters/monster_art.dart';
import 'package:yandee/presentation/monsters/monsters_thumbnail.dart';

import '../../support/asset_image_finder.dart';

void main() {
  testWidgets('shows four calm monsters in the kitchen and three treats on the tray', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: SizedBox(width: 160, height: 240, child: MonstersThumbnail())),
    ));

    expect(findAssetImage(monstersBackgroundAsset), findsOneWidget);
    expect(findAssetImage(monstersTrayAsset), findsOneWidget);
    for (final color in [MonsterColor.red, MonsterColor.blue, MonsterColor.yellow, MonsterColor.green]) {
      expect(findAssetImage(monsterPictureAsset(color, MonsterPicture.idle)), findsOneWidget, reason: color.name);
    }
    for (final treat in const [
      MonsterFood(FoodKind.strawberry, MonsterColor.red),
      MonsterFood(FoodKind.banana, MonsterColor.yellow),
      MonsterFood(FoodKind.pear, MonsterColor.green),
    ]) {
      expect(findAssetImage(foodAsset(treat)), findsOneWidget, reason: '$treat');
    }
  });
}
