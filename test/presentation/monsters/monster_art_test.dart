import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/presentation/monsters/monster_art.dart';

List<String> get _everyPicture => [
      for (final color in MonsterColor.values)
        for (final picture in MonsterPicture.values) monsterPictureAsset(color, picture),
      for (final food in allFoods) foodAsset(food),
      monstersBackgroundAsset,
      monstersTrayAsset,
    ];

void main() {
  test('every monster has four faces and an arm', () {
    for (final color in MonsterColor.values) {
      for (final picture in MonsterPicture.values) {
        final path = monsterPictureAsset(color, picture);
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('every treat has a picture', () {
    for (final food in allFoods) {
      expect(File(foodAsset(food)).existsSync(), isTrue, reason: '$food');
    }
  });

  test('the kitchen and the tray are there', () {
    expect(File(monstersBackgroundAsset).existsSync(), isTrue);
    expect(File(monstersTrayAsset).existsSync(), isTrue);
  });

  test('the pictures are WebP files in a folder the app bundles', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('- $monstersArtFolder\n'));
    for (final path in _everyPicture) {
      expect(path, startsWith(monstersArtFolder));
      expect(path, endsWith('.webp'));
    }
  });

  test('the pictures stay small enough for the app', () {
    final bytes = _everyPicture.fold<int>(0, (sum, path) => sum + File(path).lengthSync());
    expect(bytes, lessThan(8 * 1024 * 1024));
  });

  test('every monster colour has its own paint', () {
    expect(MonsterColor.values.map(monsterPaint).toSet(), hasLength(MonsterColor.values.length));
  });
}
