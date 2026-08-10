# Yandee Interactive Scenes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Yandee MVP — a Flutter app with a scene list and a scene screen offering "Explore" (tap → hear name) and "Find" (tap the requested object) modes, backed by an offline-first, versioned content cache synced from a static CDN.

**Architecture:** Three layers. Domain: JSON-mirrored content models plus a pluggable `SceneMode` interface (`ExploreMode`, `FindMode`) driven through a `SceneModeEffects` port so game logic never touches audio/platform code directly. Data: `ContentRepository` reads/writes a local file cache and syncs it from a CDN with atomic per-scene swaps. Presentation: `SceneController` (`ChangeNotifier`, via `provider`) wires a `SceneMode` to an `AudioSink`, and two screens (`SceneListScreen`, `SceneScreen`) render off it.

**Tech Stack:** Flutter 3.44 / Dart 3.12, `provider` (state), `http` (network), `path_provider` (cache location), `path` (path joins), `audioplayers` (playback). No backend — static hosting (object storage + CDN) only.

## Global Constraints

- The repo currently has **no** `lib/`, `android/`, `ios/`, or any Dart source — only a `pubspec.yaml`/`README.md` for an unrelated prior project (`coviewing_app`). Task 1 bootstraps a real Flutter project from scratch and renames the package to `yandee`.
- `rect` coordinates in scene content are normalized `0..1` fractions of the image, never pixels; tap zones are axis-aligned rectangles, not polygons.
- `version` on a scene and `scenesVersion` on the index are plain increasing integers used purely for cache invalidation (higher wins).
- `SceneScreen` opens in Explore mode by default; the parent switches modes manually via a control in the corner of the screen. The screen never closes itself — only an explicit back action returns to `SceneListScreen`.
- Find mode: a wrong tap gives a soft hint and never resets progress; a correct tap advances to the next not-yet-found object; after the last object, a fanfare plays, a ~2 second congratulations animation shows, then the mode automatically reverts to Explore.
- Content lives on static hosting (object storage + CDN) — there is no backend, no accounts, no child profiles, no per-child progress tracking. Publishing new/updated scene content must never require an app store release.
- The UI always renders from the local cache; network is used only to check for and download updates in the background. A scene download is written to a temp location and atomically swapped in only once fully complete — a partial or failed download must never replace a working cached version.
- Error handling (verbatim from spec):

  | Situation | Behavior |
  |---|---|
  | No network, cache empty (first run) | "No connection" screen with a retry button |
  | No network, cache non-empty | Serve from cache silently, no banners |
  | Index downloaded but a scene fails to download | That scene doesn't appear/update in the list; retried on the next check |
  | Audio playback error | Logged and swallowed silently; gameplay is never blocked |
  | Tap outside all object zones | Ignored, no reaction |
- Explicitly out of scope for this plan: accounts/login, child profiles/age filtering, progress/stats tracking, monetization/paywall, content-upload tooling for the content team, and any video-player code/dependency (none exists in this repo to remove, and none should be reintroduced).
- The `SceneMode` / `SceneModeEffects` abstraction is the extension point for future modes (e.g. "fact about the object", "find in sequence") — new modes must be addable as new classes without changing `SceneController` or either screen.
- Since no real hosted content exists yet, Task 7 generates small placeholder PNG/WAV assets via pure-Dart scripts (no external tools) — clearly placeholder art/audio, replaced later by the content team's real assets through the same content contract.

---

## Task 1: Bootstrap the Flutter project and rename the package

**Files:**
- Create: `android/`, `ios/`, `lib/main.dart` (temporary default, overwritten in Task 15), `test/widget_test.dart` (deleted in this task) — via `flutter create`
- Modify: `pubspec.yaml`, `README.md`, `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: a working `flutter test` / `flutter analyze` baseline; package name `yandee` that every later task's `package:yandee/...` imports rely on.

- [ ] **Step 1: Generate the platform scaffold**

Run from the repo root:

```bash
flutter create --platforms=android,ios --org com.yandee --project-name yandee .
```

This adds `android/`, `ios/`, `lib/main.dart` (Flutter's default counter template), `test/widget_test.dart` (default counter test), `analysis_options.yaml`, `.metadata`, etc. It does **not** touch the existing `pubspec.yaml` or `README.md`.

- [ ] **Step 2: Replace `pubspec.yaml`**

```yaml
name: yandee
description: "Yandee — интерактивные обучающие сцены для детей 1–3 лет"
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.5+1
  http: ^1.6.0
  path_provider: ^2.1.6
  path: ^1.9.1
  audioplayers: ^6.8.1
  cupertino_icons: ^1.0.9

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

(No `assets:` list yet — Task 7 adds it once the asset files actually exist, so no task ever leaves the pubspec pointing at missing directories.)

- [ ] **Step 3: Delete the default counter test**

```bash
rm test/widget_test.dart
```

It references the scaffold's default `MyApp` counter widget, which this project doesn't have. Every later task adds its own tests.

- [ ] **Step 4: Fix the Android app label**

In `android/app/src/main/AndroidManifest.xml`, `flutter create` wrote `android:label="yandee"` (lowercase, from the project name). Change it to the display name:

```xml
android:label="Yandee"
```

(iOS's `ios/Runner/Info.plist` already got `CFBundleDisplayName` = `Yandee` automatically from `flutter create` — no edit needed there.)

- [ ] **Step 5: Rewrite `README.md`**

```markdown
# Yandee

Интерактивные обучающие сцены для детей 1–3 лет. Ребёнок открывает сцену
(статичная иллюстрация с ~10 объектами) и может:

- **«Исследовать»** — тапнуть объект, услышать его название.
- **«Найди»** — приложение просит найти конкретный объект.

Контент (иллюстрации, аудио) раздаётся со статического хостинга и кэшируется
локально — приложение полностью работает офлайн после первой загрузки.

Дизайн-документ: `docs/superpowers/specs/2026-08-11-yandee-interactive-scenes-design.md`.

## Структура

```
lib/
  domain/
    models/   — Scene, SceneObject, ObjectRect, SceneManifestEntry (зеркалят JSON-схему контента)
    modes/    — SceneMode/SceneModeEffects и реализации ExploreMode, FindMode
  data/       — ContentRepository (кэш + синхронизация с хостингом), DemoContentSeeder
  audio/      — AudioSink/AudioPlayerService
  presentation/
    controllers/ — SceneController
    screens/     — SceneListScreen, SceneScreen
    widgets/     — SceneIllustration и др.
assets/
  audio/system/    — системные фразы (интро, подсказки, туш)
  demo_content/    — офлайн демо-сцена для первого запуска/ручной проверки
tool/
  generate_placeholder_assets.dart — генератор плейсхолдер-арта/аудио
```

## Запуск

```bash
flutter pub get
flutter test
flutter run
```
```

- [ ] **Step 6: Fetch dependencies and verify the baseline**

```bash
flutter pub get
flutter analyze
```

Expected: `flutter pub get` succeeds; `flutter analyze` reports "No issues found!" (the default `lib/main.dart` from `flutter create` is lint-clean).

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: bootstrap Flutter project scaffold as yandee"
```

---

## Task 2: Domain content models

**Files:**
- Create: `lib/domain/models/object_rect.dart`, `lib/domain/models/scene_object.dart`, `lib/domain/models/scene.dart`, `lib/domain/models/scene_manifest_entry.dart`
- Test: `test/domain/models/scene_test.dart`, `test/domain/models/scene_manifest_entry_test.dart`

**Interfaces:**
- Produces: `ObjectRect(x, y, width, height)`, `SceneObject(id, label, audio, rect)`, `Scene(id, version, title, minAgeMonths, background, objects)`, `SceneManifestEntry(id, version, title, thumbnail)` — each with `fromJson(Map<String, dynamic>)`. `SceneObject.==`/`hashCode` compare by `id` only (used by mode logic and widget-test finders). Every later task (modes, data layer, controller, screens) imports these.

- [ ] **Step 1: Write the failing parsing tests**

`test/domain/models/scene_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/scene.dart';

void main() {
  final json = {
    'id': 'city',
    'version': 3,
    'title': 'Город',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      {
        'id': 'tree_1',
        'label': 'Дерево',
        'audio': 'tree_1.mp3',
        'rect': {'x': 0.12, 'y': 0.45, 'width': 0.10, 'height': 0.20},
      },
    ],
  };

  test('Scene.fromJson parses top-level fields', () {
    final scene = Scene.fromJson(json);
    expect(scene.id, 'city');
    expect(scene.version, 3);
    expect(scene.title, 'Город');
    expect(scene.minAgeMonths, 12);
    expect(scene.background, 'background.png');
    expect(scene.objects, hasLength(1));
  });

  test('SceneObject.fromJson parses id/label/audio/rect', () {
    final object = Scene.fromJson(json).objects.first;
    expect(object.id, 'tree_1');
    expect(object.label, 'Дерево');
    expect(object.audio, 'tree_1.mp3');
    expect(object.rect.x, 0.12);
    expect(object.rect.y, 0.45);
    expect(object.rect.width, 0.10);
    expect(object.rect.height, 0.20);
  });

  test('SceneObject equality compares by id', () {
    final a = Scene.fromJson(json).objects.first;
    final b = Scene.fromJson(json).objects.first;
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
  });
}
```

`test/domain/models/scene_manifest_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/scene_manifest_entry.dart';

void main() {
  test('SceneManifestEntry.fromJson parses all fields', () {
    final entry = SceneManifestEntry.fromJson({
      'id': 'city',
      'version': 3,
      'title': 'Город',
      'thumbnail': 'city/thumb.png',
    });
    expect(entry.id, 'city');
    expect(entry.version, 3);
    expect(entry.title, 'Город');
    expect(entry.thumbnail, 'city/thumb.png');
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/domain/models/
```

Expected: FAIL — `package:yandee/domain/models/scene.dart` and `scene_manifest_entry.dart` don't exist yet.

- [ ] **Step 3: Implement the models**

`lib/domain/models/object_rect.dart`:

```dart
/// Normalized (0..1) tap-zone rectangle, relative to the scene's
/// background image — never device pixels, so it's resolution-independent.
class ObjectRect {
  const ObjectRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory ObjectRect.fromJson(Map<String, dynamic> json) {
    return ObjectRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ObjectRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}
```

`lib/domain/models/scene_object.dart`:

```dart
import 'object_rect.dart';

/// A single tappable object in a scene. `audio` and (via [rect]) tap zone
/// are shared by every mode; future modes add their own optional fields
/// here without breaking scenes/app versions that don't read them.
class SceneObject {
  const SceneObject({
    required this.id,
    required this.label,
    required this.audio,
    required this.rect,
  });

  final String id;
  final String label;
  final String audio;
  final ObjectRect rect;

  factory SceneObject.fromJson(Map<String, dynamic> json) {
    return SceneObject(
      id: json['id'] as String,
      label: json['label'] as String,
      audio: json['audio'] as String,
      rect: ObjectRect.fromJson(json['rect'] as Map<String, dynamic>),
    );
  }

  /// Objects are identified by id everywhere in the app (mode logic,
  /// widget-test finders), so equality/hashing only look at it.
  @override
  bool operator ==(Object other) => other is SceneObject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
```

`lib/domain/models/scene.dart`:

```dart
import 'scene_object.dart';

class Scene {
  const Scene({
    required this.id,
    required this.version,
    required this.title,
    required this.minAgeMonths,
    required this.background,
    required this.objects,
  });

  final String id;
  final int version;
  final String title;
  final int minAgeMonths;
  final String background;
  final List<SceneObject> objects;

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'] as String,
      version: json['version'] as int,
      title: json['title'] as String,
      minAgeMonths: json['minAgeMonths'] as int,
      background: json['background'] as String,
      objects: (json['objects'] as List<dynamic>)
          .map((e) => SceneObject.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
```

`lib/domain/models/scene_manifest_entry.dart`:

```dart
/// One row of the hosting root's index manifest (`index.json`) — enough to
/// render a scene-list card and decide whether a newer version needs
/// downloading, without fetching the full `scene.json`.
class SceneManifestEntry {
  const SceneManifestEntry({
    required this.id,
    required this.version,
    required this.title,
    required this.thumbnail,
  });

  final String id;
  final int version;
  final String title;

  /// Path to the thumbnail image, relative to the hosting root (already
  /// includes the scene id, e.g. `"city/thumb.png"` — unlike `Scene`'s own
  /// fields, which are relative to that scene's own folder).
  final String thumbnail;

  factory SceneManifestEntry.fromJson(Map<String, dynamic> json) {
    return SceneManifestEntry(
      id: json['id'] as String,
      version: json['version'] as int,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String,
    );
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/domain/models/
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/models test/domain/models
git commit -m "feat: add domain content models"
```

---

## Task 3: SceneMode contract and system-phrase vocabulary

**Files:**
- Create: `lib/domain/modes/scene_mode.dart`, `lib/domain/modes/scene_mode_effects.dart`

**Interfaces:**
- Consumes: `SceneObject` from Task 2.
- Produces: `abstract class SceneMode { void activate(); void onObjectTapped(SceneObject object); }`; `enum SystemPhrase { findIntro, wrongHint, correct, roundComplete }`; `abstract class SceneModeEffects { void playObjectAudio(SceneObject object); void promptFind(SceneObject target); void playSystemPhrase(SystemPhrase phrase); void onRoundCompleted(); }`. Tasks 4–5 implement `SceneMode` against `SceneModeEffects`; Task 11's `SceneController` implements `SceneModeEffects`.

This task is pure interface/enum declaration — no logic to unit-test directly; correctness is verified through Tasks 4, 5, and 11, which depend on it compiling.

- [ ] **Step 1: Write the interfaces**

`lib/domain/modes/scene_mode_effects.dart`:

```dart
import '../models/scene_object.dart';

/// Bundled system phrases used across modes — not tied to any scene's
/// content, so they ship as app assets rather than downloaded content.
enum SystemPhrase { findIntro, wrongHint, correct, roundComplete }

/// The side-effect port a [SceneMode] talks to. Keeping mode logic behind
/// this interface (instead of calling an audio service directly) is what
/// makes `ExploreMode`/`FindMode` unit-testable with a plain fake, and lets
/// `SceneController` own all audio/timing/UI side effects.
abstract class SceneModeEffects {
  /// Play an object's own recorded name.
  void playObjectAudio(SceneObject object);

  /// Play the "Find:" intro immediately followed by [target]'s name audio.
  void promptFind(SceneObject target);

  /// Play a bundled system phrase (hint, correct, fanfare, ...).
  void playSystemPhrase(SystemPhrase phrase);

  /// Called once when a Find round finishes (all objects found).
  void onRoundCompleted();
}
```

`lib/domain/modes/scene_mode.dart`:

```dart
import '../models/scene_object.dart';

/// A pluggable game mode over the same scene and objects. New modes (e.g.
/// "fact about the object", "find in sequence") are added as new classes
/// implementing this interface — `SceneController` and the screens never
/// change to support them.
abstract class SceneMode {
  /// Called once when this mode becomes active (scene opened in this mode,
  /// or the parent switched into it). May trigger a starting side effect
  /// (e.g. Find mode announces its first target).
  void activate();

  /// Called when the child taps an object's zone.
  void onObjectTapped(SceneObject object);
}
```

- [ ] **Step 2: Verify it compiles**

```bash
flutter analyze lib/domain/modes/
```

Expected: "No issues found!".

- [ ] **Step 3: Commit**

```bash
git add lib/domain/modes/scene_mode.dart lib/domain/modes/scene_mode_effects.dart
git commit -m "feat: add SceneMode/SceneModeEffects contracts"
```

---

## Task 4: ExploreMode

**Files:**
- Create: `lib/domain/modes/explore_mode.dart`, `test/support/fake_scene_mode_effects.dart`
- Test: `test/domain/modes/explore_mode_test.dart`

**Interfaces:**
- Consumes: `SceneMode`, `SceneModeEffects`, `SystemPhrase` from Task 3; `SceneObject` from Task 2.
- Produces: `class ExploreMode implements SceneMode { ExploreMode({required SceneModeEffects effects}); }`. `FakeSceneModeEffects` (test support) is reused by Task 5 and Task 11's tests.

- [ ] **Step 1: Write the fake effects test double**

`test/support/fake_scene_mode_effects.dart`:

```dart
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

class FakeSceneModeEffects implements SceneModeEffects {
  final List<SceneObject> objectAudioCalls = [];
  final List<SceneObject> promptFindCalls = [];
  final List<SystemPhrase> systemPhraseCalls = [];
  int roundCompletedCalls = 0;

  @override
  void playObjectAudio(SceneObject object) => objectAudioCalls.add(object);

  @override
  void promptFind(SceneObject target) => promptFindCalls.add(target);

  @override
  void playSystemPhrase(SystemPhrase phrase) => systemPhraseCalls.add(phrase);

  @override
  void onRoundCompleted() => roundCompletedCalls++;
}
```

- [ ] **Step 2: Write the failing test**

`test/domain/modes/explore_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/explore_mode.dart';

import '../../support/fake_scene_mode_effects.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const tree = SceneObject(id: 'tree', label: 'Дерево', audio: 'tree.mp3', rect: rect);

  test('activate() has no side effects', () {
    final effects = FakeSceneModeEffects();
    ExploreMode(effects: effects).activate();
    expect(effects.objectAudioCalls, isEmpty);
    expect(effects.promptFindCalls, isEmpty);
    expect(effects.systemPhraseCalls, isEmpty);
  });

  test('tapping an object plays its own audio', () {
    final effects = FakeSceneModeEffects();
    ExploreMode(effects: effects).onObjectTapped(tree);
    expect(effects.objectAudioCalls, [tree]);
  });
}
```

- [ ] **Step 3: Run the test to confirm it fails**

```bash
flutter test test/domain/modes/explore_mode_test.dart
```

Expected: FAIL — `explore_mode.dart` doesn't exist.

- [ ] **Step 4: Implement ExploreMode**

`lib/domain/modes/explore_mode.dart`:

```dart
import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// Tap any object, hear its name. No round to complete, no wrong answers.
class ExploreMode implements SceneMode {
  ExploreMode({required this.effects});

  final SceneModeEffects effects;

  @override
  void activate() {
    // Nothing to announce — the child explores at their own pace.
  }

  @override
  void onObjectTapped(SceneObject object) => effects.playObjectAudio(object);
}
```

- [ ] **Step 5: Run the test to confirm it passes**

```bash
flutter test test/domain/modes/explore_mode_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/modes/explore_mode.dart test/support/fake_scene_mode_effects.dart test/domain/modes/explore_mode_test.dart
git commit -m "feat: add ExploreMode"
```

---

## Task 5: FindMode

**Files:**
- Create: `lib/domain/modes/find_mode.dart`
- Test: `test/domain/modes/find_mode_test.dart`

**Interfaces:**
- Consumes: `SceneMode`, `SceneModeEffects`, `SystemPhrase` from Task 3; `SceneObject` from Task 2; `FakeSceneModeEffects` from Task 4.
- Produces: `class FindMode implements SceneMode { FindMode({required List<SceneObject> objects, required SceneModeEffects effects}); SceneObject? get currentTarget; }`. Consumed by Task 11's `SceneController`.

- [ ] **Step 1: Write the failing tests**

`test/domain/modes/find_mode_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/find_mode.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

import '../../support/fake_scene_mode_effects.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const ball = SceneObject(id: 'ball', label: 'Мяч', audio: 'ball.mp3', rect: rect);
  const cat = SceneObject(id: 'cat', label: 'Кот', audio: 'cat.mp3', rect: rect);
  const tree = SceneObject(id: 'tree', label: 'Дерево', audio: 'tree.mp3', rect: rect);
  final objects = [ball, cat, tree];

  test('activate() prompts the first object', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects)..activate();
    expect(mode.currentTarget, ball);
    expect(effects.promptFindCalls, [ball]);
  });

  test('wrong tap gives a hint and does not advance', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(cat);
    expect(effects.systemPhraseCalls, [SystemPhrase.wrongHint]);
    expect(mode.currentTarget, ball);
    expect(effects.promptFindCalls, [ball]); // no new prompt
  });

  test('correct tap on a non-final target advances to the next object', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(ball);
    expect(effects.systemPhraseCalls, [SystemPhrase.correct]);
    expect(mode.currentTarget, cat);
    expect(effects.promptFindCalls, [ball, cat]);
    expect(effects.roundCompletedCalls, 0);
  });

  test('finding the last object plays the fanfare and completes the round', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(ball);
    mode.onObjectTapped(cat);
    mode.onObjectTapped(tree);
    expect(
      effects.systemPhraseCalls,
      [SystemPhrase.correct, SystemPhrase.correct, SystemPhrase.correct, SystemPhrase.roundComplete],
    );
    expect(effects.roundCompletedCalls, 1);
    expect(mode.currentTarget, isNull);
  });

  test('taps after the round is complete are ignored', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(ball);
    mode.onObjectTapped(cat);
    mode.onObjectTapped(tree);
    effects.systemPhraseCalls.clear();
    mode.onObjectTapped(ball);
    expect(effects.systemPhraseCalls, isEmpty);
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/domain/modes/find_mode_test.dart
```

Expected: FAIL — `find_mode.dart` doesn't exist.

- [ ] **Step 3: Implement FindMode**

`lib/domain/modes/find_mode.dart`:

```dart
import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// The app asks for one object at a time, in the scene's own list order.
/// Only the current target registers as a correct tap, so found objects
/// are always exactly the objects before the current target's index — a
/// wrong tap never changes state, and there is no way to skip ahead.
class FindMode implements SceneMode {
  FindMode({required List<SceneObject> objects, required this.effects})
      : _objects = List.unmodifiable(objects) {
    assert(_objects.isNotEmpty, 'FindMode requires at least one object');
  }

  final List<SceneObject> _objects;
  final SceneModeEffects effects;

  int _targetIndex = 0;
  int _foundCount = 0;

  /// The object currently being searched for, or null once every object
  /// in the scene has been found.
  SceneObject? get currentTarget =>
      _foundCount == _objects.length ? null : _objects[_targetIndex];

  @override
  void activate() {
    _targetIndex = 0;
    _foundCount = 0;
    effects.promptFind(_objects[_targetIndex]);
  }

  @override
  void onObjectTapped(SceneObject object) {
    final target = currentTarget;
    if (target == null) return; // round already complete

    if (object != target) {
      effects.playSystemPhrase(SystemPhrase.wrongHint);
      return;
    }

    _foundCount++;
    effects.playSystemPhrase(SystemPhrase.correct);

    if (_foundCount == _objects.length) {
      effects.playSystemPhrase(SystemPhrase.roundComplete);
      effects.onRoundCompleted();
      return;
    }

    _targetIndex++;
    effects.promptFind(_objects[_targetIndex]);
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/domain/modes/find_mode_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/modes/find_mode.dart test/domain/modes/find_mode_test.dart
git commit -m "feat: add FindMode"
```

---

## Task 6: AudioSink and AudioPlayerService

**Files:**
- Create: `lib/audio/audio_sink.dart`, `lib/audio/audio_player_service.dart`

**Interfaces:**
- Consumes: `SystemPhrase` from Task 3.
- Produces: `abstract class AudioSink { Future<void> playFile(String absolutePath); Future<void> playSystemPhrase(SystemPhrase phrase); Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath); }`; `class AudioPlayerService implements AudioSink`. Consumed by Task 11 (`SceneController`) and Task 12 (`SceneScreen`'s default factory). Test fakes of `AudioSink` are written per-task where needed (Task 11).

`AudioPlayerService` wraps `audioplayers`, which talks to platform channels — it cannot run under plain `flutter test` (no platform binding), so per spec §5 it is exercised only by manual on-device verification (Task 15), not unit tests. `AudioSink` exists precisely so every *other* class can be unit-tested against a fake instead.

- [ ] **Step 1: Add the `audioplayers` dependency check**

Already present in `pubspec.yaml` from Task 1 (`audioplayers: ^6.8.1`). Run `flutter pub get` if it hasn't been run since.

- [ ] **Step 2: Write the interface**

`lib/audio/audio_sink.dart`:

```dart
import '../domain/modes/scene_mode_effects.dart';

/// The audio-playing seam `SceneController` depends on, instead of the
/// concrete `audioplayers`-backed `AudioPlayerService` — lets tests inject
/// a fake with no platform channel involved.
abstract class AudioSink {
  /// Play a locally cached audio file (a scene object's recorded name).
  Future<void> playFile(String absolutePath);

  /// Play a bundled system phrase asset.
  Future<void> playSystemPhrase(SystemPhrase phrase);

  /// Play a system phrase, wait for it to finish, then play the object
  /// audio file — used for Find mode's "Find: <name>" prompt.
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath);
}
```

- [ ] **Step 3: Implement AudioPlayerService**

`lib/audio/audio_player_service.dart`:

```dart
import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';
import '../domain/modes/scene_mode_effects.dart';
import 'audio_sink.dart';

const Map<SystemPhrase, String> _systemPhraseAssets = {
  SystemPhrase.findIntro: 'audio/system/find_intro.wav',
  SystemPhrase.wrongHint: 'audio/system/wrong_hint.wav',
  SystemPhrase.correct: 'audio/system/correct.wav',
  SystemPhrase.roundComplete: 'audio/system/round_complete.wav',
};

/// Thin `audioplayers` wrapper. Playback errors are logged and swallowed —
/// per spec, sound must never block gameplay.
class AudioPlayerService implements AudioSink {
  AudioPlayerService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> playFile(String absolutePath) => _playSafely(DeviceFileSource(absolutePath));

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) =>
      _playSafely(AssetSource(_systemPhraseAssets[phrase]!));

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async {
    await _playAndWait(AssetSource(_systemPhraseAssets[phrase]!));
    await _playSafely(DeviceFileSource(objectAudioPath));
  }

  Future<void> _playSafely(Source source) async {
    try {
      await _player.play(source);
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _playAndWait(Source source) async {
    try {
      final completed = _player.onPlayerComplete.first;
      await _player.play(source);
      await completed;
    } catch (error, stackTrace) {
      developer.log('Audio playback failed', name: 'AudioPlayerService', error: error, stackTrace: stackTrace);
    }
  }

  void dispose() => _player.dispose();
}
```

- [ ] **Step 4: Verify it compiles**

```bash
flutter analyze lib/audio/
```

Expected: "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/audio
git commit -m "feat: add AudioSink and AudioPlayerService"
```

---

## Task 7: Placeholder asset generator and demo/system audio assets

**Files:**
- Create: `tool/src/placeholder_png.dart`, `tool/src/placeholder_wav.dart`, `tool/generate_placeholder_assets.dart`
- Create (generated, committed as binary fixtures): `assets/audio/system/find_intro.wav`, `wrong_hint.wav`, `correct.wav`, `round_complete.wav`; `assets/demo_content/demo/scene.json`, `background.png`, `thumb.png`, `ball.wav`, `cat.wav`, `tree.wav`, `sun.wav`
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `Uint8List buildPlaceholderPng({required int width, required int height, required List<int> backgroundRgb, required List<PlaceholderMarker> markers})` and `Uint8List buildSilentWav({double seconds, int sampleRate})`, both pure-Dart with no external tool dependency. `test/support/fixture_assets.dart` (Task 12) imports `tool/src/placeholder_png.dart` to build test fixtures. The demo scene's id is `demo`; its 4 objects are `ball`, `cat`, `tree`, `sun`.

These are placeholder art/audio (solid-color shapes, silence) generated entirely by code — not a description of what to do, but a working generator producing real files, so `flutter run` shows something real end-to-end before real hosted content exists.

- [ ] **Step 1: Write the pure-Dart PNG encoder**

`tool/src/placeholder_png.dart`:

```dart
import 'dart:io';
import 'dart:typed_data';

class PlaceholderMarker {
  const PlaceholderMarker({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rgb,
  });

  final double x, y, width, height;
  final List<int> rgb;
}

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _chunk(String type, List<int> data) {
  final out = BytesBuilder();
  out.add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List());
  final typeAndData = [...type.codeUnits, ...data];
  out.add(typeAndData.sublist(0, type.length));
  out.add(data);
  out.add((ByteData(4)..setUint32(0, _crc32(typeAndData))).buffer.asUint8List());
  return out.toBytes();
}

/// Builds a minimal, valid, uncompressed-filter 8-bit RGB PNG: a solid
/// background with rectangular "marker" regions — enough to visually and
/// programmatically stand in for real scene art in demos and tests.
Uint8List buildPlaceholderPng({
  required int width,
  required int height,
  required List<int> backgroundRgb,
  List<PlaceholderMarker> markers = const [],
}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter type: None
    for (var x = 0; x < width; x++) {
      var rgb = backgroundRgb;
      for (final m in markers) {
        final mx0 = (m.x * width).round();
        final my0 = (m.y * height).round();
        final mx1 = mx0 + (m.width * width).round();
        final my1 = my0 + (m.height * height).round();
        if (x >= mx0 && x < mx1 && y >= my0 && y < my1) {
          rgb = m.rgb;
          break;
        }
      }
      raw.add(rgb);
    }
  }
  final compressed = const ZLibEncoder(level: 6).encode(raw.toBytes());

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // color type: RGB
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  out.add(_chunk('IHDR', ihdr.buffer.asUint8List()));
  out.add(_chunk('IDAT', compressed));
  out.add(_chunk('IEND', const []));
  return out.toBytes();
}
```

- [ ] **Step 2: Write the silent WAV encoder**

`tool/src/placeholder_wav.dart`:

```dart
import 'dart:typed_data';

/// Builds a minimal, valid, silent 16-bit mono PCM WAV — a placeholder
/// stand-in for a recorded name/phrase, wherever real audio isn't
/// available yet.
Uint8List buildSilentWav({double seconds = 0.4, int sampleRate = 8000}) {
  final numSamples = (sampleRate * seconds).round();
  final dataSize = numSamples * 2;
  final b = BytesBuilder();

  void writeString(String s) => b.add(s.codeUnits);
  void writeUint32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void writeUint16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(sampleRate);
  writeUint32(sampleRate * 2);
  writeUint16(2);
  writeUint16(16);
  writeString('data');
  writeUint32(dataSize);
  b.add(List<int>.filled(dataSize, 0));
  return b.toBytes();
}
```

- [ ] **Step 3: Write the generator script**

`tool/generate_placeholder_assets.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'src/placeholder_png.dart';
import 'src/placeholder_wav.dart';

const _demoMarkers = [
  PlaceholderMarker(x: 0.10, y: 0.65, width: 0.15, height: 0.20, rgb: [220, 50, 50]), // ball
  PlaceholderMarker(x: 0.35, y: 0.55, width: 0.18, height: 0.30, rgb: [230, 140, 40]), // cat
  PlaceholderMarker(x: 0.60, y: 0.30, width: 0.20, height: 0.55, rgb: [40, 150, 70]), // tree
  PlaceholderMarker(x: 0.75, y: 0.05, width: 0.15, height: 0.15, rgb: [250, 210, 60]), // sun
];

const _demoSceneJson = '''
{
  "id": "demo",
  "version": 1,
  "title": "Демо",
  "minAgeMonths": 12,
  "background": "background.png",
  "objects": [
    {"id": "ball", "label": "Мяч", "audio": "ball.wav", "rect": {"x": 0.10, "y": 0.65, "width": 0.15, "height": 0.20}},
    {"id": "cat", "label": "Кот", "audio": "cat.wav", "rect": {"x": 0.35, "y": 0.55, "width": 0.18, "height": 0.30}},
    {"id": "tree", "label": "Дерево", "audio": "tree.wav", "rect": {"x": 0.60, "y": 0.30, "width": 0.20, "height": 0.55}},
    {"id": "sun", "label": "Солнце", "audio": "sun.wav", "rect": {"x": 0.75, "y": 0.05, "width": 0.15, "height": 0.15}}
  ]
}
''';

Future<void> _write(String path, List<int> bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  stdout.writeln('wrote $path (${bytes.length} bytes)');
}

Future<void> main() async {
  for (final name in ['find_intro', 'wrong_hint', 'correct', 'round_complete']) {
    await _write('assets/audio/system/$name.wav', buildSilentWav());
  }

  await _write('assets/demo_content/demo/scene.json', utf8.encode(_demoSceneJson));
  await _write(
    'assets/demo_content/demo/background.png',
    buildPlaceholderPng(width: 800, height: 600, backgroundRgb: const [150, 200, 240], markers: _demoMarkers),
  );
  await _write(
    'assets/demo_content/demo/thumb.png',
    buildPlaceholderPng(width: 200, height: 150, backgroundRgb: const [150, 200, 240], markers: _demoMarkers),
  );
  for (final name in ['ball', 'cat', 'tree', 'sun']) {
    await _write('assets/demo_content/demo/$name.wav', buildSilentWav());
  }
}
```

- [ ] **Step 4: Run the generator**

```bash
dart run tool/generate_placeholder_assets.dart
```

Expected: 10 "wrote ..." lines, each with a non-zero byte count.

- [ ] **Step 5: Add the asset directories to `pubspec.yaml`**

Under the existing `flutter:` key:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/audio/system/
    - assets/demo_content/demo/
```

- [ ] **Step 6: Verify the assets load**

```bash
flutter pub get
flutter analyze
```

Expected: no errors (asset directories now exist and are listed).

- [ ] **Step 7: Commit**

```bash
git add tool assets pubspec.yaml
git commit -m "feat: add placeholder asset generator, demo scene, and system audio"
```

---

## Task 8: ContentRepository — local cache reading

**Files:**
- Create: `lib/data/cached_scene.dart`, `lib/data/content_repository.dart`
- Test: `test/data/content_repository_test.dart`

**Interfaces:**
- Consumes: `Scene`, `SceneObject` from Task 2.
- Produces: `class CachedSceneSummary { final String id, title, thumbnailPath; }`; `class CachedScene { final Scene scene; final String directoryPath; String get backgroundPath; String audioPathFor(SceneObject object); }`; `class ContentRepository { static const cacheSubdirName = 'content_cache'; ContentRepository({required http.Client httpClient, required Uri baseUrl, required Future<Directory> Function() cacheRootProvider}); Future<List<CachedSceneSummary>> loadCachedIndex(); Future<CachedScene?> loadScene(String sceneId); }` (constructor also used, unmodified, by Task 9, which adds `refresh()` to this same class). Consumed by Tasks 10, 12, 13, 14, 15.

- [ ] **Step 1: Write the failing tests**

`test/data/content_repository_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';

Future<Directory> _tempCacheRoot() => Directory.systemTemp.createTemp('yandee_repo_test_');

Future<void> _seedScene(
  Directory cacheRoot,
  String id, {
  required int version,
  required String title,
}) async {
  final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, id));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': id,
    'version': version,
    'title': title,
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': <Map<String, dynamic>>[],
  }));
  await File(p.join(dir.path, 'thumb.png')).writeAsBytes([1, 2, 3]);
}

void main() {
  late Directory cacheRoot;
  late ContentRepository repository;

  setUp(() async {
    cacheRoot = await _tempCacheRoot();
    repository = ContentRepository(
      httpClient: http.Client(),
      baseUrl: Uri.parse('https://example.invalid/v1/'),
      cacheRootProvider: () async => cacheRoot,
    );
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('loadCachedIndex on an empty cache returns an empty list', () async {
    expect(await repository.loadCachedIndex(), isEmpty);
  });

  test('loadCachedIndex lists cached scenes sorted by title', () async {
    await _seedScene(cacheRoot, 'farm', version: 1, title: 'Ферма');
    await _seedScene(cacheRoot, 'city', version: 3, title: 'Город');

    final index = await repository.loadCachedIndex();

    expect(index.map((e) => e.id), ['city', 'farm']); // 'Город' < 'Ферма'
  });

  test('loadCachedIndex ignores __tmp directories and dirs without scene.json', () async {
    await _seedScene(cacheRoot, 'city', version: 1, title: 'Город');
    await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'city__tmp'))
        .create(recursive: true);
    await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'empty')).create(recursive: true);

    final index = await repository.loadCachedIndex();

    expect(index.map((e) => e.id), ['city']);
  });

  test('loadCachedIndex skips a scene with corrupted scene.json', () async {
    final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'broken'));
    await dir.create(recursive: true);
    await File(p.join(dir.path, 'scene.json')).writeAsString('not json');

    expect(await repository.loadCachedIndex(), isEmpty);
  });

  test('loadScene returns null when the scene is not cached', () async {
    expect(await repository.loadScene('missing'), isNull);
  });

  test('loadScene returns the parsed scene and resolvable paths', () async {
    await _seedScene(cacheRoot, 'city', version: 3, title: 'Город');

    final cached = await repository.loadScene('city');

    expect(cached, isNotNull);
    expect(cached!.scene.id, 'city');
    expect(cached.scene.version, 3);
    expect(cached.backgroundPath, p.join(cached.directoryPath, 'background.png'));
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/data/content_repository_test.dart
```

Expected: FAIL — `content_repository.dart` doesn't exist.

- [ ] **Step 3: Implement CachedScene and the read side of ContentRepository**

`lib/data/cached_scene.dart`:

```dart
import 'package:path/path.dart' as p;
import '../domain/models/scene.dart';
import '../domain/models/scene_object.dart';

/// A summary row for `SceneListScreen` — everything needed to render a
/// card without parsing the full `scene.json`.
class CachedSceneSummary {
  const CachedSceneSummary({required this.id, required this.title, required this.thumbnailPath});

  final String id;
  final String title;
  final String thumbnailPath;
}

/// A fully-cached scene plus the local directory its files live in, so
/// callers never need to know the cache's on-disk layout.
class CachedScene {
  const CachedScene({required this.scene, required this.directoryPath});

  final Scene scene;
  final String directoryPath;

  String get backgroundPath => p.join(directoryPath, scene.background);

  String audioPathFor(SceneObject object) => p.join(directoryPath, object.audio);
}
```

`lib/data/content_repository.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../domain/models/scene.dart';
import 'cached_scene.dart';

/// Reads and writes the local scene cache, and (from Task 9's `refresh()`)
/// syncs it from static hosting. The UI only ever reads through
/// `loadCachedIndex`/`loadScene` — `refresh()` is the sole network path,
/// and it never throws: every failure just means "try again next time".
class ContentRepository {
  ContentRepository({
    required http.Client httpClient,
    required Uri baseUrl,
    required Future<Directory> Function() cacheRootProvider,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl,
        _cacheRootProvider = cacheRootProvider,
        assert(baseUrl.path.endsWith('/'), 'baseUrl must end with / so Uri.resolve keeps the full path');

  static const cacheSubdirName = 'content_cache';

  final http.Client _httpClient;
  final Uri _baseUrl;
  final Future<Directory> Function() _cacheRootProvider;

  Future<Directory> _cacheRoot() async {
    final dir = Directory(p.join((await _cacheRootProvider()).path, cacheSubdirName));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Scenes available right now, without touching the network, sorted by
  /// title for a stable list order.
  Future<List<CachedSceneSummary>> loadCachedIndex() async {
    final root = await _cacheRoot();
    final summaries = <CachedSceneSummary>[];
    await for (final entry in root.list()) {
      if (entry is! Directory || entry.path.endsWith('__tmp')) continue;
      final scene = await _readSceneJson(entry);
      if (scene == null) continue;
      summaries.add(CachedSceneSummary(
        id: scene.id,
        title: scene.title,
        thumbnailPath: p.join(entry.path, 'thumb.png'),
      ));
    }
    summaries.sort((a, b) => a.title.compareTo(b.title));
    return summaries;
  }

  /// Loads a scene `loadCachedIndex` reported as available. Returns null
  /// if it isn't (or is no longer) cached.
  Future<CachedScene?> loadScene(String sceneId) async {
    final root = await _cacheRoot();
    final dir = Directory(p.join(root.path, sceneId));
    final scene = await _readSceneJson(dir);
    if (scene == null) return null;
    return CachedScene(scene: scene, directoryPath: dir.path);
  }

  Future<Scene?> _readSceneJson(Directory sceneDir) async {
    final file = File(p.join(sceneDir.path, 'scene.json'));
    if (!await file.exists()) return null;
    try {
      return Scene.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupted cache entry: skip it, refresh() will re-download it
    }
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/data/content_repository_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/cached_scene.dart lib/data/content_repository.dart test/data/content_repository_test.dart
git commit -m "feat: add ContentRepository local cache reading"
```

---

## Task 9: ContentRepository — sync from hosting

**Files:**
- Modify: `lib/data/content_repository.dart`
- Test: `test/data/content_repository_test.dart` (append)

**Interfaces:**
- Consumes: `SceneManifestEntry` from Task 2; `http.testing.MockClient` (dev dependency of `http`, no new package needed).
- Produces: adds `Future<void> refresh()` to `ContentRepository` (constructor/read API unchanged from Task 8). Consumed by Tasks 14 (`SceneListScreen`) and 15 (`main.dart`).

The hosting URL convention: `{baseUrl}index.json` lists scenes; each scene's own files (`scene.json`, its `background`, each object's `audio`) live under `{baseUrl}{sceneId}/`; a `SceneManifestEntry.thumbnail` path is already root-relative (spec example: `"city/thumb.png"`) — unlike `Scene`'s own fields, it must **not** be prefixed with the scene id again.

- [ ] **Step 1: Append the failing tests**

Add to `test/data/content_repository_test.dart` (new imports at top: `import 'package:http/testing.dart';`):

```dart
void main() {
  // ... existing setUp/tearDown/tests above ...

  group('refresh', () {
    test('network failure leaves the cache untouched and does not throw', () async {
      await _seedScene(cacheRoot, 'city', version: 1, title: 'Город');
      final client = MockClient((request) async => throw const SocketException('offline'));
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      final index = await repo.loadCachedIndex();
      expect(index.map((e) => e.id), ['city']);
    });

    test('a scene already at the remote version is not re-downloaded', () async {
      await _seedScene(cacheRoot, 'city', version: 3, title: 'Город');
      var sceneJsonRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/v1/index.json') {
          return http.Response(
            jsonEncode({
              'scenesVersion': 3,
              'scenes': [
                {'id': 'city', 'version': 3, 'title': 'Город', 'thumbnail': 'city/thumb.png'},
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/v1/city/scene.json') sceneJsonRequests++;
        return http.Response('not found', 404);
      });
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      expect(sceneJsonRequests, 0);
    });

    test('a newer remote version is downloaded and swapped in atomically', () async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/index.json') {
          return http.Response(
            jsonEncode({
              'scenesVersion': 2,
              'scenes': [
                {'id': 'city', 'version': 2, 'title': 'Город', 'thumbnail': 'city/thumb.png'},
              ],
            }),
            200,
          );
        }
        if (path == '/v1/city/scene.json') {
          return http.Response(
            jsonEncode({
              'id': 'city',
              'version': 2,
              'title': 'Город',
              'minAgeMonths': 12,
              'background': 'background.png',
              'objects': <Map<String, dynamic>>[
                {
                  'id': 'tree',
                  'label': 'Дерево',
                  'audio': 'tree.mp3',
                  'rect': {'x': 0.0, 'y': 0.0, 'width': 0.1, 'height': 0.1},
                },
              ],
            }),
            200,
          );
        }
        if (path == '/v1/city/background.png') return http.Response.bytes([1, 2, 3], 200);
        if (path == '/v1/city/thumb.png') return http.Response.bytes([4, 5], 200);
        if (path == '/v1/city/tree.mp3') return http.Response.bytes([6, 7], 200);
        return http.Response('not found', 404);
      });
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      final cached = await repo.loadScene('city');
      expect(cached, isNotNull);
      expect(cached!.scene.version, 2);
      expect(await File(cached.backgroundPath).exists(), isTrue);
      expect(await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'city__tmp')).exists(), isFalse);
    });

    test('a failed asset download leaves a previously cached scene untouched', () async {
      await _seedScene(cacheRoot, 'city', version: 1, title: 'Город');
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/v1/index.json') {
          return http.Response(
            jsonEncode({
              'scenesVersion': 2,
              'scenes': [
                {'id': 'city', 'version': 2, 'title': 'Город', 'thumbnail': 'city/thumb.png'},
              ],
            }),
            200,
          );
        }
        if (path == '/v1/city/scene.json') {
          return http.Response(
            jsonEncode({
              'id': 'city',
              'version': 2,
              'title': 'Город',
              'minAgeMonths': 12,
              'background': 'background.png',
              'objects': <Map<String, dynamic>>[],
            }),
            200,
          );
        }
        // background.png/thumb.png missing on the server -> 404
        return http.Response('not found', 404);
      });
      final repo = ContentRepository(
        httpClient: client,
        baseUrl: Uri.parse('https://example.invalid/v1/'),
        cacheRootProvider: () async => cacheRoot,
      );

      await repo.refresh();

      final cached = await repo.loadScene('city');
      expect(cached!.scene.version, 1); // unchanged
      expect(await Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'city__tmp')).exists(), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/data/content_repository_test.dart
```

Expected: FAIL — `refresh()` doesn't exist yet.

- [ ] **Step 3: Implement `refresh()`**

Add to `lib/data/content_repository.dart` (new imports: `import '../domain/models/scene_manifest_entry.dart';`), inside the `ContentRepository` class:

```dart
  /// Fetches the remote index, downloads any new or updated scenes, and
  /// atomically swaps each one in only once fully downloaded. Never
  /// throws — any failure just means "try again on the next refresh()".
  Future<void> refresh() async {
    final List<SceneManifestEntry> remoteEntries;
    try {
      final response = await _httpClient.get(_baseUrl.resolve('index.json'));
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      remoteEntries = (decoded['scenes'] as List<dynamic>)
          .map((e) => SceneManifestEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return; // offline or unreachable: keep serving whatever is cached
    }

    final root = await _cacheRoot();
    for (final entry in remoteEntries) {
      final localVersion = (await _readSceneJson(Directory(p.join(root.path, entry.id))))?.version;
      if (localVersion != null && localVersion >= entry.version) continue;
      await _downloadScene(root, entry);
    }
  }

  Future<void> _downloadScene(Directory root, SceneManifestEntry entry) async {
    final tmpDir = Directory(p.join(root.path, '${entry.id}__tmp'));
    try {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      await tmpDir.create(recursive: true);

      final sceneBytes = await _downloadBytes('${entry.id}/scene.json');
      final scene = Scene.fromJson(jsonDecode(utf8.decode(sceneBytes)) as Map<String, dynamic>);
      await File(p.join(tmpDir.path, 'scene.json')).writeAsBytes(sceneBytes);

      await File(p.join(tmpDir.path, scene.background))
          .writeAsBytes(await _downloadBytes('${entry.id}/${scene.background}'));

      // entry.thumbnail is already root-relative (e.g. "city/thumb.png");
      // it is stored locally under the fixed name "thumb.png", which is
      // what loadCachedIndex() expects regardless of the remote path.
      await File(p.join(tmpDir.path, 'thumb.png')).writeAsBytes(await _downloadBytes(entry.thumbnail));

      for (final object in scene.objects) {
        await File(p.join(tmpDir.path, object.audio))
            .writeAsBytes(await _downloadBytes('${entry.id}/${object.audio}'));
      }

      final finalDir = Directory(p.join(root.path, entry.id));
      if (await finalDir.exists()) await finalDir.delete(recursive: true);
      await tmpDir.rename(finalDir.path);
    } catch (_) {
      if (await tmpDir.exists()) await tmpDir.delete(recursive: true);
      // Leave any previously cached version of this scene untouched; the
      // next refresh() call will retry.
    }
  }

  Future<List<int>> _downloadBytes(String relativePath) async {
    final response = await _httpClient.get(_baseUrl.resolve(relativePath));
    if (response.statusCode != 200) {
      throw HttpException('GET $relativePath -> ${response.statusCode}');
    }
    return response.bodyBytes;
  }
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/data/content_repository_test.dart
```

Expected: PASS (10 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/content_repository.dart test/data/content_repository_test.dart
git commit -m "feat: sync ContentRepository cache from hosting"
```

---

## Task 10: DemoContentSeeder

**Files:**
- Create: `lib/data/demo_content_seeder.dart`
- Test: `test/data/demo_content_seeder_test.dart`

**Interfaces:**
- Consumes: `ContentRepository.cacheSubdirName` from Task 8.
- Produces: `class DemoContentSeeder { const DemoContentSeeder(); Future<void> seedIfEmpty(Directory cacheRoot); }`. Consumed by Task 15 (`main.dart`).

- [ ] **Step 1: Write the failing tests**

`test/data/demo_content_seeder_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/data/demo_content_seeder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheRoot;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('yandee_seeder_test_');
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('seeds the bundled demo scene into an empty cache', () async {
    await const DemoContentSeeder().seedIfEmpty(cacheRoot);

    final demoDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
    expect(await File(p.join(demoDir.path, 'scene.json')).exists(), isTrue);
    expect(await File(p.join(demoDir.path, 'background.png')).exists(), isTrue);
    expect(await File(p.join(demoDir.path, 'thumb.png')).exists(), isTrue);
    for (final name in ['ball', 'cat', 'tree', 'sun']) {
      expect(await File(p.join(demoDir.path, '$name.wav')).exists(), isTrue);
    }
  });

  test('does nothing if the cache already has a scene', () async {
    final otherDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'other'));
    await otherDir.create(recursive: true);
    await File(p.join(otherDir.path, 'scene.json')).writeAsString('{}');

    await const DemoContentSeeder().seedIfEmpty(cacheRoot);

    final demoDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
    expect(await demoDir.exists(), isFalse);
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/data/demo_content_seeder_test.dart
```

Expected: FAIL — `demo_content_seeder.dart` doesn't exist.

- [ ] **Step 3: Implement DemoContentSeeder**

`lib/data/demo_content_seeder.dart`:

```dart
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'content_repository.dart';

/// Copies the bundled placeholder demo scene into the content cache the
/// first time the app runs with an empty cache, so there is something to
/// see and tap before any real hosted content has been published. Once
/// real content exists, `ContentRepository.refresh` naturally replaces it
/// (a real scene's higher `version` wins) — no special-casing needed.
class DemoContentSeeder {
  const DemoContentSeeder();

  static const _bundleDir = 'assets/demo_content/demo';
  static const _sceneFiles = [
    'scene.json',
    'background.png',
    'thumb.png',
    'ball.wav',
    'cat.wav',
    'tree.wav',
    'sun.wav',
  ];

  Future<void> seedIfEmpty(Directory cacheRoot) async {
    final contentCacheDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName));
    if (await contentCacheDir.exists()) {
      final hasAnyScene = await contentCacheDir.list().any((e) => e is Directory);
      if (hasAnyScene) return;
    }

    final targetDir = Directory(p.join(contentCacheDir.path, 'demo'));
    await targetDir.create(recursive: true);
    for (final fileName in _sceneFiles) {
      final data = await rootBundle.load('$_bundleDir/$fileName');
      await File(p.join(targetDir.path, fileName))
          .writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/data/demo_content_seeder_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/demo_content_seeder.dart test/data/demo_content_seeder_test.dart
git commit -m "feat: add DemoContentSeeder"
```

---

## Task 11: SceneController

**Files:**
- Create: `lib/presentation/controllers/scene_controller.dart`, `test/support/fake_audio_sink.dart`
- Test: `test/presentation/controllers/scene_controller_test.dart`

**Interfaces:**
- Consumes: `AudioSink` from Task 6; `SceneMode`, `SceneModeEffects`, `SystemPhrase` from Task 3; `ExploreMode`, `FindMode` from Tasks 4–5; `CachedScene` from Task 8.
- Produces: `enum SceneModeType { explore, find }`; `class SceneController extends ChangeNotifier implements SceneModeEffects { SceneController({required CachedScene cachedScene, required AudioSink audioSink, Duration congratsDuration = const Duration(seconds: 2)}); SceneModeType get modeType; bool get showCongrats; SceneObject? get currentFindTarget; void setMode(SceneModeType type); void onObjectTapped(SceneObject object); }`. Consumed by Tasks 12–14 (screens/widgets).

- [ ] **Step 1: Write the fake AudioSink test double**

`test/support/fake_audio_sink.dart`:

```dart
import 'package:yandee/audio/audio_sink.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

class FakeAudioSink implements AudioSink {
  final List<String> playedFiles = [];
  final List<SystemPhrase> playedSystemPhrases = [];
  final List<(SystemPhrase, String)> playedSequences = [];

  @override
  Future<void> playFile(String absolutePath) async => playedFiles.add(absolutePath);

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) async => playedSystemPhrases.add(phrase);

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async =>
      playedSequences.add((phrase, objectAudioPath));
}
```

- [ ] **Step 2: Write the failing tests**

`test/presentation/controllers/scene_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/data/cached_scene.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';
import 'package:yandee/presentation/controllers/scene_controller.dart';

import '../../support/fake_audio_sink.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const ball = SceneObject(id: 'ball', label: 'Мяч', audio: 'ball.wav', rect: rect);
  const cat = SceneObject(id: 'cat', label: 'Кот', audio: 'cat.wav', rect: rect);
  final cachedScene = CachedScene(
    scene: Scene(
      id: 'demo',
      version: 1,
      title: 'Демо',
      minAgeMonths: 12,
      background: 'background.png',
      objects: [ball, cat],
    ),
    directoryPath: '/cache/demo',
  );

  test('starts in explore mode with no find target', () {
    final controller = SceneController(cachedScene: cachedScene, audioSink: FakeAudioSink());
    expect(controller.modeType, SceneModeType.explore);
    expect(controller.currentFindTarget, isNull);
  });

  test('explore mode: tapping an object plays its file', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    controller.onObjectTapped(ball);
    expect(audio.playedFiles, [cachedScene.audioPathFor(ball)]);
  });

  test('switching to find mode prompts the first object', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    controller.setMode(SceneModeType.find);
    expect(controller.modeType, SceneModeType.find);
    expect(controller.currentFindTarget, ball);
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);
  });

  test('completing a find round shows congrats then reverts to explore', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      congratsDuration: const Duration(milliseconds: 5),
    );
    controller.setMode(SceneModeType.find);
    controller.onObjectTapped(ball);
    controller.onObjectTapped(cat);

    expect(controller.showCongrats, isTrue);
    expect(audio.playedSystemPhrases, contains(SystemPhrase.roundComplete));

    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.showCongrats, isFalse);
    expect(controller.modeType, SceneModeType.explore);
  });

  test('setMode with the current type is a no-op', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.setMode(SceneModeType.explore);
    expect(notifications, 0);
  });
}
```

- [ ] **Step 3: Run the tests to confirm they fail**

```bash
flutter test test/presentation/controllers/scene_controller_test.dart
```

Expected: FAIL — `scene_controller.dart` doesn't exist.

- [ ] **Step 4: Implement SceneController**

`lib/presentation/controllers/scene_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/audio_sink.dart';
import '../../data/cached_scene.dart';
import '../../domain/models/scene_object.dart';
import '../../domain/modes/explore_mode.dart';
import '../../domain/modes/find_mode.dart';
import '../../domain/modes/scene_mode.dart';
import '../../domain/modes/scene_mode_effects.dart';

enum SceneModeType { explore, find }

/// Owns the active [SceneMode] for one open scene, and is where mode
/// switching, audio dispatch, and the Find-round congratulations timing
/// live — none of which belongs inside `SceneMode` itself, so future modes
/// get all of it for free.
class SceneController extends ChangeNotifier implements SceneModeEffects {
  SceneController({
    required this.cachedScene,
    required AudioSink audioSink,
    this.congratsDuration = const Duration(seconds: 2),
  }) : _audio = audioSink {
    _mode = ExploreMode(effects: this)..activate();
  }

  final CachedScene cachedScene;
  final Duration congratsDuration;
  final AudioSink _audio;

  late SceneMode _mode;
  SceneModeType _modeType = SceneModeType.explore;
  bool _showCongrats = false;
  Timer? _congratsTimer;

  SceneModeType get modeType => _modeType;
  bool get showCongrats => _showCongrats;

  SceneObject? get currentFindTarget => _mode is FindMode ? (_mode as FindMode).currentTarget : null;

  void setMode(SceneModeType type) {
    if (type == _modeType) return;
    _congratsTimer?.cancel();
    _showCongrats = false;
    _modeType = type;
    _mode = type == SceneModeType.explore
        ? ExploreMode(effects: this)
        : FindMode(objects: cachedScene.scene.objects, effects: this);
    _mode.activate();
    notifyListeners();
  }

  void onObjectTapped(SceneObject object) => _mode.onObjectTapped(object);

  @override
  void playObjectAudio(SceneObject object) {
    unawaited(_audio.playFile(cachedScene.audioPathFor(object)));
  }

  @override
  void promptFind(SceneObject target) {
    unawaited(_audio.playSystemPhraseThenFile(SystemPhrase.findIntro, cachedScene.audioPathFor(target)));
    notifyListeners();
  }

  @override
  void playSystemPhrase(SystemPhrase phrase) {
    unawaited(_audio.playSystemPhrase(phrase));
  }

  @override
  void onRoundCompleted() {
    _showCongrats = true;
    notifyListeners();
    _congratsTimer = Timer(congratsDuration, () => setMode(SceneModeType.explore));
  }

  @override
  void dispose() {
    _congratsTimer?.cancel();
    super.dispose();
  }
}
```

- [ ] **Step 5: Run the tests to confirm they pass**

```bash
flutter test test/presentation/controllers/scene_controller_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/controllers test/support/fake_audio_sink.dart test/presentation/controllers
git commit -m "feat: add SceneController"
```

---

## Task 12: SceneIllustration (background + tap zones)

**Files:**
- Create: `lib/presentation/widgets/scene_illustration.dart`, `test/support/fixture_assets.dart`
- Test: `test/presentation/widgets/scene_illustration_test.dart`

**Interfaces:**
- Consumes: `CachedScene` from Task 8; `SceneController` from Task 11 (via `provider`'s `context.watch`); `buildPlaceholderPng` from Task 7 (test-only, via `test/support/fixture_assets.dart`).
- Produces: `class SceneIllustration extends StatefulWidget { const SceneIllustration({required CachedScene cachedScene}); }`. Renders each object's tap zone with `Key(ValueKey('object_zone_${object.id}'))`. Consumed by Task 13.

The background's on-screen aspect ratio is preserved (no cropping/stretching) by sizing an `AspectRatio` to the image's real decoded dimensions, so normalized `rect` coordinates always map onto exactly the rendered image — including on screens with a different aspect ratio than the art.

- [ ] **Step 1: Write the fixture PNG helper**

`test/support/fixture_assets.dart`:

```dart
import 'dart:io';

import '../../tool/src/placeholder_png.dart';

/// Writes a fixture PNG with a known, non-square size (to catch aspect
/// ratio bugs) into [dir] under [fileName].
Future<File> writeFixturePng(Directory dir, String fileName, {int width = 400, int height = 300}) async {
  final bytes = buildPlaceholderPng(width: width, height: height, backgroundRgb: const [150, 200, 240]);
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file;
}
```

- [ ] **Step 2: Write the failing widget test**

`test/presentation/widgets/scene_illustration_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yandee/data/cached_scene.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/presentation/controllers/scene_controller.dart';
import 'package:yandee/presentation/widgets/scene_illustration.dart';

import '../../support/fake_audio_sink.dart';
import '../../support/fixture_assets.dart';

void main() {
  // Container is 800x800; a 400x300 (4:3) image inside it renders at
  // 800x600, letterboxed with 100px top/bottom margins.
  const ball = SceneObject(
    id: 'ball',
    label: 'Мяч',
    audio: 'ball.wav',
    rect: ObjectRect(x: 0.25, y: 0.5, width: 0.1, height: 0.2),
  );

  testWidgets('positions a tap zone at the object rect and dispatches taps', (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('yandee_illustration_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    await writeFixturePng(tempDir, 'background.png', width: 400, height: 300);

    final cachedScene = CachedScene(
      scene: Scene(
        id: 'demo',
        version: 1,
        title: 'Демо',
        minAgeMonths: 12,
        background: 'background.png',
        objects: [ball],
      ),
      directoryPath: tempDir.path,
    );
    final audio = FakeAudioSink();

    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 800,
        height: 800,
        child: ChangeNotifierProvider(
          create: (_) => SceneController(cachedScene: cachedScene, audioSink: audio),
          child: SceneIllustration(cachedScene: cachedScene),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final zoneFinder = find.byKey(const ValueKey('object_zone_ball'));
    expect(zoneFinder, findsOneWidget);

    final topLeft = tester.getTopLeft(zoneFinder);
    final size = tester.getSize(zoneFinder);
    expect(topLeft.dx, moreOrLessEquals(0.25 * 800));
    expect(topLeft.dy, moreOrLessEquals(100 + 0.5 * 600));
    expect(size.width, moreOrLessEquals(0.1 * 800));
    expect(size.height, moreOrLessEquals(0.2 * 600));

    await tester.tap(zoneFinder);
    await tester.pump();
    expect(audio.playedFiles, [cachedScene.audioPathFor(ball)]);
  });
}
```

- [ ] **Step 3: Run the test to confirm it fails**

```bash
flutter test test/presentation/widgets/scene_illustration_test.dart
```

Expected: FAIL — `scene_illustration.dart` doesn't exist.

- [ ] **Step 4: Implement SceneIllustration**

`lib/presentation/widgets/scene_illustration.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/cached_scene.dart';
import '../controllers/scene_controller.dart';

class SceneIllustration extends StatefulWidget {
  const SceneIllustration({super.key, required this.cachedScene});

  final CachedScene cachedScene;

  @override
  State<SceneIllustration> createState() => _SceneIllustrationState();
}

class _SceneIllustrationState extends State<SceneIllustration> {
  late final ImageProvider _imageProvider;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _imageProvider = FileImage(File(widget.cachedScene.backgroundPath));
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    });
    _imageProvider.resolve(const ImageConfiguration()).addListener(_listener!);
  }

  @override
  void dispose() {
    _imageProvider.resolve(const ImageConfiguration()).removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    if (imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final controller = context.watch<SceneController>();
    return Center(
      child: AspectRatio(
        aspectRatio: imageSize.width / imageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: _imageProvider, fit: BoxFit.fill),
                for (final object in widget.cachedScene.scene.objects)
                  Positioned(
                    key: ValueKey('object_zone_${object.id}'),
                    left: object.rect.x * width,
                    top: object.rect.y * height,
                    width: object.rect.width * width,
                    height: object.rect.height * height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.onObjectTapped(object),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test to confirm it passes**

```bash
flutter test test/presentation/widgets/scene_illustration_test.dart
```

Expected: PASS (1 test).

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/scene_illustration.dart test/support/fixture_assets.dart test/presentation/widgets
git commit -m "feat: add SceneIllustration with normalized tap zones"
```

---

## Task 13: SceneScreen — mode switch, find banner, congrats overlay

**Files:**
- Create: `lib/presentation/screens/scene_screen.dart`
- Test: `test/presentation/screens/scene_screen_test.dart`

**Interfaces:**
- Consumes: `ContentRepository` from Task 9, `SceneController`/`SceneModeType` from Task 11, `SceneIllustration` from Task 12, `AudioSink`/`AudioPlayerService` from Task 6.
- Produces: `class SceneScreen extends StatefulWidget { const SceneScreen({required ContentRepository contentRepository, required String sceneId, AudioSink Function()? audioSinkFactory}); }`. Consumed by Task 14 (`SceneListScreen` navigates to it) and Task 15 (manual run).

- [ ] **Step 1: Write the failing widget tests**

`test/presentation/screens/scene_screen_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/presentation/screens/scene_screen.dart';

import '../../support/fake_audio_sink.dart';
import '../../support/fixture_assets.dart';

Future<Directory> _seedCache() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  await File(p.join(sceneDir.path, 'ball.wav')).writeAsBytes([0]);
  await File(p.join(sceneDir.path, 'cat.wav')).writeAsBytes([0]);
  await File(p.join(sceneDir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': 'demo',
    'version': 1,
    'title': 'Демо',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      {
        'id': 'ball',
        'label': 'Мяч',
        'audio': 'ball.wav',
        'rect': {'x': 0.0, 'y': 0.0, 'width': 0.2, 'height': 0.2},
      },
      {
        'id': 'cat',
        'label': 'Кот',
        'audio': 'cat.wav',
        'rect': {'x': 0.5, 'y': 0.5, 'width': 0.2, 'height': 0.2},
      },
    ],
  }));
  return cacheRoot;
}

void main() {
  testWidgets('opens in explore mode; switching to find shows the banner and completing it shows congrats', (tester) async {
    final cacheRoot = await _seedCache();
    addTearDown(() => cacheRoot.delete(recursive: true));
    final audio = FakeAudioSink();
    final repository = ContentRepository(
      httpClient: http.Client(),
      baseUrl: Uri.parse('https://example.invalid/v1/'),
      cacheRootProvider: () async => cacheRoot,
    );

    await tester.pumpWidget(MaterialApp(
      home: SceneScreen(
        contentRepository: repository,
        sceneId: 'demo',
        audioSinkFactory: () => audio,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('mode_switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('find_banner')), findsNothing);
    expect(find.byKey(const ValueKey('congrats_overlay')), findsNothing);

    await tester.tap(find.text('Найди'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
    expect(find.text('Найди: Мяч'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object_zone_cat'))); // wrong
    await tester.pump();
    expect(find.text('Найди: Мяч'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object_zone_ball'))); // correct
    await tester.pump();
    expect(find.text('Найди: Кот'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('object_zone_cat'))); // correct, last
    await tester.pump();

    expect(find.byKey(const ValueKey('congrats_overlay')), findsOneWidget);
    expect(find.byKey(const ValueKey('find_banner')), findsNothing);

    await tester.pump(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('congrats_overlay')), findsNothing);
    final toggle = tester.widget<ToggleButtons>(find.byType(ToggleButtons));
    expect(toggle.isSelected, [true, false]); // back to Explore
  });
}
```

- [ ] **Step 2: Run the test to confirm it fails**

```bash
flutter test test/presentation/screens/scene_screen_test.dart
```

Expected: FAIL — `scene_screen.dart` doesn't exist.

- [ ] **Step 3: Implement SceneScreen**

`lib/presentation/screens/scene_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/audio_player_service.dart';
import '../../audio/audio_sink.dart';
import '../../data/cached_scene.dart';
import '../../data/content_repository.dart';
import '../../domain/models/scene_object.dart';
import '../controllers/scene_controller.dart';
import '../widgets/scene_illustration.dart';

class SceneScreen extends StatefulWidget {
  SceneScreen({
    super.key,
    required this.contentRepository,
    required this.sceneId,
    AudioSink Function()? audioSinkFactory,
  }) : audioSinkFactory = audioSinkFactory ?? AudioPlayerService.new;

  final ContentRepository contentRepository;
  final String sceneId;
  final AudioSink Function() audioSinkFactory;

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  CachedScene? _cachedScene;

  @override
  void initState() {
    super.initState();
    widget.contentRepository.loadScene(widget.sceneId).then((scene) {
      if (!mounted) return;
      setState(() => _cachedScene = scene);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cachedScene = _cachedScene;
    if (cachedScene == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider(
      create: (_) => SceneController(cachedScene: cachedScene, audioSink: widget.audioSinkFactory()),
      child: _SceneView(cachedScene: cachedScene),
    );
  }
}

class _SceneView extends StatelessWidget {
  const _SceneView({required this.cachedScene});

  final CachedScene cachedScene;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SceneController>();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: SceneIllustration(cachedScene: cachedScene)),
            if (controller.modeType == SceneModeType.find && !controller.showCongrats)
              Positioned(
                top: 16,
                left: 16,
                right: 88,
                child: _FindBanner(target: controller.currentFindTarget),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: _ModeSwitch(modeType: controller.modeType, onChanged: controller.setMode),
            ),
            if (controller.showCongrats) const Positioned.fill(child: _CongratsOverlay()),
          ],
        ),
      ),
    );
  }
}

class _FindBanner extends StatelessWidget {
  const _FindBanner({required this.target});

  final SceneObject? target;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    if (target == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('find_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Найди: ${target.label}', style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.modeType, required this.onChanged});

  final SceneModeType modeType;
  final ValueChanged<SceneModeType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mode_switch'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ToggleButtons(
        isSelected: [modeType == SceneModeType.explore, modeType == SceneModeType.find],
        onPressed: (index) => onChanged(index == 0 ? SceneModeType.explore : SceneModeType.find),
        children: const [
          Padding(padding: EdgeInsets.all(8), child: Text('Исследовать')),
          Padding(padding: EdgeInsets.all(8), child: Text('Найди')),
        ],
      ),
    );
  }
}

class _CongratsOverlay extends StatelessWidget {
  const _CongratsOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: const ValueKey('congrats_overlay'),
        color: Colors.black.withValues(alpha: 0.15),
        child: const Center(child: Icon(Icons.star, size: 96, color: Colors.amber)),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to confirm it passes**

```bash
flutter test test/presentation/screens/scene_screen_test.dart
```

Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/scene_screen.dart test/presentation/screens/scene_screen_test.dart
git commit -m "feat: add SceneScreen with mode switch and congrats overlay"
```

---

## Task 14: SceneListScreen

**Files:**
- Create: `lib/presentation/screens/scene_list_screen.dart`
- Test: `test/presentation/screens/scene_list_screen_test.dart`

**Interfaces:**
- Consumes: `ContentRepository` from Task 9, `SceneScreen` from Task 13.
- Produces: `class SceneListScreen extends StatefulWidget { const SceneListScreen({required ContentRepository contentRepository}); }`. Consumed by Task 15 (`main.dart`, the app's home screen).

- [ ] **Step 1: Write the failing widget tests**

`test/presentation/screens/scene_list_screen_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:yandee/data/content_repository.dart';
import 'package:yandee/presentation/screens/scene_list_screen.dart';

Future<void> _seedScene(Directory cacheRoot, String id, String title) async {
  final dir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, id));
  await dir.create(recursive: true);
  await File(p.join(dir.path, 'thumb.png')).writeAsBytes([1, 2, 3]);
  await File(p.join(dir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': id,
    'version': 1,
    'title': title,
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': <Map<String, dynamic>>[],
  }));
}

void main() {
  testWidgets('shows cached scenes as cards', (tester) async {
    final cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_');
    addTearDown(() => cacheRoot.delete(recursive: true));
    await _seedScene(cacheRoot, 'city', 'Город');
    await _seedScene(cacheRoot, 'farm', 'Ферма');
    final repository = ContentRepository(
      httpClient: MockClient((_) async => throw const SocketException('offline')),
      baseUrl: Uri.parse('https://example.invalid/v1/'),
      cacheRootProvider: () async => cacheRoot,
    );

    await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Город'), findsOneWidget);
    expect(find.text('Ферма'), findsOneWidget);
  });

  testWidgets('shows a retry screen when the cache is empty and offline', (tester) async {
    final cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_empty_');
    addTearDown(() => cacheRoot.delete(recursive: true));
    final repository = ContentRepository(
      httpClient: MockClient((_) async => throw const SocketException('offline')),
      baseUrl: Uri.parse('https://example.invalid/v1/'),
      cacheRootProvider: () async => cacheRoot,
    );

    await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Нет подключения'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);
  });

  testWidgets('tapping a card navigates to SceneScreen', (tester) async {
    final cacheRoot = await Directory.systemTemp.createTemp('yandee_list_test_nav_');
    addTearDown(() => cacheRoot.delete(recursive: true));
    await _seedScene(cacheRoot, 'city', 'Город');
    // scene_list navigates by id; SceneScreen's own background load will
    // just spin (no background.png seeded) — enough to confirm navigation.
    final repository = ContentRepository(
      httpClient: MockClient((_) async => throw const SocketException('offline')),
      baseUrl: Uri.parse('https://example.invalid/v1/'),
      cacheRootProvider: () async => cacheRoot,
    );

    await tester.pumpWidget(MaterialApp(home: SceneListScreen(contentRepository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('scene_card_city')));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsOneWidget); // SceneScreen's own loading state
  });
}
```

- [ ] **Step 2: Run the tests to confirm they fail**

```bash
flutter test test/presentation/screens/scene_list_screen_test.dart
```

Expected: FAIL — `scene_list_screen.dart` doesn't exist.

- [ ] **Step 3: Implement SceneListScreen**

`lib/presentation/screens/scene_list_screen.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/cached_scene.dart';
import '../../data/content_repository.dart';
import 'scene_screen.dart';

class SceneListScreen extends StatefulWidget {
  const SceneListScreen({super.key, required this.contentRepository});

  final ContentRepository contentRepository;

  @override
  State<SceneListScreen> createState() => _SceneListScreenState();
}

class _SceneListScreenState extends State<SceneListScreen> {
  List<CachedSceneSummary>? _scenes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cached = await widget.contentRepository.loadCachedIndex();
    if (!mounted) return;
    setState(() {
      _scenes = cached;
      _loading = false;
    });
    await widget.contentRepository.refresh();
    if (!mounted) return;
    final updated = await widget.contentRepository.loadCachedIndex();
    if (!mounted) return;
    setState(() => _scenes = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scenes = _scenes!;
    if (scenes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Нет подключения'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Yandee')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: scenes.map(_buildCard).toList(),
      ),
    );
  }

  Widget _buildCard(CachedSceneSummary scene) {
    return GestureDetector(
      key: ValueKey('scene_card_${scene.id}'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SceneScreen(contentRepository: widget.contentRepository, sceneId: scene.id),
      )),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(child: Image.file(File(scene.thumbnailPath), fit: BoxFit.cover)),
            Padding(padding: const EdgeInsets.all(8), child: Text(scene.title)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to confirm they pass**

```bash
flutter test test/presentation/screens/scene_list_screen_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/scene_list_screen.dart test/presentation/screens/scene_list_screen_test.dart
git commit -m "feat: add SceneListScreen"
```

---

## Task 15: Wire main.dart and verify on a device/emulator

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `ContentRepository` (Task 9), `DemoContentSeeder` (Task 10), `SceneListScreen` (Task 14).
- Produces: the app's `main()` entry point — nothing later depends on it.

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'data/content_repository.dart';
import 'data/demo_content_seeder.dart';
import 'presentation/screens/scene_list_screen.dart';

/// Root of the static hosting endpoint that serves `index.json` and each
/// scene's files. Must end with a trailing slash — `Uri.resolve` treats a
/// URL's last path segment as a filename otherwise, and would silently
/// drop it when building request URLs. Point this at the real CDN once
/// content hosting is deployed; until then, requests simply fail and the
/// app falls back to its local (seeded demo) cache, per the offline
/// error-handling behavior in ContentRepository.refresh().
final kContentBaseUrl = Uri.parse('https://content.yandee.app/v1/');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YandeeApp());
}

class YandeeApp extends StatelessWidget {
  const YandeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final contentRepository = ContentRepository(
      httpClient: http.Client(),
      baseUrl: kContentBaseUrl,
      cacheRootProvider: getApplicationDocumentsDirectory,
    );
    return MaterialApp(
      title: 'Yandee',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange),
      home: _StartupScreen(contentRepository: contentRepository),
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen({required this.contentRepository});

  final ContentRepository contentRepository;

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  late final Future<void> _seeded = _seed();

  Future<void> _seed() async {
    final cacheRoot = await getApplicationDocumentsDirectory();
    await const DemoContentSeeder().seedIfEmpty(cacheRoot);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _seeded,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return SceneListScreen(contentRepository: widget.contentRepository);
      },
    );
  }
}
```

- [ ] **Step 2: Manual verification on a simulator/emulator**

```bash
flutter run
```

Walk through, and confirm each one:
1. App launches to a grid with one card, "Демо" (the seeded placeholder scene — a blue background with 4 colored rectangles).
2. Opening it shows the full illustration with an "Исследовать/Найди" switch in the top-right corner.
3. In Исследовать, tapping each colored rectangle plays (silent placeholder) audio without crashing or visibly reacting otherwise.
4. Switching to Найди shows a "Найди: <label>" banner; tapping the wrong rectangle leaves the banner unchanged; tapping the right one advances it; after the last object, a star overlay appears for ~2 seconds and the switch returns to Исследовать on its own.
5. The back button returns to the scene grid; the scene screen never closes on its own.
6. Force-quit and relaunch with the device in airplane mode: the grid still shows "Демо" (offline cache works), with no error banner.

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: wire app startup (seed cache, scene list, content repository)"
```

---

## Task 16: Full verification pass

**Files:** none (verification only).

- [ ] **Step 1: Run static analysis**

```bash
flutter analyze
```

Expected: "No issues found!".

- [ ] **Step 2: Run the full test suite**

```bash
flutter test
```

Expected: all tests pass (unit tests for models/modes/data layer/controller, widget tests for the illustration and both screens).

- [ ] **Step 3: Confirm no trace of the old, unrelated project remains**

```bash
grep -ri "coviewing\|video_player\|interaction_service\|parent_prompt" --include=*.dart --include=*.yaml -r . || echo "clean"
```

Expected: "clean" (no matches) — the prior project's name and the discarded video-player skeleton were never carried into this codebase.

- [ ] **Step 4: Commit any leftover changes**

If `pubspec.lock` or anything else changed as a side effect of the above (it shouldn't have), commit it:

```bash
git status
git add -A
git commit -m "chore: final verification pass"
```

---

## Self-Review Notes

- **Spec coverage:** §1 scope → Tasks 1, 14–15 (list/scene screens, manual mode switch, no forced parent action). §2 content model/contract → Task 2 (models), Task 7 (schema instance via demo scene), Task 9 (index/thumbnail convention). §3 architecture → Tasks 3–6, 8–14 (Data/Domain/Presentation layers, `SceneMode` extension point, `AudioPlayerService`). §4 delivery/cache/errors → Tasks 8–9 (atomic swap, version compare), Task 14 (offline/empty states matching the error table). §5 testing → unit tests in Tasks 2, 4, 5, 8, 9, 10, 11; widget tests in Tasks 12, 13, 14; manual pass in Task 15.
- **Placeholder scan:** no "TBD"/"handle appropriately" steps; every code block is complete and copy-pasteable; the one deliberately-undeployed value (`kContentBaseUrl`, Task 15) is a concrete, documented placeholder domain with an explicit, testable fallback behavior — not a stub.
- **Type consistency:** `SceneModeType`, `SceneModeEffects`, `AudioSink`, `CachedScene`/`CachedSceneSummary`, and `ContentRepository.cacheSubdirName` are defined once (Tasks 8, 11, 6) and referenced with identical names/signatures in every later task that consumes them.
