# Фонарик: только звери и силуэты — план реализации

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** В игре с фонариком прячутся только предметы с контуром (в «Лесу» — пять зверей), а найденный проступает из темноты по своему силуэту, а не овальным пятном.

**Architecture:** Контур — необязательный многоугольник в `scene.json` (`objects[].outline`, `realistic.outlines`). Предмет с контуром на основной картинке — цель фонарика; `FlashlightMode` считает только цели, `SceneController` в режиме фонарика отдаёт для попадания пальца только цели, `FlashlightDarkness` вырезает найденную цель по контуру.

**Tech Stack:** Flutter / Dart 3.3, provider, flutter_test. Контуры подготовлены разовым скриптом `tool/extract_outlines.py` (macOS Vision + OpenCV), в рантайме не используется.

Спецификация: `docs/superpowers/specs/2026-11-14-flashlight-animals-outline-design.md`.

## Global Constraints

- Координаты контура — доли картинки 0..1, как у `rect`.
- Цель фонарика — предмет, у которого есть `outline` на **основной** картинке; набор целей не зависит от того, какая картинка на экране.
- `outline` необязателен: сцены без него работают как раньше, игра в них не предлагается.
- Версия сцены `forest` — 4.
- Не входит: размер и положение луча, поведение света при поднятом пальце, озвучка, режимы «Смотри» и «Найди».
- Коммиты — только по явной просьбе пользователя.

## Файлы

| Файл | Что делает |
|---|---|
| `lib/domain/models/object_outline.dart` (новый) | `ObjectOutline`: многоугольник силуэта, разбор из JSON |
| `lib/domain/models/scene_object.dart` | `outline`, `placedAt` вместо `withRect` |
| `lib/domain/models/scene_variant.dart` | `outlines` реалистичной картинки |
| `lib/domain/models/scene.dart` | `objectsFor` подставляет зону и контур картинки |
| `lib/domain/modes/flashlight_mode.dart` | цели — только предметы с контуром, `isTarget` |
| `lib/presentation/controllers/scene_controller.dart` | `hasFlashlight` по данным сцены, `touchableObjects` |
| `lib/presentation/widgets/scene_illustration.dart` | попадание пальца по `touchableObjects` |
| `lib/presentation/widgets/flashlight_darkness.dart` | вырез по контуру, овал как запасной вариант |
| `assets/demo_content/forest/scene.json` | контуры пяти зверей на обеих картинках, версия 4 |
| `tool/extract_outlines.py`, `tool/subject_masks.swift` | подготовка контуров (уже написаны и прогнаны) |

---

### Task 1: Контуры в модели сцены

**Files:**
- Create: `lib/domain/models/object_outline.dart`
- Modify: `lib/domain/models/scene_object.dart`, `lib/domain/models/scene_variant.dart`, `lib/domain/models/scene.dart`
- Test: `test/domain/models/scene_test.dart`

**Interfaces:**
- Produces: `typedef OutlinePoint = ({double x, double y})`; `ObjectOutline(List<OutlinePoint> points)`, `ObjectOutline.fromJson(List<dynamic>)`; `SceneObject.outline` (`ObjectOutline?`); `SceneObject.placedAt({required ObjectRect rect, required ObjectOutline? outline})`; `SceneVariant.outlines` (`Map<String, ObjectOutline>`, по умолчанию пусто).

- [ ] **Step 1: Падающие тесты** — в конец `main()` в `test/domain/models/scene_test.dart`:

```dart
  group('outline', () {
    final jsonWithOutlines = {
      ...json,
      'objects': [
        {
          'id': 'fox',
          'label': 'Лиса',
          'audio': 'fox.wav',
          'rect': {'x': 0.1, 'y': 0.1, 'width': 0.2, 'height': 0.2},
          'outline': [
            [0.1, 0.1],
            [0.3, 0.1],
            [0.2, 0.3],
          ],
        },
        {
          'id': 'hare',
          'label': 'Заяц',
          'audio': 'hare.wav',
          'rect': {'x': 0.5, 'y': 0.1, 'width': 0.2, 'height': 0.2},
          'outline': [
            [0.5, 0.1],
            [0.7, 0.1],
            [0.6, 0.3],
          ],
        },
        {
          'id': 'bear',
          'label': 'Медведь',
          'audio': 'bear.wav',
          'rect': {'x': 0.1, 'y': 0.5, 'width': 0.2, 'height': 0.2},
          'outline': [
            [0.1, 0.5],
            [0.3, 0.5],
            [0.2, 0.7],
          ],
        },
        {
          'id': 'tree',
          'label': 'Дерево',
          'audio': 'tree.wav',
          'rect': {'x': 0.5, 'y': 0.5, 'width': 0.2, 'height': 0.2},
        },
      ],
      'realistic': {
        'background': 'background_real.png',
        'rects': {
          'fox': {'x': 0.15, 'y': 0.15, 'width': 0.2, 'height': 0.2},
          'hare': {'x': 0.55, 'y': 0.15, 'width': 0.2, 'height': 0.2},
        },
        'outlines': {
          'fox': [
            [0.15, 0.15],
            [0.35, 0.15],
            [0.25, 0.35],
          ],
        },
      },
    };

    test('an object without an outline has none', () {
      expect(Scene.fromJson(json).objects.single.outline, isNull);
    });

    test('SceneObject.fromJson parses the outline points in order', () {
      final fox = Scene.fromJson(jsonWithOutlines).objects.first;
      expect(fox.outline!.points, [(x: 0.1, y: 0.1), (x: 0.3, y: 0.1), (x: 0.2, y: 0.3)]);
    });

    test('the realistic picture brings its own outline along with its tap zone', () {
      final fox = Scene.fromJson(jsonWithOutlines).objectsFor(realistic: true).first;
      expect(fox.rect.x, 0.15);
      expect(fox.outline!.points.first, (x: 0.15, y: 0.15));
    });

    test('an object moved on the realistic picture without an outline there has none', () {
      // The default outline would be drawn in the wrong place.
      final hare = Scene.fromJson(jsonWithOutlines).objectsFor(realistic: true)[1];
      expect(hare.rect.x, 0.55);
      expect(hare.outline, isNull);
    });

    test('an object the realistic picture leaves in place keeps its outline', () {
      final bear = Scene.fromJson(jsonWithOutlines).objectsFor(realistic: true)[2];
      expect(bear.outline!.points.first, (x: 0.1, y: 0.5));
    });

    test('a realistic variant without outlines parses to none', () {
      final scene = Scene.fromJson({
        ...jsonWithOutlines,
        'realistic': {'background': 'background_real.png'},
      });
      expect(scene.realistic!.outlines, isEmpty);
    });
  });
```

- [ ] **Step 2: Убедиться, что падает** — `flutter test test/domain/models/scene_test.dart` → ошибка компиляции: нет `outline`.

- [ ] **Step 3: Реализация**

`lib/domain/models/object_outline.dart`:

```dart
/// One corner of an [ObjectOutline], normalized (0..1) to the picture.
typedef OutlinePoint = ({double x, double y});

/// An object's silhouette as a closed polygon, relative to the scene's
/// picture — like `ObjectRect`, never device pixels. The flashlight game
/// shows a found object through the dark in this shape.
class ObjectOutline {
  const ObjectOutline(this.points);

  /// The polygon's corners in order; the last one joins back to the first.
  final List<OutlinePoint> points;

  /// Parses `[[x, y], [x, y], ...]`.
  factory ObjectOutline.fromJson(List<dynamic> json) => ObjectOutline([
        for (final point in json.cast<List<dynamic>>())
          (x: (point[0] as num).toDouble(), y: (point[1] as num).toDouble()),
      ]);
}
```

`lib/domain/models/scene_object.dart` — импорт `object_outline.dart`, поле и разбор, `placedAt` вместо `withRect`:

```dart
  const SceneObject({
    required this.id,
    required this.label,
    required this.audio,
    required this.rect,
    this.outline,
  });

  final String id;
  final String label;
  final String audio;
  final ObjectRect rect;

  /// The object's silhouette on the picture, for the objects that have one
  /// marked up. Having one on the scene's default picture is what makes an
  /// object something to find in the flashlight game.
  final ObjectOutline? outline;

  factory SceneObject.fromJson(Map<String, dynamic> json) {
    return SceneObject(
      id: json['id'] as String,
      label: json['label'] as String,
      audio: json['audio'] as String,
      rect: ObjectRect.fromJson(json['rect'] as Map<String, dynamic>),
      outline: json['outline'] == null ? null : ObjectOutline.fromJson(json['outline'] as List<dynamic>),
    );
  }

  /// The same object as it sits on a different picture.
  SceneObject placedAt({required ObjectRect rect, required ObjectOutline? outline}) =>
      SceneObject(id: id, label: label, audio: audio, rect: rect, outline: outline);
```

`lib/domain/models/scene_variant.dart` — импорт `object_outline.dart`:

```dart
  const SceneVariant({required this.background, required this.rects, this.outlines = const {}});

  /// This variant's silhouettes, keyed by `SceneObject.id`, for the objects
  /// that have one marked up on this picture.
  final Map<String, ObjectOutline> outlines;
```

и в `fromJson`:

```dart
      outlines: (json['outlines'] as Map<String, dynamic>? ?? const {}).map(
        (objectId, outline) => MapEntry(objectId, ObjectOutline.fromJson(outline as List<dynamic>)),
      ),
```

`lib/domain/models/scene.dart` — `objectsFor`:

```dart
  /// The scene's objects as they sit on the picture being shown: on the
  /// default illustration, or — with [realistic] set, when the scene has
  /// that variant — at the realistic picture's tap zones, with its
  /// outlines. An object the variant moves but gives no outline has none
  /// there (its default one would be in the wrong place); one it leaves
  /// where it is keeps its own. Order is the same either way, since it is
  /// also the tap priority.
  List<SceneObject> objectsFor({required bool realistic}) {
    final variant = this.realistic;
    if (!realistic || variant == null) return objects;
    return [
      for (final object in objects)
        if (variant.rects[object.id] case final rect?)
          object.placedAt(rect: rect, outline: variant.outlines[object.id])
        else if (variant.outlines[object.id] case final outline?)
          object.placedAt(rect: object.rect, outline: outline)
        else
          object,
    ];
  }
```

- [ ] **Step 4: Тесты проходят** — `flutter test test/domain/models/scene_test.dart` → All tests passed.

---

### Task 2: Цели фонарика — только предметы с контуром

**Files:**
- Modify: `lib/domain/modes/flashlight_mode.dart`
- Test: `test/domain/modes/flashlight_mode_test.dart`

**Interfaces:**
- Consumes: `SceneObject.outline`.
- Produces: `FlashlightMode.isTarget(SceneObject) → bool`; `totalCount`/`foundCount`/`isFound` считают только цели.

- [ ] **Step 1: Падающие тесты** — заменить объявления предметов и тесты в `test/domain/modes/flashlight_mode_test.dart` (импорт `object_outline.dart`):

```dart
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const outline = ObjectOutline([(x: 0, y: 0), (x: 0.1, y: 0), (x: 0.05, y: 0.1)]);
  const fox = SceneObject(id: 'fox', label: 'Лиса', audio: 'fox.wav', rect: rect, outline: outline);
  const hare1 = SceneObject(id: 'hare_1', label: 'Заяц', audio: 'hare.wav', rect: rect, outline: outline);
  const hare2 = SceneObject(id: 'hare_2', label: 'Заяц', audio: 'hare.wav', rect: rect, outline: outline);
  const bear = SceneObject(id: 'bear', label: 'Медведь', audio: 'bear.wav', rect: rect, outline: outline);
  const tree = SceneObject(id: 'tree', label: 'Дерево', audio: 'tree.wav', rect: rect);
  final objects = [fox, tree, hare1, hare2, bear];
```

Существующие тесты переводятся с `tree1`/`tree2` на `hare1`/`hare2` (число целей остаётся 3), добавляются:

```dart
  test('only objects with an outline are things to find', () {
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    expect(mode.totalCount, 3);
    expect(mode.isTarget(fox), isTrue);
    expect(mode.isTarget(tree), isFalse);
  });

  test('an object is a target on any picture, outline or not', () {
    // The realistic picture may have no outline marked up for it.
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    expect(mode.isTarget(fox.placedAt(rect: rect, outline: null)), isTrue);
  });

  test('lighting anything else does nothing at all', () {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(tree);
    expect(mode.foundCount, 0);
    expect(mode.isFound(tree), isFalse);
    expect(effects.objectAudioCalls, isEmpty);
  });
```

В тесте `taps after the lights are on are ignored` цикл идёт по `objects` — не-цель в нём безвредна.

- [ ] **Step 2: Убедиться, что падает** — `flutter test test/domain/modes/flashlight_mode_test.dart` → нет `isTarget`.

- [ ] **Step 3: Реализация** в `lib/domain/modes/flashlight_mode.dart`:

```dart
/// The scene is dark; the child moves a flashlight over it looking for the
/// things hiding there. Each one the light reaches lights up for good and
/// says its name; lighting up the last one turns the lights on for the
/// whole scene (the round is complete).
///
/// What hides is the objects that have an outline marked up — a handful
/// per scene (the animals in the forest), not everything on the picture,
/// so there is dark to search between them. Everything else is scenery
/// here: the light shows it, and touching it does nothing.
///
/// No order and no wrong answers: the child finds things in whatever order
/// the light happens to reach them. Targets are counted by label, like in
/// Find mode — several of the same thing are one thing to find, and
/// lighting any of them lights all of them.
class FlashlightMode implements SceneMode {
  FlashlightMode({required List<SceneObject> objects, required this.effects})
      : _labels = List.unmodifiable(objects.where((o) => o.outline != null).map((o) => o.label).toSet()) {
    assert(_labels.isNotEmpty, 'FlashlightMode requires at least one object with an outline');
  }
```

```dart
  /// Whether [object] is one of the things hiding in the dark. Goes by
  /// label, so it holds for the object on any of the scene's pictures.
  bool isTarget(SceneObject object) => _labels.contains(object.label);
```

и первая строка `onObjectTapped`:

```dart
    if (_completed || !isTarget(object)) return;
```

- [ ] **Step 4: Тесты проходят** — `flutter test test/domain/modes/flashlight_mode_test.dart`.

---

### Task 3: Контроллер — игра там, где есть цели; палец попадает только по целям

**Files:**
- Modify: `lib/presentation/controllers/scene_controller.dart`, `lib/presentation/widgets/scene_illustration.dart`
- Test: `test/presentation/controllers/scene_controller_test.dart`, `test/presentation/widgets/scene_illustration_test.dart`

**Interfaces:**
- Consumes: `FlashlightMode.isTarget`, `SceneObject.outline`.
- Produces: `SceneController.hasFlashlight` (по данным сцены), `SceneController.touchableObjects → List<SceneObject>`.

- [ ] **Step 1: Падающие тесты** — группа `flashlight` в `scene_controller_test.dart` целиком:

```dart
  group('flashlight', () {
    const outline = ObjectOutline([(x: 0, y: 0), (x: 0.1, y: 0), (x: 0.05, y: 0.1)]);
    const fox = SceneObject(id: 'fox', label: 'Лиса', audio: 'fox.wav', rect: rect, outline: outline);
    const bear = SceneObject(id: 'bear', label: 'Медведь', audio: 'bear.wav', rect: rect, outline: outline);
    final forest = CachedScene(
      scene: Scene(
        id: 'forest',
        version: 1,
        title: 'Лес',
        minAgeMonths: 12,
        background: 'background.png',
        objects: [fox, ball, bear],
      ),
      directoryPath: '/cache/forest',
    );

    test('is offered where the scene has objects with an outline', () {
      expect(SceneController(cachedScene: forest, audioSink: FakeAudioSink()).hasFlashlight, isTrue);
      expect(SceneController(cachedScene: cachedScene, audioSink: FakeAudioSink()).hasFlashlight, isFalse);
    });

    test('only the things to find can be touched while the game is on', () {
      final controller = SceneController(cachedScene: forest, audioSink: FakeAudioSink());
      expect(controller.touchableObjects, [fox, ball, bear]);
      controller.setMode(SceneModeType.flashlight);
      expect(controller.touchableObjects, [fox, bear]);
      controller.setMode(SceneModeType.explore);
      expect(controller.touchableObjects, [fox, ball, bear]);
    });

    test('lighting the targets notifies listeners and ends in the congratulations', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: forest, audioSink: audio);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setMode(SceneModeType.flashlight);
      expect(controller.flashlight, isNotNull);
      notifications = 0;

      controller.onObjectTapped(ball); // scenery: nothing happens
      expect(notifications, 0);
      expect(audio.playedFiles, isEmpty);

      controller.onObjectTapped(fox);
      expect(notifications, 1);
      expect(controller.flashlight!.isFound(fox), isTrue);
      expect(audio.playedFiles, [forest.audioPathFor(fox)]);

      controller.onObjectTapped(fox); // already lit: no change to redraw
      expect(notifications, 1);

      controller.onObjectTapped(bear);
      expect(controller.flashlight!.isComplete, isTrue);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, contains(forest.audioPathFor(bear)));
      expect(controller.showCongrats, isTrue);
    });
  });
```

(импорт `package:yandee/domain/models/object_outline.dart`).

Виджет-тест в `scene_illustration_test.dart` — зона не-цели лежит поверх цели и её не заслоняет (по образцу первого теста файла):

```dart
  testWidgets('in the flashlight game scenery on top of a target does not shadow it', (tester) async {
    late Directory tempDir;
    late CachedScene cachedScene;
    late SceneController controller;
    final audio = FakeAudioSink();
    // `front` sits on top of `hidden` (later in the list wins a tap), and
    // only `hidden` is something to find.
    const hidden = SceneObject(
      id: 'hidden',
      label: 'Лиса',
      audio: 'fox.wav',
      rect: ObjectRect(x: 0.2, y: 0.4, width: 0.4, height: 0.4),
      outline: ObjectOutline([(x: 0.2, y: 0.4), (x: 0.6, y: 0.4), (x: 0.4, y: 0.8)]),
    );

    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() async {
      tempDir = await Directory.systemTemp.createTemp('yandee_illustration_flashlight_test_');
      await writeFixturePng(tempDir, 'background.png', width: 400, height: 300);
      cachedScene = CachedScene(
        scene: Scene(
          id: 'demo',
          version: 1,
          title: 'Демо',
          minAgeMonths: 12,
          background: 'background.png',
          objects: [hidden, front, cat],
        ),
        directoryPath: tempDir.path,
      );
      controller = SceneController(cachedScene: cachedScene, audioSink: audio);
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(
          width: 800,
          height: 800,
          child: ChangeNotifierProvider.value(
            value: controller,
            child: SceneIllustration(cachedScene: cachedScene),
          ),
        ),
      ));
      for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    addTearDown(() => tempDir.delete(recursive: true));
    addTearDown(controller.dispose);

    // Explore: the object on top answers.
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_front'))));
    await tester.pump();
    expect(audio.playedFiles, [cachedScene.audioPathFor(front)]);

    controller.setMode(SceneModeType.flashlight);
    await tester.pump();
    audio.playedFiles.clear();

    // Scenery alone: silent, nothing found.
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_cat'))));
    await tester.pump();
    expect(audio.playedFiles, isEmpty);
    expect(controller.flashlight!.foundCount, 0);

    // The same spot as before now reaches the target underneath, and that
    // being the only target, finishes the round.
    await tester.tapAt(tester.getCenter(find.byKey(const ValueKey('object_zone_front'))));
    await tester.pump();
    expect(controller.flashlight!.isFound(hidden), isTrue);
    expect(controller.flashlight!.isComplete, isTrue);

    // Let the darkness fade and the congratulations timer run out.
    await tester.pump(const Duration(seconds: 3));
  });
```

(импорт `object_outline.dart`).

- [ ] **Step 2: Убедиться, что падают** — `flutter test test/presentation/controllers/scene_controller_test.dart test/presentation/widgets/scene_illustration_test.dart`.

- [ ] **Step 3: Реализация**

`scene_controller.dart` — вместо `flashlightSceneIds` и старого `hasFlashlight`:

```dart
  /// Whether this scene offers the flashlight game: it does when it has
  /// something to hide in the dark, i.e. objects with an outline marked up.
  bool get hasFlashlight => cachedScene.scene.objects.any((object) => object.outline != null);

  /// The running flashlight game, or null in any other mode.
  FlashlightMode? get flashlight => _mode is FlashlightMode ? _mode as FlashlightMode : null;

  /// The objects a finger can land on right now, in the picture's tap
  /// order: all of them, except in the flashlight game, where only the
  /// things to find count — so a tree or a path whose tap zone lies over
  /// an animal's doesn't keep the finger from reaching it.
  List<SceneObject> get touchableObjects {
    final flashlight = this.flashlight;
    final objects = visibleObjects;
    return flashlight == null ? objects : objects.where(flashlight.isTarget).toList();
  }
```

`scene_illustration.dart` — `_objectAt` перебирает `touchableObjects`:

```dart
    for (final object in context.read<SceneController>().touchableObjects.reversed) {
```

и в комментарии над ним дописать: `In the flashlight game only the things to find are there to be hit.`

- [ ] **Step 4: Тесты проходят** — та же команда.

---

### Task 4: Темнота вырезается по силуэту

**Files:**
- Modify: `lib/presentation/widgets/flashlight_darkness.dart`, `lib/presentation/widgets/scene_illustration.dart`
- Test: `test/presentation/widgets/flashlight_darkness_test.dart` (новый)

**Interfaces:**
- Consumes: `SceneObject.outline`, `SceneController.touchableObjects`.
- Produces: `FlashlightDarkness.objects` — теперь «цели фонарика на показанной картинке»; сигнатура виджета не меняется.

- [ ] **Step 1: Падающий тест** — `test/presentation/widgets/flashlight_darkness_test.dart`. Темнота рисуется на холсте, поэтому проверяем сам рисунок: пиксель внутри силуэта найденной цели прозрачен, пиксель в углу её зоны, но вне силуэта, остаётся тёмным (у овала по зоне было бы иначе — см. точки ниже).

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_outline.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/presentation/widgets/flashlight_darkness.dart';

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

  /// Alpha (0..255) of the darkness at a point given in shares of its size,
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
    // Past the 500 ms reveal animation; the stopwatch behind it is real
    // time, hence runAsync.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final x = (point.dx * side).round(), y = (point.dy * side).round();
    return bytes.getUint8((y * image.width + x) * 4 + 3);
  }

  const insideSilhouette = Offset(0.55, 0.8);
  // Inside the zone (and inside the oval a zone-shaped hole would be), but
  // right of the triangle.
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
```

- [ ] **Step 2: Убедиться, что падает** — `flutter test test/presentation/widgets/flashlight_darkness_test.dart` → первый тест падает на `besideSilhouette` (сейчас там овал).

- [ ] **Step 3: Реализация** в `_DarknessPainter.paint` — цикл по найденным:

```dart
    for (final object in objects) {
      final found = foundAt[object.id];
      if (found == null) continue;
      final progress = Curves.easeOutBack
          .transform(((now - found).inMicroseconds / _revealDuration.inMicroseconds).clamp(0.0, 1.0));
      if (progress <= 0) continue;
      final outline = object.outline;
      if (outline == null) {
        _cutOval(canvas, _rectOf(object, size), progress);
      } else {
        _cutSilhouette(canvas, _pathOf(outline, size), size, progress);
      }
    }
```

и новые методы:

```dart
  // The found object's own shape, with a little room around it and a soft
  // edge, popping out from its middle.
  void _cutSilhouette(Canvas canvas, Path silhouette, Size size, double progress) {
    final center = silhouette.getBounds().center;
    final edge = MaskFilter.blur(BlurStyle.normal, size.width * 0.008);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(progress);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(
      silhouette,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = edge,
    );
    // Stroking the same shape widens the hole past the silhouette, so the
    // soft edge falls on the scenery around the object, not on the object.
    canvas.drawPath(
      silhouette,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = edge,
    );
    canvas.restore();
  }

  // For an object with no outline on the picture being shown: a soft oval
  // over its tap zone.
  void _cutOval(Canvas canvas, Rect rect, double progress) {
    final glow = rect.inflate(rect.shortestSide * 0.12);
    canvas.drawOval(
      Rect.fromCenter(center: glow.center, width: glow.width * progress, height: glow.height * progress),
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.shortestSide * 0.15),
    );
  }

  Path _pathOf(ObjectOutline outline, Size size) => Path()
    ..addPolygon([for (final point in outline.points) Offset(point.x * size.width, point.y * size.height)], true);
```

(импорт `../../domain/models/object_outline.dart`). Док-комментарий поля `objects` виджета: `The things to find, as they sit on the picture being shown.`; в комментарии класса «objects the child has already found» остаётся верным.

`scene_illustration.dart` — темноте передаются только цели:

```dart
                      objects: controller.touchableObjects,
```

- [ ] **Step 4: Тесты проходят** — `flutter test test/presentation/widgets/`.

---

### Task 5: Контент «Леса» и проверка собранных сцен

**Files:**
- Modify: `assets/demo_content/forest/scene.json` (контуры уже записаны скриптом; поднять `version` до 4)
- Test: `test/data/bundled_scenes_test.dart`

- [ ] **Step 1: Падающие тесты** — в `bundled_scenes_test.dart`, внутри цикла по сценам:

```dart
    test('$sceneId: outlines are polygons inside the picture, for objects that exist', () {
      final scene = readScene(dir);
      final outlines = {
        for (final object in scene.objects)
          if (object.outline != null) object.id: object.outline!,
        for (final entry in (scene.realistic?.outlines ?? const <String, ObjectOutline>{}).entries)
          '${entry.key} (realistic)': entry.value,
      };
      for (final entry in outlines.entries) {
        expect(entry.value.points.length, greaterThanOrEqualTo(3), reason: entry.key);
        for (final point in entry.value.points) {
          expect(point.x, inInclusiveRange(0, 1), reason: entry.key);
          expect(point.y, inInclusiveRange(0, 1), reason: entry.key);
        }
      }
      final ids = scene.objects.map((o) => o.id).toSet();
      expect(ids, containsAll(scene.realistic?.outlines.keys ?? const <String>[]));
    });

    test('$sceneId: a flashlight target has an outline on the realistic picture too', () {
      final scene = readScene(dir);
      final realistic = scene.realistic;
      if (realistic == null) return;
      final targets = scene.objects.where((o) => o.outline != null).map((o) => o.id).toSet();
      expect(realistic.outlines.keys.toSet(), targets);
    });
```

и после цикла:

```dart
  test('the forest hides its five animals in the flashlight game', () {
    final forest = readScene(sceneDirs.singleWhere((dir) => p.basename(dir.path) == 'forest'));
    expect(forest.version, greaterThanOrEqualTo(4));
    expect(
      forest.objects.where((o) => o.outline != null).map((o) => o.label).toSet(),
      {'Медведь', 'Лиса', 'Заяц', 'Белка', 'Ёж'},
    );
  });
```

(импорт `package:yandee/domain/models/object_outline.dart`).

- [ ] **Step 2: Убедиться, что падает** — `flutter test test/data/bundled_scenes_test.dart` → `forest.version` равен 3.

- [ ] **Step 3: Поднять версию** — в `assets/demo_content/forest/scene.json` `"version":3` → `"version":4`.

- [ ] **Step 4: Тесты проходят** — `flutter test test/data/`.

---

### Task 6: Общая проверка и сборка на iPhone

- [ ] **Step 1:** `flutter analyze` → No issues found.
- [ ] **Step 2:** `flutter test` → All tests passed.
- [ ] **Step 3:** `flutter build ios --release`, затем `xcrun devicectl device install app --device 00008140-0001602602D8801C build/ios/iphoneos/Runner.app` и запуск.
- [ ] **Step 4:** Пользователь проверяет игру на телефоне: пять звёзд, зверь проступает силуэтом, остальное в темноте молчит.
