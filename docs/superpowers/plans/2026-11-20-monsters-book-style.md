# «Монстрики» в книжном стиле — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Монстрики, еда, фон и поднос в игре «Монстрики» — готовые картинки в стиле сцен вместо SVG, нарисованного кодом; тёплые кнопки, точки и конфетти; миниатюра и экран отдыха на тех же картинках.

**Architecture:** Скрипт `tool/prepare_monster_art.py` делает из PNG-оригиналов (вне git) WebP в `assets/monsters/`. `monster_art.dart` знает только пути к картинкам и цвет шерсти. `MonsterFigure` складывает 4 лица стопкой `Offstage` и вращает руку-картинку вокруг плеча; поля и методы виджета не меняются. Экран игры, миниатюра и экран отдыха показывают `Image.asset`.

**Tech Stack:** Flutter 3.47.5, Python 3 + Pillow (как `tool/compose_store_screenshots.py`).

Спек: `docs/superpowers/specs/2026-11-20-monsters-book-style-design.md`. Прототип: `docs/prototypes/monsters.html`.

## Global Constraints

- Не трогать правила, фразы, голос и тайминги: `lib/domain/monsters/`, `lib/audio/`, длительности в `MonsterFigure` (`_moveDurations`, хлопок 900 мс, взмах 1000 мс, танец 500 мс) и все `Duration` в `monsters_screen.dart`, кроме тех, что прямо названы в задачах.
- Существующие тесты не правятся: `test/presentation/screens/monsters_screen_test.dart` (только дописываются новые `testWidgets`), `scene_list_screen_test.dart`, `play_timer_scope_test.dart`, `test/domain/monsters/*`.
- PNG-оригиналы — в `tool/monsters_art/`, папка в `.gitignore`. В `assets/monsters/` только `*.webp`.
- Имена: `<MonsterColor.name>_<idle|open|chomp|yuck|arm>.webp`, `<MonsterColor.name>_<FoodKind.fileId>.webp`, `background.webp`, `tray.webp`.
- Цвета экрана: бумага `#fff8f0`, кнопка `#fff0e1`, иконка `#2b211a`, тень `rgba(84,52,16,.14)` размытие 16 сдвиг (0,6), кольцо незнакомого цвета `#dcc2a2`.
- `flutter_svg` остаётся в `pubspec.yaml`.
- Ветка `claude/monsters-book-style`. Мерж в main и пуш — только с согласия пользователя. Коммиты заканчиваются строкой `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Python с numpy/Pillow из user site-packages запускать без `-I`, из папки, где нет чужих `.py`.

## Файлы

| Файл | Что |
|---|---|
| `.gitignore` | `/tool/monsters_art/` |
| `tool/prepare_monster_art.py` | новый: PNG → WebP |
| `assets/monsters/*.webp` | новые: 99 картинок |
| `pubspec.yaml` | `- assets/monsters/` |
| `lib/presentation/monsters/monster_art.dart` | пути, `monsterPaint`, `monsterMouthAt`; SVG удаляется в задаче 5 |
| `lib/presentation/monsters/monster_figure.dart` | лица, руки, наклон |
| `lib/presentation/screens/monsters_screen.dart` | фон, поднос, кнопки, точки, конфетти, еда |
| `lib/presentation/monsters/monsters_thumbnail.dart` | новый: миниатюра (была `_MonstersThumbnail`) |
| `lib/presentation/screens/scene_list_screen.dart` | использует `MonstersThumbnail` |
| `lib/presentation/screens/rest_screen.dart` | `blue_chomp` |
| `test/support/asset_image_finder.dart` | новый: `findAssetImage` |
| `test/presentation/monsters/monster_art_test.dart` | новый |
| `test/presentation/monsters/monster_figure_test.dart` | новый |
| `test/presentation/monsters/monsters_thumbnail_test.dart` | новый |
| `test/presentation/screens/rest_screen_test.dart` | новый |
| `test/presentation/screens/monsters_screen_test.dart` | дописываются 3 теста |

---

### Task 1: Картинки в приложении и пути к ним

**Files:**
- Modify: `.gitignore`, `pubspec.yaml:31-48`, `lib/presentation/monsters/monster_art.dart` (дописать в конец)
- Create: `tool/prepare_monster_art.py`, `assets/monsters/*.webp`, `test/support/asset_image_finder.dart`
- Test: `test/presentation/monsters/monster_art_test.dart`

**Interfaces:**
- Produces (в `monster_art.dart`):
  - `enum MonsterPicture { idle, open, chomp, yuck, arm }`
  - `const String monstersArtFolder = 'assets/monsters/'`
  - `String monsterPictureAsset(MonsterColor color, MonsterPicture picture)`
  - `String foodAsset(MonsterFood food)`
  - `const String monstersBackgroundAsset`, `const String monstersTrayAsset`
  - `Color monsterPaint(MonsterColor color)`
- Produces (в `test/support/asset_image_finder.dart`): `Finder findAssetImage(String path)`

- [ ] **Step 1: Перенести оригиналы из ассетов**

```bash
mkdir -p tool/monsters_art && mv assets/monsters/*.png tool/monsters_art/ && ls tool/monsters_art | wc -l
```
Expected: `99`.

В `.gitignore` после блока `/tool/*.mp3` дописать:

```
# PNG originals of the "Монстрики" pictures (made in ChatGPT, 38 MB);
# tool/prepare_monster_art.py turns them into the WebP files in assets/.
/tool/monsters_art/
```

- [ ] **Step 2: Написать падающий тест**

`test/support/asset_image_finder.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds every [Image] showing the bundled picture at [path].
Finder findAssetImage(String path) => find.byWidgetPredicate(
      (widget) => widget is Image && widget.image is AssetImage && (widget.image as AssetImage).assetName == path,
      description: 'image $path',
    );
```

`test/presentation/monsters/monster_art_test.dart`:

```dart
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
```

- [ ] **Step 3: Запустить — падает**

Run: `flutter test test/presentation/monsters/monster_art_test.dart`
Expected: FAIL на компиляции: `MonsterPicture`, `monsterPictureAsset` не определены.

- [ ] **Step 4: Пути и цвет шерсти в `monster_art.dart`**

Дописать в конец `lib/presentation/monsters/monster_art.dart` (старый SVG-код пока остаётся — его ещё используют экраны; удаляется в задаче 5):

```dart
// ---------------------------------------------------------------- pictures

/// The pictures of one monster: four faces and one arm. The faces are the
/// same monster in the same place, only the face differs; the arm is the
/// left one, mirrored for the right.
enum MonsterPicture { idle, open, chomp, yuck, arm }

/// Where the painted pictures of the game live (made by
/// `tool/prepare_monster_art.py`).
const String monstersArtFolder = 'assets/monsters/';

String monsterPictureAsset(MonsterColor color, MonsterPicture picture) =>
    '$monstersArtFolder${color.name}_${picture.name}.webp';

/// The picture of a treat: `red_strawberry.webp`, `orange_orange_fruit.webp`.
String foodAsset(MonsterFood food) => '$monstersArtFolder${food.color.name}_${food.kind.fileId}.webp';

/// The kitchen wall with the edge of a wooden table at the bottom.
const String monstersBackgroundAsset = '${monstersArtFolder}background.webp';

/// The empty wooden tray the treats lie on.
const String monstersTrayAsset = '${monstersArtFolder}tray.webp';

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
```

- [ ] **Step 5: Скрипт подготовки картинок**

`tool/prepare_monster_art.py`:

```python
#!/usr/bin/env python3
"""Turns the PNG originals of the "Монстрики" pictures into the WebP files
the app bundles.

    python3 tool/prepare_monster_art.py [originals] [out]

Defaults: tool/monsters_art/ (kept out of git) → assets/monsters/.

- faces and arms (<color>_idle/open/chomp/yuck/arm): 627×627 — the red
  ones were drawn at 1254 and are scaled down, so all faces line up;
- treats: fitted into 400×400;
- background.png: as is, without transparency;
- tray.png: cropped to the wood.
"""
import sys
from pathlib import Path

from PIL import Image

MONSTER_SIDE = 627
FOOD_SIDE = 400
QUALITY = 85
MONSTER_PICTURES = ("idle", "open", "chomp", "yuck", "arm")


def save(image, path):
    image.save(path, "WEBP", quality=QUALITY, method=4)


def prepare(src, out):
    name = src.stem
    image = Image.open(src)
    if name == "background":
        save(image.convert("RGB"), out / "background.webp")
        return
    image = image.convert("RGBA")
    if name == "tray":
        box = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
        save(image.crop(box), out / "tray.webp")
        return
    if name.rsplit("_", 1)[-1] in MONSTER_PICTURES:
        if image.width != image.height:
            sys.exit(f"{src.name}: a monster picture must be square, got {image.size}")
        if image.width != MONSTER_SIDE:
            image = image.resize((MONSTER_SIDE, MONSTER_SIDE), Image.LANCZOS)
    else:
        image.thumbnail((FOOD_SIDE, FOOD_SIDE), Image.LANCZOS)
    save(image, out / f"{name}.webp")


def main():
    root = Path(__file__).resolve().parent.parent
    originals = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "tool" / "monsters_art"
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else root / "assets" / "monsters"
    out.mkdir(parents=True, exist_ok=True)
    sources = sorted(originals.glob("*.png"))
    if not sources:
        sys.exit(f"no PNG files in {originals}")
    for src in sources:
        prepare(src, out)
    total = sum(p.stat().st_size for p in out.glob("*.webp"))
    print(f"{len(sources)} pictures → {out} ({total / 1024 / 1024:.1f} MB)")


if __name__ == "__main__":
    main()
```

Run (в фоне, у WebP-кодировщика это займёт ~1–2 минуты):

```bash
python3 tool/prepare_monster_art.py
```
Expected: `99 pictures → …/assets/monsters (4.x MB)`; в `assets/monsters/` только `.webp`.

- [ ] **Step 6: Объявить папку в `pubspec.yaml`**

После строки `- assets/audio/monsters_tts/` добавить:

```yaml
    # "Монстрики" pictures, made by tool/prepare_monster_art.py.
    - assets/monsters/
```

- [ ] **Step 7: Запустить — проходит**

Run: `flutter test test/presentation/monsters/monster_art_test.dart`
Expected: PASS, 6 тестов.

- [ ] **Step 8: Commit**

```bash
git add .gitignore pubspec.yaml tool/prepare_monster_art.py assets/monsters/*.webp lib/presentation/monsters/monster_art.dart test/support/asset_image_finder.dart test/presentation/monsters/monster_art_test.dart
git commit -m "feat(monsters): painted pictures of the monsters, treats, kitchen and tray as assets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `MonsterFigure` на картинках

**Files:**
- Modify: `lib/presentation/monsters/monster_figure.dart`, `lib/presentation/monsters/monster_art.dart:60-66` (`monsterMouthAt`)
- Test: `test/presentation/monsters/monster_figure_test.dart`

**Interfaces:**
- Consumes: `MonsterPicture`, `monsterPictureAsset` (задача 1); `findAssetImage` (задача 1).
- Produces: те же `MonsterFigure`/`MonsterFigureState`, что сейчас. Ключи для тестов: `ValueKey('monster_face_<idle|open|chomp|yuck>')` на `Offstage` лица; `ValueKey('monster_arm_left')`, `ValueKey('monster_arm_right')` на `Transform` поворота руки; `ValueKey('monster_lean')` на `Transform` наклона. `monsterMouthAt` — `({double x, double y})`, `(x: .5, y: .46)`.

Геометрия руки (из прототипа, в долях стороны квадрата фигуры) — приватные константы в `monster_figure.dart`: квадрат руки 42%, верх 42%, левая `left: -4%`, правая `left: 62%`, плечо `FractionalOffset(.5, .1)`, в покое левая +10°, правая −10°. Повороты хлопка и взмаха прибавляются к покою, как CSS-свойство `rotate` складывается с анимацией `transform` в прототипе: хлопок — левая `10 + [0, −72, −54, −72, −54, 0]` по точкам `[0, .22, .42, .62, .82, 1]`, правая зеркально; взмах — правая `−10 + [0, −150, −118, −150, −118, 0]` по `[0, .2, .4, .6, .8, 1]`, кривая `easeInOut` в каждом отрезке.

- [ ] **Step 1: Написать падающий тест**

`test/presentation/monsters/monster_figure_test.dart`:

```dart
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
      expect(findAssetImage(monsterPictureAsset(MonsterColor.purple, picture)), findsOneWidget);
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
```

- [ ] **Step 2: Запустить — падает**

Run: `flutter test test/presentation/monsters/monster_figure_test.dart`
Expected: FAIL: не найдены ключи `monster_face_idle` и др.

- [ ] **Step 3: Переписать отрисовку `MonsterFigure`**

В `monster_figure.dart`:
- убрать `import 'package:flutter_svg/flutter_svg.dart';`;
- удалить класс `_HandPose` и метод `_handPoses()`;
- `lookDirection` в доке: «Which way the monster is looking, as a direction of length 1; it leans a little that way. Null looks straight ahead.»;
- добавить константы и `_armAngles()`, заменить `build`.

Константы (в `MonsterFigureState`, рядом с `_enterCurve`):

```dart
  // The arm, as a share of the figure's square (from the prototype): a
  // square 42% wide, its top at 42%; the left one starts at -4%, the right
  // one at 62%. It turns about the shoulder, near the top of its square.
  static const _armSide = .42;
  static const _armTop = .42;
  static const _leftArmLeft = -.04;
  static const _rightArmLeft = .62;
  static const _shoulder = FractionalOffset(.5, .1);

  /// At rest the hands hang a little away from the body.
  static const _armRestDegrees = 10.0;

  /// How far the monster leans toward the treat it is looking at.
  static const _maxLeanDegrees = 4.0;

  /// The feet: the point the monster leans about.
  static const _feet = Alignment(0, .82);
```

`_armAngles()` на месте `_handPoses()`:

```dart
  // The turn of each arm about its shoulder for this frame, in radians.
  // The swing adds to the resting turn, as in the prototype.
  ({double left, double right}) _armAngles() {
    final t = _arms.value;
    switch (_armMove) {
      case _ArmMove.clap:
        // Both hands come in front of the belly and meet twice.
        final swing =
            _track(t, const [0, .22, .42, .62, .82, 1], const [0, -72, -54, -72, -54, 0], Curves.easeInOut);
        return (left: _deg(_armRestDegrees + swing), right: _deg(-_armRestDegrees - swing));
      case _ArmMove.wave:
        // The right hand goes up beside the head and wags.
        final lift =
            _track(t, const [0, .2, .4, .6, .8, 1], const [0, -150, -118, -150, -118, 0], Curves.easeInOut);
        return (left: _deg(_armRestDegrees), right: _deg(-_armRestDegrees + lift));
    }
  }
```

Новый `build`:

```dart
  static const _faces = {
    MonsterMouth.idle: MonsterPicture.idle,
    MonsterMouth.open: MonsterPicture.open,
    MonsterMouth.chomp: MonsterPicture.chomp,
    MonsterMouth.yuck: MonsterPicture.yuck,
  };

  @override
  Widget build(BuildContext context) {
    final face = _faces[widget.mouth]!;
    final look = widget.lookDirection;
    final lean = look == null ? 0.0 : _deg(_maxLeanDegrees * look.dx);

    Widget picture(MonsterPicture picture) => Image.asset(
          monsterPictureAsset(widget.color, picture),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;

        Widget arm({required bool left, required double angle}) => Positioned(
              left: side * (left ? _leftArmLeft : _rightArmLeft),
              top: side * _armTop,
              width: side * _armSide,
              height: side * _armSide,
              child: Transform.rotate(
                key: ValueKey(left ? 'monster_arm_left' : 'monster_arm_right'),
                angle: angle,
                alignment: _shoulder,
                child: left ? picture(MonsterPicture.arm) : Transform.flip(flipX: true, child: picture(MonsterPicture.arm)),
              ),
            );

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: AnimatedScale(
              scale: widget.growth,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: lean),
                duration: const Duration(milliseconds: 150),
                builder: (context, angle, child) => Transform.rotate(
                  key: const ValueKey('monster_lean'),
                  angle: angle,
                  alignment: _feet,
                  child: child,
                ),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_move, _arms, _dance]),
                  builder: (context, _) {
                    final pose = _bodyPose(side / 180);
                    final arms = _armAngles();
                    return Opacity(
                      opacity: pose.opacity,
                      child: Transform(
                        transform: pose.transform,
                        alignment: Alignment.center,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // All four faces stay loaded, so a new face shows
                            // at once, without a blank frame.
                            for (final each in _faces.values)
                              Positioned.fill(
                                child: Offstage(
                                  key: ValueKey('monster_face_${each.name}'),
                                  offstage: each != face,
                                  child: picture(each),
                                ),
                              ),
                            arm(left: true, angle: arms.left),
                            arm(left: false, angle: arms.right),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
```

- [ ] **Step 4: Точка рта под картинки**

В `monster_art.dart` заменить объявление `final monsterMouthAt = _fraction(100, 132);` с его докой на:

```dart
/// The middle of the mouth in the monster pictures, as a share of the
/// picture's side — where food flies to.
const ({double x, double y}) monsterMouthAt = (x: .5, y: .46);
```

- [ ] **Step 5: Запустить — проходит**

Run: `flutter test test/presentation/monsters/ test/presentation/screens/monsters_screen_test.dart`
Expected: PASS — новые тесты фигуры и все старые тесты экрана (взгляд, рост, слоты).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/monsters/monster_figure.dart lib/presentation/monsters/monster_art.dart test/presentation/monsters/monster_figure_test.dart
git commit -m "feat(monsters): the monster is its painted faces, with a painted arm turning at the shoulder

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Экран игры — кухня, поднос, кнопки, точки, еда

**Files:**
- Modify: `lib/presentation/screens/monsters_screen.dart` (`:5`, `:16-19`, `_Layout`, `build`, `_RoundButton`, `_MetDot`, `_TrayFood`, `_ConfettiPiece`)
- Test: `test/presentation/screens/monsters_screen_test.dart` (дописать 3 теста в конец `main`)

**Interfaces:**
- Consumes: `monstersBackgroundAsset`, `monstersTrayAsset`, `foodAsset`, `monsterPaint` (задача 1); `findAssetImage`.
- Produces: ключи `ValueKey('monsters_background')`, `ValueKey('monsters_tray_picture')`. Остальные ключи экрана прежние.

- [ ] **Step 1: Написать падающие тесты**

В `monsters_screen_test.dart` добавить импорты:

```dart
import 'package:yandee/presentation/monsters/monster_art.dart';

import '../../support/asset_image_finder.dart';
```

и в конец `main()`:

```dart
  testWidgets('the game stands in a painted kitchen, with a wooden tray', (tester) async {
    await _startGame(tester);
    expect(findAssetImage(monstersBackgroundAsset), findsOneWidget);
    expect(findAssetImage(monstersTrayAsset), findsOneWidget);
  });

  testWidgets('each treat in the tray is the picture of that treat', (tester) async {
    final h = await _startGame(tester);
    for (var slot = 0; slot < MonstersGame.traySize; slot++) {
      final picture = find.descendant(
        of: find.byKey(ValueKey('monster_tray_slot_$slot')),
        matching: findAssetImage(foodAsset(h.game.tray[slot]!)),
      );
      expect(picture, findsWidgets, reason: 'slot $slot');
    }
  });

  testWidgets('met colours are dots of the monster paint, the others empty rings', (tester) async {
    final h = await _startGame(tester);
    BoxDecoration dot(MonsterColor color) => tester
        .widget<Container>(find.descendant(
          of: find.byKey(ValueKey('monsters_met_${color.name}')),
          matching: find.byType(Container),
        ))
        .decoration! as BoxDecoration;

    for (final color in MonsterColor.values) {
      if (h.game.metColors.contains(color)) {
        expect(dot(color).color, monsterPaint(color), reason: color.name);
      } else {
        expect(dot(color).color, isNull, reason: color.name);
        expect((dot(color).border! as Border).top.color, const Color(0xFFDCC2A2), reason: color.name);
      }
    }
  });
```

- [ ] **Step 2: Запустить — падает**

Run: `flutter test test/presentation/screens/monsters_screen_test.dart`
Expected: FAIL в трёх новых тестах (картинок фона/подноса/еды нет, у точек `monsterFill`).

- [ ] **Step 3: Цвета и раскладка**

Убрать `import 'package:flutter_svg/flutter_svg.dart';`, добавить `import 'dart:ui' as ui;`. Константы `:16-19` заменить на:

```dart
// Warm paper colours, like the scenes and the site.
const _paper = Color(0xFFFFF8F0);
const _card = Color(0xFFFFF0E1);
const _ink = Color(0xFF2B211A);
const _stitch = Color(0xFFDCC2A2);
const _outline = Color(0xFF6B4A2E);
const _shadow = Color(0x24543410);
```

В `_Layout` после `slot(...)` добавить:

```dart
  /// Where the tray picture is drawn: the lower 70% of the tray, as in the
  /// prototype, so the treats stand on its bottom board.
  Rect get trayPicture => Rect.fromLTWH(tray.left, tray.top + tray.height * .24, tray.width, tray.height * .7);
```

- [ ] **Step 4: Кухня и поднос в `build`**

`Scaffold(backgroundColor: _sky, body: SafeArea(...))` заменить на:

```dart
      child: Scaffold(
        backgroundColor: _paper,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // The kitchen fills the whole screen, under the system bars too;
            // pinned to the bottom so the tray stands on the table.
            const Image(
              key: ValueKey('monsters_background'),
              image: AssetImage(monstersBackgroundAsset),
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              excludeFromSemantics: true,
            ),
            SafeArea(
              child: LayoutBuilder(
                // … без изменений до блока подноса …
              ),
            ),
          ],
        ),
      ),
```

Блок `Positioned.fromRect(rect: layout.tray, child: const DecoratedBox(...))` заменить на:

```dart
                    Positioned.fromRect(
                      rect: layout.trayPicture,
                      child: const Image(
                        key: ValueKey('monsters_tray_picture'),
                        image: AssetImage(monstersTrayAsset),
                        fit: BoxFit.fill,
                        excludeFromSemantics: true,
                      ),
                    ),
```

- [ ] **Step 5: Еда — картинка с мягкой тенью**

Добавить в конец файла:

```dart
/// A treat's picture with a soft warm shadow under it; a [lifted] treat
/// (under a finger or flying) casts a bigger one, further down.
class _FoodPicture extends StatelessWidget {
  const _FoodPicture(this.food, {this.lifted = false});

  final MonsterFood food;
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    Widget picture() => Image.asset(
          foodAsset(food),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        );
    final blur = lifted ? 5.0 : 2.5;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(0, lifted ? 14 : 5),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(Color(lifted ? 0x47543410 : 0x38543410), BlendMode.srcIn),
              child: picture(),
            ),
          ),
        ),
        picture(),
      ],
    );
  }
}
```

Заменить `child: SvgPicture.string(foodSvg(floating.food)),` на `child: _FoodPicture(floating.food, lifted: true),` и в `_TrayFoodState.build` `child: SvgPicture.string(foodSvg(widget.food)),` на `child: _FoodPicture(widget.food),`.

- [ ] **Step 6: Кнопки, точки, конфетти**

`_RoundButton.build`, `decoration:`:

```dart
        decoration: const BoxDecoration(
          color: _card,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _shadow, blurRadius: 16, offset: Offset(0, 6))],
        ),
```

`_MetDot.build`, ветки `decoration`:

```dart
    if (justMet) {
      decoration = BoxDecoration(
        color: monsterPaint(color),
        shape: BoxShape.circle,
        border: Border.all(color: _outline, width: 1.5),
        boxShadow: const [BoxShadow(color: _paper, spreadRadius: 3)],
      );
    } else if (met) {
      decoration = BoxDecoration(
        color: monsterPaint(color),
        shape: BoxShape.circle,
        border: Border.all(color: _outline, width: 1.5),
      );
    } else {
      decoration = BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _stitch, width: 2),
      );
    }
```

`_ConfettiPiece`: `color = monsterFill(...)` → `color = monsterPaint(...)`.

- [ ] **Step 7: Запустить — проходит**

Run: `flutter test test/presentation/screens/monsters_screen_test.dart && flutter analyze lib/presentation/screens/monsters_screen.dart`
Expected: PASS все тесты экрана; `No issues found!`.

- [ ] **Step 8: Commit**

```bash
git add lib/presentation/screens/monsters_screen.dart test/presentation/screens/monsters_screen_test.dart
git commit -m "feat(monsters): painted kitchen and tray, warm buttons and dots, treats as pictures

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Миниатюра в списке сцен и экран отдыха

**Files:**
- Create: `lib/presentation/monsters/monsters_thumbnail.dart`
- Modify: `lib/presentation/screens/scene_list_screen.dart` (`:4`, `:8-10`, `:105`, удалить `:163-218`), `lib/presentation/screens/rest_screen.dart`
- Test: `test/presentation/monsters/monsters_thumbnail_test.dart`, `test/presentation/screens/rest_screen_test.dart`

**Interfaces:**
- Consumes: `monsterPictureAsset`, `foodAsset`, `monstersBackgroundAsset`, `monstersTrayAsset` (задача 1).
- Produces: `class MonstersThumbnail extends StatelessWidget { const MonstersThumbnail({super.key}); }`.

- [ ] **Step 1: Написать падающие тесты**

`test/presentation/monsters/monsters_thumbnail_test.dart`:

```dart
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
```

`test/presentation/screens/rest_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/presentation/monsters/monster_art.dart';
import 'package:yandee/presentation/screens/rest_screen.dart';

import '../../support/asset_image_finder.dart';

void main() {
  testWidgets('the blue monster sleeps with its eyes shut', (tester) async {
    await tester.pumpWidget(MaterialApp(home: RestScreen(playPhrase: () async {})));

    expect(find.text('Пора отдохнуть!'), findsOneWidget);
    final monster = findAssetImage(monsterPictureAsset(MonsterColor.blue, MonsterPicture.chomp));
    expect(monster, findsOneWidget);
    expect(tester.getSize(monster), const Size(200, 200));
  });
}
```

- [ ] **Step 2: Запустить — падает**

Run: `flutter test test/presentation/monsters/monsters_thumbnail_test.dart test/presentation/screens/rest_screen_test.dart`
Expected: FAIL: нет `monsters_thumbnail.dart`; на экране отдыха нет картинки `blue_chomp`.

- [ ] **Step 3: `MonstersThumbnail`**

`lib/presentation/monsters/monsters_thumbnail.dart`:

```dart
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
```

- [ ] **Step 4: Список сцен берёт `MonstersThumbnail`**

В `scene_list_screen.dart`:
- `:105` `_MonstersThumbnail()` → `MonstersThumbnail()`;
- удалить класс `_MonstersThumbnail` (`:163-218`);
- удалить импорты `flutter_svg`, `monster_color.dart`, `monster_food.dart`, `monster_art.dart`, если `flutter analyze` скажет, что они не используются; добавить `import '../monsters/monsters_thumbnail.dart';`.

- [ ] **Step 5: Экран отдыха — `blue_chomp`**

В `rest_screen.dart`:
- убрать `import 'package:flutter_svg/flutter_svg.dart';`;
- убрать строку `final monster = MonsterLayers.of(MonsterColor.blue);`;
- блок `SizedBox(width: 200, height: 200, child: Stack(...))` заменить на:

```dart
              // The blue monster with its eyes shut, as if asleep.
              Image.asset(
                monsterPictureAsset(MonsterColor.blue, MonsterPicture.chomp),
                width: 200,
                height: 200,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
```

- [ ] **Step 6: Запустить — проходит**

Run: `flutter test test/presentation/monsters/ test/presentation/screens/rest_screen_test.dart test/presentation/screens/scene_list_screen_test.dart test/presentation/widgets/play_timer_scope_test.dart`
Expected: PASS все.

- [ ] **Step 7: Commit**

```bash
git add lib/presentation/monsters/monsters_thumbnail.dart lib/presentation/screens/scene_list_screen.dart lib/presentation/screens/rest_screen.dart test/presentation/monsters/monsters_thumbnail_test.dart test/presentation/screens/rest_screen_test.dart
git commit -m "feat(monsters): the card thumbnail and the rest screen use the painted monsters

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Убрать SVG-рисование монстриков

**Files:**
- Modify: `lib/presentation/monsters/monster_art.dart` (оставить только раздел `pictures` и `monsterMouthAt`)

**Interfaces:**
- Consumes: ничего нового.
- Produces: `monster_art.dart` экспортирует только `MonsterPicture`, `monstersArtFolder`, `monsterPictureAsset`, `foodAsset`, `monstersBackgroundAsset`, `monstersTrayAsset`, `monsterPaint`, `monsterMouthAt`.

- [ ] **Step 1: Убедиться, что старое больше никто не зовёт**

Run: `grep -rn "MonsterLayers\|foodSvg\|monsterFill\|monsterDark\|monsterShades\|MonsterShades\|monsterViewBoxSize\|monsterLeftHandAt\|monsterRightHandAt\|monsterPupilReach" lib test`
Expected: совпадения только внутри `lib/presentation/monsters/monster_art.dart`.

- [ ] **Step 2: Переписать `monster_art.dart`**

Файл целиком:

```dart
import 'dart:ui' show Color;

import '../../domain/monsters/monster_color.dart';
import '../../domain/monsters/monster_food.dart';

/// The painted pictures of the "Монстрики" game: where each one lives, and
/// the few things the code needs to know about them.
///
/// The pictures were made in ChatGPT (`docs/prototypes/monsters_one_prompt.md`)
/// and are turned into the bundled WebP files by `tool/prepare_monster_art.py`.

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
```

- [ ] **Step 3: Весь набор тестов и анализ**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; `All tests passed!`.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/monsters/monster_art.dart
git commit -m "refactor(monsters): drop the code-drawn SVG monsters and treats

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Проверка в приложении

**Files:** без изменений кода (если найдено что-то — чинить в файле из задач 2–4 и коммитить отдельно).

- [ ] **Step 1: Запустить в iOS-симуляторе**

Открыть панель симулятора (`attach`), собрать `flutter build ios --simulator --debug`, `launch` `build/ios/iphonesimulator/Runner.app`.

- [ ] **Step 2: Посмотреть и снять скриншоты**

- список сцен: карточка «Монстрики» — кухня, 4 монстрика, поднос с едой;
- игра: монстрики стоят на кухне, поднос на столе, кнопки кремовые, точки цветные;
- перетащить еду к своему монстрику: рот открывается, монстрик наклоняется, жуёт, хлопает руками;
- перетащить к чужому: «фу», трясётся;
- кормить до ухода: машет правой рукой, уходит, приходит новый без пустого кадра.

- [ ] **Step 3: Итог**

`git status` чистый (кроме чужих `.DS_Store` и неотслеживаемых файлов, которые были до работы). Мерж и пуш — только по слову пользователя.
