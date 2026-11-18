import 'dart:ui' show Color;

import '../../domain/monsters/monster_color.dart';
import '../../domain/monsters/monster_food.dart';

/// The drawings of the "Монстрики" game, carried over from the HTML
/// prototype (`docs/prototypes/monsters.html`) as SVG text.
///
/// A monster is not one picture but a stack of layers sharing one view box
/// — body, eyes, pupils, each mouth shape, each arm — so the screen can
/// move the pupils, swap the mouth and swing the arms on their own.

/// The three shades a colour is drawn with: the fill, a darker outline and
/// a lighter highlight.
class MonsterShades {
  const MonsterShades(this.fill, this.dark, this.light);
  final String fill;
  final String dark;
  final String light;
}

const Map<MonsterColor, MonsterShades> monsterShades = {
  MonsterColor.red: MonsterShades('#ec4a3a', '#b8301f', '#ff8a77'),
  MonsterColor.blue: MonsterShades('#2f7cf0', '#1b55b5', '#7db0ff'),
  MonsterColor.yellow: MonsterShades('#ffc929', '#d99a00', '#ffe27a'),
  MonsterColor.green: MonsterShades('#36b95a', '#1f8a3c', '#7fe09a'),
  MonsterColor.orange: MonsterShades('#ff8a1f', '#c95f00', '#ffb877'),
  MonsterColor.purple: MonsterShades('#9b5de5', '#6c35b0', '#c9a6f5'),
  MonsterColor.pink: MonsterShades('#ff7eb6', '#d14d8a', '#ffb8d6'),
  MonsterColor.brown: MonsterShades('#9a6337', '#6b3f1d', '#c99a6e'),
  MonsterColor.lightblue: MonsterShades('#6fd0f6', '#2c9cc8', '#b8ecff'),
  MonsterColor.white: MonsterShades('#fbfbf8', '#8e98a4', '#ffffff'),
  MonsterColor.black: MonsterShades('#34343f', '#121219', '#5c5c6c'),
};

/// The fill of [color] as a Flutter colour (for dots and confetti).
Color monsterFill(MonsterColor color) => _parseHex(monsterShades[color]!.fill);

/// The outline shade of [color] as a Flutter colour.
Color monsterDark(MonsterColor color) => _parseHex(monsterShades[color]!.dark);

Color _parseHex(String hex) => Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));

const _sky = '#d9efff';
const _leaf = '#3fae4f';
const _leafDark = '#23803a';
const _cone = '#e3b46a';
const _coneDark = '#b27f32';
const _stem = '#7a4a1e';
const _pupilInk = '#1c2335';

// ---------------------------------------------------------------- monsters

/// The view box every monster layer is drawn in: 212 × 212 units, with the
/// body between 0 and 200 and a margin for horns and feet.
const double monsterViewBoxSize = 212;
const double _viewBoxLeft = -6;
const double _viewBoxTop = -10;

/// Where a point of the monster drawing lies inside its square, as a
/// fraction (0…1) of the square's side.
({double x, double y}) _fraction(double x, double y) =>
    (x: (x - _viewBoxLeft) / monsterViewBoxSize, y: (y - _viewBoxTop) / monsterViewBoxSize);

/// The middle of the mouth — where food flies to.
final monsterMouthAt = _fraction(100, 132);

/// The shoulders the arms swing around.
final monsterLeftShoulderAt = _fraction(46, 132);
final monsterRightShoulderAt = _fraction(154, 132);

// Monsters come in four looks, so neighbours don't look like recolours of
// one another: horns with two eyes, a tuft with one big eye, antennae with
// two eyes, ears with three small eyes.
const Map<MonsterColor, int> _lookOf = {
  MonsterColor.red: 0,
  MonsterColor.blue: 2,
  MonsterColor.yellow: 1,
  MonsterColor.green: 3,
  MonsterColor.orange: 1,
  MonsterColor.purple: 0,
  MonsterColor.pink: 3,
  MonsterColor.brown: 2,
  MonsterColor.lightblue: 0,
  MonsterColor.white: 1,
  MonsterColor.black: 3,
};

const Map<int, List<(double, double)>> _eyesOfLook = {
  0: [(72, 88), (128, 88)],
  1: [(100, 84)],
  2: [(74, 86), (126, 86)],
  3: [(66, 92), (100, 76), (134, 92)],
};

double _eyeRadius(int look) => switch (look) { 1 => 26, 3 => 15, _ => 19 };

/// How far, in view-box units, the pupils of [color] slide towards what the
/// monster is looking at.
double monsterPupilReach(MonsterColor color) => _eyeRadius(_lookOf[color]!) * .35;

// Mouth lines and squinting eyes are dark, except on the black monster,
// where dark ink would vanish.
String _ink(MonsterColor color) => color == MonsterColor.black ? '#ffffff' : _pupilInk;

String _n(double value) {
  final text = value.toStringAsFixed(2);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

String _monsterSvg(String content) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${_n(_viewBoxLeft)} ${_n(_viewBoxTop)} '
    '${_n(monsterViewBoxSize)} ${_n(monsterViewBoxSize)}">$content</svg>';

String _extras(MonsterColor color) {
  final k = monsterShades[color]!;
  return switch (_lookOf[color]!) {
    0 => '<path d="M58 40 L48 6 L78 30 Z M142 40 L152 6 L122 30 Z" fill="#fff6e8" stroke="${k.dark}" stroke-width="4" stroke-linejoin="round"/>',
    1 => '<path d="M88 22 Q92 2 100 18 Q106 0 112 22" fill="${k.fill}" stroke="${k.dark}" stroke-width="4" stroke-linejoin="round"/>',
    2 => '<path d="M76 30 Q66 12 58 4 M124 30 Q134 12 142 4" stroke="${k.dark}" stroke-width="5" fill="none" stroke-linecap="round"/>'
        '<circle cx="58" cy="4" r="9" fill="${k.light}" stroke="${k.dark}" stroke-width="4"/>'
        '<circle cx="142" cy="4" r="9" fill="${k.light}" stroke="${k.dark}" stroke-width="4"/>',
    _ => '<circle cx="34" cy="62" r="16" fill="${k.fill}" stroke="${k.dark}" stroke-width="4"/>'
        '<circle cx="166" cy="62" r="16" fill="${k.fill}" stroke="${k.dark}" stroke-width="4"/>',
  };
}

String _bodyContent(MonsterColor color) {
  final k = monsterShades[color]!;
  return '${_extras(color)}'
      '<ellipse cx="66" cy="190" rx="24" ry="10" fill="${k.dark}"/><ellipse cx="134" cy="190" rx="24" ry="10" fill="${k.dark}"/>'
      '<path d="M100 26 C152 26 184 66 184 116 C184 164 148 190 100 190 C52 190 16 164 16 116 C16 66 48 26 100 26Z" fill="${k.fill}" stroke="${k.dark}" stroke-width="5"/>'
      '<ellipse cx="100" cy="152" rx="50" ry="32" fill="${k.light}" opacity=".55"/>'
      '<circle cx="54" cy="122" r="9" fill="#ff7aa8" opacity=".55"/><circle cx="146" cy="122" r="9" fill="#ff7aa8" opacity=".55"/>';
}

String _eyeWhitesContent(MonsterColor color) {
  final k = monsterShades[color]!;
  final look = _lookOf[color]!;
  final r = _eyeRadius(look);
  return [
    for (final (x, y) in _eyesOfLook[look]!)
      '<circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(r)}" fill="#fff" stroke="${k.dark}" stroke-width="4"/>',
  ].join();
}

String _pupilsContent(MonsterColor color) {
  final look = _lookOf[color]!;
  final r = _eyeRadius(look);
  return [
    for (final (x, y) in _eyesOfLook[look]!)
      '<circle cx="${_n(x)}" cy="${_n(y)}" r="${_n(r * .5)}" fill="$_pupilInk"/>'
          '<circle cx="${_n(x - r * .18)}" cy="${_n(y - r * .2)}" r="${_n(r * .17)}" fill="#fff"/>',
  ].join();
}

String _squintContent(MonsterColor color) {
  final look = _lookOf[color]!;
  final r = _eyeRadius(look);
  return [
    for (final (x, y) in _eyesOfLook[look]!)
      '<path d="M${_n(x - r * .7)} ${_n(y - r * .3)} L${_n(x + r * .4)} ${_n(y)} L${_n(x - r * .7)} ${_n(y + r * .35)}" '
          'stroke="${_ink(color)}" stroke-width="6" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
  ].join();
}

String _mouthIdleContent(MonsterColor color) =>
    '<path d="M76 124 Q100 146 124 124" stroke="${_ink(color)}" stroke-width="6" fill="none" stroke-linecap="round"/>';

const _mouthOpenContent = '<ellipse cx="100" cy="134" rx="28" ry="24" fill="#5b1730"/>'
    '<ellipse cx="100" cy="146" rx="16" ry="8" fill="#ff7a92"/>'
    '<path d="M84 114 l5 9 l5 -9 M106 114 l5 9 l5 -9" fill="#fff"/>';

String _mouthChompContent(MonsterColor color) =>
    '<path d="M68 120 Q100 158 132 120 Z" fill="#5b1730" stroke="${_ink(color)}" stroke-width="5" stroke-linejoin="round"/>';

String _mouthYuckContent(MonsterColor color) =>
    '<path d="M70 130 q8 -8 15 0 t15 0 t15 0 t15 0" stroke="${_ink(color)}" stroke-width="6" fill="none" stroke-linecap="round"/>'
    '<path d="M96 132 q6 22 16 4" fill="#ff7a92" stroke="#c84a64" stroke-width="3"/>';

// Arms hang down and outwards; clapping swings both hands to meet in front
// of the belly.
String _armContent(MonsterColor color, {required bool left}) {
  final k = monsterShades[color]!;
  final shoulderX = left ? 46 : 154;
  final handX = left ? 18 : 182;
  return '<path d="M$shoulderX 132 L$handX 180" stroke="${k.dark}" stroke-width="12" stroke-linecap="round"/>'
      '<path d="M$shoulderX 132 L$handX 180" stroke="${k.fill}" stroke-width="6" stroke-linecap="round"/>'
      '<circle cx="$handX" cy="180" r="13" fill="${k.light}" stroke="${k.dark}" stroke-width="4"/>';
}

/// The separate layers of one monster, bottom to top: [body], then
/// [eyeWhites] with [pupils] (or [squint] instead of both), one of the four
/// mouths, and the arms on top.
class MonsterLayers {
  MonsterLayers._(MonsterColor color)
      : body = _monsterSvg(_bodyContent(color)),
        eyeWhites = _monsterSvg(_eyeWhitesContent(color)),
        pupils = _monsterSvg(_pupilsContent(color)),
        squint = _monsterSvg(_squintContent(color)),
        mouthIdle = _monsterSvg(_mouthIdleContent(color)),
        mouthOpen = _monsterSvg(_mouthOpenContent),
        mouthChomp = _monsterSvg(_mouthChompContent(color)),
        mouthYuck = _monsterSvg(_mouthYuckContent(color)),
        leftArm = _monsterSvg(_armContent(color, left: true)),
        rightArm = _monsterSvg(_armContent(color, left: false)),
        whole = _monsterSvg(
          _bodyContent(color) +
              _eyeWhitesContent(color) +
              _pupilsContent(color) +
              _mouthIdleContent(color) +
              _armContent(color, left: true) +
              _armContent(color, left: false),
        );

  static final Map<MonsterColor, MonsterLayers> _cache = {};

  factory MonsterLayers.of(MonsterColor color) => _cache.putIfAbsent(color, () => MonsterLayers._(color));

  final String body;
  final String eyeWhites;
  final String pupils;
  final String squint;
  final String mouthIdle;
  final String mouthOpen;
  final String mouthChomp;
  final String mouthYuck;
  final String leftArm;
  final String rightArm;

  /// The whole monster standing still, as one picture.
  final String whole;
}

// -------------------------------------------------------------------- food

const _round = 'stroke-width="4" stroke-linejoin="round" stroke-linecap="round"';

String _circles(List<(int, int)> points, String Function(int x, int y) draw) =>
    [for (final (x, y) in points) draw(x, y)].join();

String _foodContent(FoodKind kind, MonsterShades k) {
  switch (kind) {
    case FoodKind.candy:
      return '<path d="M28 50 L6 34 L10 50 L6 66 Z M72 50 L94 34 L90 50 L94 66 Z" fill="${k.light}" stroke="${k.dark}" stroke-width="3" stroke-linejoin="round"/>'
          '<circle cx="50" cy="50" r="25" fill="${k.fill}" stroke="${k.dark}" stroke-width="4"/>'
          '<path d="M36 42 Q44 32 56 34" stroke="#fff" stroke-width="5" fill="none" stroke-linecap="round" opacity=".7"/>';
    case FoodKind.lollipop:
      return '<path d="M50 54 L50 96" stroke="#e9dcc4" stroke-width="7" stroke-linecap="round"/>'
          '<circle cx="50" cy="36" r="30" fill="${k.fill}" stroke="${k.dark}" stroke-width="4"/>'
          '<path d="M50 36 m-4 0 a4 4 0 1 1 8 0 a9 9 0 1 1 -17 0 a14 14 0 1 1 27 0 a19 19 0 1 1 -37 0" stroke="${k.light}" stroke-width="4" fill="none" stroke-linecap="round"/>';
    case FoodKind.iceCream:
      return '<path d="M30 50 L50 94 L70 50Z" fill="$_cone" stroke="$_coneDark" $_round/>'
          '<path d="M38 58 L60 74 M44 52 L64 66 M56 52 L40 68" stroke="$_coneDark" stroke-width="2.5"/>'
          '<circle cx="50" cy="38" r="24" fill="${k.fill}" stroke="${k.dark}" stroke-width="4"/>'
          '<path d="M28 48 q6 8 12 0 q6 8 12 0 q6 8 12 0 q6 8 10 0" fill="${k.fill}" stroke="${k.dark}" stroke-width="4" stroke-linejoin="round"/>'
          '<circle cx="42" cy="30" r="5" fill="#fff" opacity=".5"/>';
    case FoodKind.donut:
      const sprinkles = [(30, 34, '#fff'), (62, 30, '#ffe27a'), (70, 44, '#7db0ff'), (36, 48, '#7fe09a'), (52, 30, '#fff')];
      return '<circle cx="50" cy="52" r="38" fill="#e3b46a" stroke="#b27f32" stroke-width="4"/>'
          '<path d="M50 18 C72 18 86 32 86 48 C80 56 76 50 70 58 C64 66 58 58 50 62 C42 58 36 66 30 58 C24 50 20 56 14 48 C14 32 28 18 50 18Z" fill="${k.fill}" stroke="${k.dark}" stroke-width="4" stroke-linejoin="round"/>'
          '<circle cx="50" cy="50" r="11" fill="$_sky" stroke="#b27f32" stroke-width="4"/>'
          '${[
        for (final (x, y, c) in sprinkles)
          '<rect x="$x" y="$y" width="8" height="3" rx="1.5" fill="$c" transform="rotate(${x * 7} ${x + 4} ${y + 1})"/>',
      ].join()}';
    case FoodKind.chocolate:
      return '<rect x="18" y="14" width="64" height="76" rx="6" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '${[
        for (final c in [0, 1])
          for (final r in [0, 1, 2])
            '<rect x="${26 + c * 26}" y="${22 + r * 22}" width="20" height="16" rx="3" fill="${k.light}" opacity=".55"/>',
      ].join()}'
          '<path d="M18 62 L82 50 L82 90 L18 90Z" fill="#e9e2d6" stroke="#b9ad99" stroke-width="3" stroke-linejoin="round"/>';
    case FoodKind.cookie:
      return '<circle cx="50" cy="50" r="38" fill="${k.light}" stroke="${k.dark}" $_round/>'
          '${_circles(const [(36, 36), (60, 32), (66, 56), (42, 62), (54, 48), (30, 54), (56, 72)], (x, y) => '<circle cx="$x" cy="$y" r="5" fill="${k.dark}"/>')}';
    case FoodKind.egg:
      return '<path d="M50 10 C72 10 86 46 86 62 C86 82 70 94 50 94 C30 94 14 82 14 62 C14 46 28 10 50 10Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<ellipse cx="36" cy="44" rx="6" ry="12" fill="#e8ecef" transform="rotate(20 36 44)"/>';
    case FoodKind.milk:
      return '<path d="M26 12 H74 L68 92 H32Z" fill="#eef6fb" stroke="${k.dark}" $_round/>'
          '<path d="M29 34 H71 L67 88 H33Z" fill="${k.fill}"/>'
          '<path d="M29 34 q10 -6 21 0 t21 0" stroke="#dfe5ea" stroke-width="3" fill="none"/>';
    case FoodKind.blackberry:
      return '${_circles(const [(38, 40), (52, 36), (66, 42), (34, 56), (48, 52), (62, 56), (42, 70), (56, 70), (50, 84)], (x, y) => '<circle cx="$x" cy="$y" r="10" fill="${k.fill}" stroke="${k.dark}" stroke-width="3"/><circle cx="${x - 3}" cy="${y - 3}" r="2.5" fill="#fff" opacity=".45"/>')}'
          '<path d="M40 26 L52 14 L64 26 L52 30Z" fill="$_leaf" stroke="$_leafDark" stroke-width="3" stroke-linejoin="round"/>';
    case FoodKind.strawberry:
      return '<path d="M50 92 C22 72 12 48 22 34 C32 22 44 28 50 32 C56 28 68 22 78 34 C88 48 78 72 50 92Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '${_circles(const [(38, 46), (56, 44), (46, 60), (64, 60), (36, 64), (54, 76)], (x, y) => '<ellipse cx="$x" cy="$y" rx="2.5" ry="4" fill="#ffe27a"/>')}'
          '<path d="M32 30 L44 24 L50 14 L56 24 L68 30 L56 34 L50 30 L44 34Z" fill="$_leaf" stroke="$_leafDark" stroke-width="3" stroke-linejoin="round"/>';
    case FoodKind.tomato:
      return '<circle cx="50" cy="56" r="34" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<ellipse cx="36" cy="46" rx="6" ry="10" fill="#fff" opacity=".4" transform="rotate(25 36 46)"/>'
          '<path d="M50 26 L40 18 L46 28 L32 28 L46 32 L42 40 L50 33 L58 40 L54 32 L68 28 L54 28 L60 18Z" fill="$_leaf" stroke="$_leafDark" stroke-width="3" stroke-linejoin="round"/>';
    case FoodKind.blueberry:
      return _circles(
        const [(36, 60), (64, 60), (50, 38)],
        (x, y) => '<circle cx="$x" cy="$y" r="20" fill="${k.fill}" stroke="${k.dark}" stroke-width="4"/>'
            '<path d="M${x - 5} ${y - 12} l5 4 l5 -4" stroke="${k.dark}" stroke-width="3" fill="none" stroke-linecap="round"/>'
            '<circle cx="${x - 8}" cy="${y + 2}" r="4" fill="#fff" opacity=".45"/>',
      );
    case FoodKind.banana:
      return '<path d="M14 26 C20 70 58 90 90 70 C93 64 89 61 84 63 C58 74 34 58 28 26 C26 20 16 20 14 26Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<path d="M14 26 L12 18" stroke="$_stem" stroke-width="6" stroke-linecap="round"/>'
          '<path d="M30 40 C36 58 52 68 72 70" stroke="${k.dark}" stroke-width="3" fill="none" opacity=".6"/>';
    case FoodKind.cheese:
      return '<path d="M10 66 L84 30 L92 40 L92 80 L10 80Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<path d="M10 66 L92 40" stroke="${k.dark}" stroke-width="3"/>'
          '<circle cx="40" cy="70" r="6" fill="${k.dark}" opacity=".55"/><circle cx="70" cy="62" r="8" fill="${k.dark}" opacity=".55"/>'
          '<circle cx="82" cy="74" r="4" fill="${k.dark}" opacity=".55"/><circle cx="58" cy="44" r="4" fill="${k.dark}" opacity=".55"/>';
    case FoodKind.cucumber:
      return '<rect x="10" y="36" width="80" height="30" rx="15" fill="${k.fill}" stroke="${k.dark}" $_round transform="rotate(-20 50 51)"/>'
          '${_circles(const [(30, 58), (46, 50), (62, 44), (74, 38), (38, 64), (56, 56)], (x, y) => '<circle cx="$x" cy="$y" r="2.5" fill="${k.light}"/>')}';
    case FoodKind.pear:
      return '<path d="M50 18 C60 18 62 32 63 40 C82 52 84 90 50 92 C16 90 18 52 37 40 C38 32 40 18 50 18Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<path d="M50 18 Q50 10 56 6" stroke="$_stem" stroke-width="5" fill="none" stroke-linecap="round"/>'
          '<ellipse cx="38" cy="62" rx="6" ry="11" fill="#fff" opacity=".35"/>';
    case FoodKind.orangeFruit:
      return '<circle cx="50" cy="54" r="36" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '${_circles(const [(38, 44), (58, 40), (48, 60), (66, 62), (34, 66), (60, 78)], (x, y) => '<circle cx="$x" cy="$y" r="2" fill="${k.dark}" opacity=".6"/>')}'
          '<path d="M50 18 Q64 6 74 16 Q62 26 50 18Z" fill="$_leaf" stroke="$_leafDark" stroke-width="3"/>';
    case FoodKind.carrot:
      return '<path d="M50 94 L30 34 C36 26 64 26 70 34Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<path d="M38 46 h10 M44 60 h10 M46 74 h7" stroke="${k.dark}" stroke-width="3" stroke-linecap="round"/>'
          '<path d="M50 30 L38 8 M50 30 L50 4 M50 30 L62 8" stroke="$_leaf" stroke-width="7" stroke-linecap="round"/>';
    case FoodKind.grapes:
      return '${_circles(const [(36, 36), (54, 36), (72, 36), (44, 52), (62, 52), (52, 68), (40, 68), (64, 68), (52, 84)], (x, y) => '<circle cx="$x" cy="$y" r="11" fill="${k.fill}" stroke="${k.dark}" stroke-width="3"/><circle cx="${x - 3}" cy="${y - 3}" r="3" fill="#fff" opacity=".4"/>')}'
          '<path d="M54 25 Q56 12 66 8" stroke="$_stem" stroke-width="5" fill="none" stroke-linecap="round"/>';
    case FoodKind.eggplant:
      return '<path d="M66 26 C88 40 92 76 70 88 C48 98 18 84 14 66 C10 50 30 46 44 40 C54 36 58 22 66 26Z" fill="${k.fill}" stroke="${k.dark}" $_round/>'
          '<path d="M56 30 L66 16 L76 30 L70 38 L62 36Z" fill="$_leaf" stroke="$_leafDark" stroke-width="3" stroke-linejoin="round"/>'
          '<ellipse cx="36" cy="64" rx="5" ry="12" fill="#fff" opacity=".3" transform="rotate(60 36 64)"/>';
  }
}

final Map<MonsterFood, String> _foodSvgCache = {};

/// The picture of a treat, in a 100 × 100 view box.
String foodSvg(MonsterFood food) => _foodSvgCache.putIfAbsent(
      food,
      () => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
          '${_foodContent(food.kind, monsterShades[food.color]!)}</svg>',
    );
