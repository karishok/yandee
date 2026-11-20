import 'dart:ui' show Color;

import '../../domain/monsters/monster_color.dart';
import '../../domain/monsters/monster_food.dart';

// The painted pictures of the "Монстрики" game: where each one lives, and
// the few things the code needs to know about them.
//
// The pictures were made in ChatGPT (`docs/prototypes/monsters_one_prompt.md`)
// and are turned into the bundled WebP files by `tool/prepare_monster_art.py`.

/// The pictures of one monster: four faces and one arm. The faces are the
/// same monster in the same place, only the face differs; the arm is the
/// left one, mirrored for the right.
enum MonsterPicture { idle, open, chomp, yuck, arm }

/// Where the painted pictures of the game live.
const String monstersArtFolder = 'assets/monsters/';

String monsterPictureAsset(MonsterColor color, MonsterPicture picture) =>
    '$monstersArtFolder${color.name}_${picture.name}.webp';

/// The picture of a treat: `red_strawberry.webp`, `orange_orange_fruit.webp`.
String foodAsset(MonsterFood food) => '$monstersArtFolder${food.color.name}_${food.kind.fileId}.webp';

/// The kitchen wall with the edge of a wooden table at the bottom.
const String monstersBackgroundAsset = '${monstersArtFolder}background.webp';

/// The empty wooden tray the treats lie on.
const String monstersTrayAsset = '${monstersArtFolder}tray.webp';

/// The middle of the mouth in the monster pictures, as a share of the
/// picture's side — where food flies to.
const ({double x, double y}) monsterMouthAt = (x: .5, y: .46);

/// The fur colour of each monster, taken from the side of its body in the
/// «спокойный» picture — for the met-colour dots and the confetti.
const Map<MonsterColor, Color> _paint = {
  MonsterColor.red: Color(0xFFDE1926),
  MonsterColor.blue: Color(0xFF0234D6),
  MonsterColor.yellow: Color(0xFFFBBC04),
  MonsterColor.green: Color(0xFF649221),
  MonsterColor.orange: Color(0xFFF65D0A),
  MonsterColor.purple: Color(0xFF9D3BA9),
  MonsterColor.pink: Color(0xFFF880A1),
  MonsterColor.brown: Color(0xFF7D3F23),
  MonsterColor.lightblue: Color(0xFF6EC4F5),
  MonsterColor.white: Color(0xFFF6ECE2),
  MonsterColor.black: Color(0xFF2E2825),
};

Color monsterPaint(MonsterColor color) => _paint[color]!;
