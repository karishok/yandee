import 'package:flutter/material.dart';

import '../../domain/monsters/monster_color.dart';
import '../../domain/monsters/monster_food.dart';
import 'monster_art.dart';

/// The "Монстрики" game in miniature — the picture on its card in the scene
/// list: four calm monsters in the kitchen, three treats on the tray.
class MonstersThumbnail extends StatelessWidget {
  const MonstersThumbnail({super.key});

  static const _monsters = [
    [MonsterColor.red, MonsterColor.blue],
    [MonsterColor.yellow, MonsterColor.green],
  ];

  static const _treats = [
    MonsterFood(FoodKind.strawberry, MonsterColor.red),
    MonsterFood(FoodKind.banana, MonsterColor.yellow),
    MonsterFood(FoodKind.pear, MonsterColor.green),
  ];

  static Widget _picture(String asset, {BoxFit fit = BoxFit.contain}) =>
      Image.asset(asset, fit: fit, filterQuality: FilterQuality.medium, excludeFromSemantics: true);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Image(
          image: AssetImage(monstersBackgroundAsset),
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          excludeFromSemantics: true,
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            children: [
              for (final row in _monsters)
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      for (final color in row)
                        Expanded(child: _picture(monsterPictureAsset(color, MonsterPicture.idle))),
                    ],
                  ),
                ),
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The tray on the lower 70% of its strip, as in the game.
                    FractionallySizedBox(
                      alignment: Alignment.bottomCenter,
                      heightFactor: .7,
                      child: _picture(monstersTrayAsset, fit: BoxFit.fill),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [for (final treat in _treats) Expanded(child: _picture(foodAsset(treat)))],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
