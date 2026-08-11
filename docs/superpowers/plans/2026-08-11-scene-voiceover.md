# Scene Voiceover (TTS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 54 silent placeholder WAV files (50 object-name words + 4 system phrases) with real macOS `say` speech (voice `Milena`, `ru_RU`), without touching `scene.json` or any app code.

**Architecture:** A new dev-only script, `tool/generate_voiceover.dart`, reuses the existing scene/object vocabulary (extracted into a shared `tool/src/scene_vocabulary.dart` so it isn't duplicated with `tool/generate_placeholder_assets.dart`), maps it to a flat list of `{text, outputPath}` tasks via a pure, unit-tested function, then shells out to `say` + `afconvert` per task to write real speech directly into the existing asset paths.

**Tech Stack:** Dart (`dart:io` `Process.run`), macOS `say` + `afconvert` (both preinstalled, no new dependencies), `flutter_test` for the pure-function unit tests.

## Global Constraints

- Voice: `Milena` (`ru_RU`) — the only Russian voice available via `say` on this machine
- Speech rate: `-r 150` (words/minute) — slower than the ~175–200 default, for toddler audience
- Output audio format: WAV, 16-bit little-endian PCM, mono, 22050 Hz (`afconvert -f WAVE -d LEI16@22050 -c 1`)
- Output paths are unchanged from today: `assets/demo_content/<scene_id>/<object_id>.wav`, `assets/audio/system/<phrase>.wav`
- System phrase text (agreed, verbatim):
  - `find_intro` → `Найди:`
  - `wrong_hint` → `Попробуй ещё раз`
  - `correct` → `Молодец!`
  - `round_complete` → `Ура, ты всё нашёл!`
- No changes to `scene.json`, `lib/`, or any app runtime code — this plan only touches `tool/`, `test/`, and regenerates binary assets under `assets/`
- No CI/build-time hook — this is a manually-run dev tool, same as the existing `tool/generate_placeholder_assets.dart`

---

### Task 1: Extract shared scene vocabulary

**Files:**
- Create: `tool/src/scene_vocabulary.dart`
- Modify: `tool/generate_placeholder_assets.dart`
- Test: `test/tool/scene_vocabulary_test.dart`

**Interfaces:**
- Produces: `class ObjectSpec { const ObjectSpec(this.id, this.label); final String id; final String label; }`
- Produces: `class SceneSpec { const SceneSpec(this.id, this.title, this.backgroundRgb, this.objects); final String id; final String title; final List<int> backgroundRgb; final List<ObjectSpec> objects; }`
- Produces: `const List<SceneSpec> scenes` — 5 scenes (`home`, `kitchen`, `farm`, `street`, `bathroom`), 10 objects each, identical content to today's private `_scenes` in `tool/generate_placeholder_assets.dart`

This task moves the existing private `_ObjectSpec`/`_SceneSpec`/`_scenes` out of `tool/generate_placeholder_assets.dart` into a shared, public file so Task 2's voiceover script can reuse the same vocabulary without duplicating 50 hand-typed labels.

- [ ] **Step 1: Write the failing test**

Create `test/tool/scene_vocabulary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/scene_vocabulary.dart';

void main() {
  test('defines exactly 5 scenes with 10 objects each', () {
    expect(scenes.length, 5);
    for (final scene in scenes) {
      expect(scene.objects.length, 10, reason: 'scene ${scene.id}');
    }
  });

  test('kitchen scene includes the expected vocabulary', () {
    final kitchen = scenes.firstWhere((s) => s.id == 'kitchen');
    expect(kitchen.title, 'Кухня');
    final apple = kitchen.objects.firstWhere((o) => o.id == 'apple');
    expect(apple.label, 'Яблоко');
  });

  test('every object id is unique within its scene', () {
    for (final scene in scenes) {
      final ids = scene.objects.map((o) => o.id).toSet();
      expect(ids.length, scene.objects.length, reason: 'scene ${scene.id}');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tool/scene_vocabulary_test.dart`
Expected: FAIL — `tool/src/scene_vocabulary.dart` does not exist (import error)

- [ ] **Step 3: Create `tool/src/scene_vocabulary.dart`**

Move the vocabulary out of `tool/generate_placeholder_assets.dart` verbatim, only dropping the leading underscores to make it public:

```dart
/// One tappable object in a scene: its content-facing id/label (the real,
/// agreed-on vocabulary for that scene). Shared between
/// `generate_placeholder_assets.dart` (art) and `generate_voiceover.dart`
/// (audio) so the word list lives in exactly one place.
class ObjectSpec {
  const ObjectSpec(this.id, this.label);
  final String id;
  final String label;
}

class SceneSpec {
  const SceneSpec(this.id, this.title, this.backgroundRgb, this.objects);
  final String id;
  final String title;
  final List<int> backgroundRgb;
  final List<ObjectSpec> objects;
}

// The app's first 5 real content scenes (see
// docs/superpowers/plans/2026-08-11-yandee-interactive-scenes.md).
const scenes = [
  SceneSpec('home', 'Дом', [235, 222, 200], [
    ObjectSpec('bed', 'Кровать'),
    ObjectSpec('table', 'Стол'),
    ObjectSpec('chair', 'Стул'),
    ObjectSpec('lamp', 'Лампа'),
    ObjectSpec('book', 'Книга'),
    ObjectSpec('clock', 'Часы'),
    ObjectSpec('window', 'Окно'),
    ObjectSpec('door', 'Дверь'),
    ObjectSpec('sofa', 'Диван'),
    ObjectSpec('rug', 'Ковёр'),
  ]),
  SceneSpec('kitchen', 'Кухня', [255, 240, 200], [
    ObjectSpec('plate', 'Тарелка'),
    ObjectSpec('cup', 'Чашка'),
    ObjectSpec('spoon', 'Ложка'),
    ObjectSpec('fork', 'Вилка'),
    ObjectSpec('fridge', 'Холодильник'),
    ObjectSpec('stove', 'Плита'),
    ObjectSpec('kettle', 'Чайник'),
    ObjectSpec('apple', 'Яблоко'),
    ObjectSpec('bread', 'Хлеб'),
    ObjectSpec('pot', 'Кастрюля'),
  ]),
  SceneSpec('farm', 'Ферма', [200, 230, 180], [
    ObjectSpec('cow', 'Корова'),
    ObjectSpec('pig', 'Свинья'),
    ObjectSpec('chicken', 'Курица'),
    ObjectSpec('rooster', 'Петух'),
    ObjectSpec('horse', 'Лошадь'),
    ObjectSpec('sheep', 'Овца'),
    ObjectSpec('goat', 'Коза'),
    ObjectSpec('duck', 'Утка'),
    ObjectSpec('dog', 'Собака'),
    ObjectSpec('tractor', 'Трактор'),
  ]),
  SceneSpec('street', 'Улица', [210, 215, 220], [
    ObjectSpec('car', 'Машина'),
    ObjectSpec('bus', 'Автобус'),
    ObjectSpec('bicycle', 'Велосипед'),
    ObjectSpec('traffic_light', 'Светофор'),
    ObjectSpec('tree', 'Дерево'),
    ObjectSpec('bench', 'Скамейка'),
    ObjectSpec('lamppost', 'Фонарь'),
    ObjectSpec('scooter', 'Самокат'),
    ObjectSpec('truck', 'Грузовик'),
    ObjectSpec('road_sign', 'Дорожный знак'),
  ]),
  SceneSpec('bathroom', 'Ванная', [210, 235, 245], [
    ObjectSpec('soap', 'Мыло'),
    ObjectSpec('toothbrush', 'Зубная щётка'),
    ObjectSpec('toothpaste', 'Зубная паста'),
    ObjectSpec('towel', 'Полотенце'),
    ObjectSpec('bathtub', 'Ванна'),
    ObjectSpec('sink', 'Раковина'),
    ObjectSpec('shampoo', 'Шампунь'),
    ObjectSpec('duck_toy', 'Уточка'),
    ObjectSpec('mirror', 'Зеркало'),
    ObjectSpec('comb', 'Расчёска'),
  ]),
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tool/scene_vocabulary_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Update `tool/generate_placeholder_assets.dart` to use the shared vocabulary**

Remove the now-duplicated private declarations and import the shared file instead, then rename every use of `_ObjectSpec`/`_SceneSpec`/`_scenes` to `ObjectSpec`/`SceneSpec`/`scenes`.

At the top of the file, change:

```dart
import 'dart:convert';
import 'dart:io';

import 'src/placeholder_png.dart';
import 'src/placeholder_wav.dart';

/// One tappable object in a placeholder scene: its content-facing id/label
/// (the real, agreed-on vocabulary for that scene) plus generated
/// placeholder art/audio, same as everything else in this tool.
class _ObjectSpec {
  const _ObjectSpec(this.id, this.label);
  final String id;
  final String label;
}

class _SceneSpec {
  const _SceneSpec(this.id, this.title, this.backgroundRgb, this.objects);
  final String id;
  final String title;
  final List<int> backgroundRgb;
  final List<_ObjectSpec> objects;
}
```

to:

```dart
import 'dart:convert';
import 'dart:io';

import 'src/placeholder_png.dart';
import 'src/placeholder_wav.dart';
import 'src/scene_vocabulary.dart';
```

Then delete the entire `final _scenes = [ ... ];` block (the 5 `_SceneSpec(...)` entries — now living in `tool/src/scene_vocabulary.dart` instead), and update every remaining reference in the file:

- `List<PlaceholderMarker> _layoutMarkers(List<_ObjectSpec> objects)` → `List<PlaceholderMarker> _layoutMarkers(List<ObjectSpec> objects)`
- `Map<String, dynamic> _buildSceneJson(_SceneSpec scene, ...)` → `Map<String, dynamic> _buildSceneJson(SceneSpec scene, ...)`
- `for (final scene in _scenes) {` (in `main()`) → `for (final scene in scenes) {`

- [ ] **Step 6: Verify the placeholder generator still produces identical output**

Run: `dart run tool/generate_placeholder_assets.dart && git status --short`
Expected: the command prints its usual 59 "wrote ..." lines, and `git status --short` shows **no changes** under `assets/` (byte-identical output — only the vocabulary's *location* moved, not its content). If anything under `assets/` shows as modified, the vocabulary was copied incorrectly — diff it against the original `_scenes` block before continuing.

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add tool/src/scene_vocabulary.dart tool/generate_placeholder_assets.dart test/tool/scene_vocabulary_test.dart
git commit -m "refactor: extract shared scene vocabulary from placeholder generator"
```

---

### Task 2: Pure mapping from vocabulary to voiceover tasks

**Files:**
- Create: `tool/src/voiceover_tasks.dart`
- Test: `test/tool/voiceover_tasks_test.dart`

**Interfaces:**
- Consumes: `scenes` (`List<SceneSpec>`) from `tool/src/scene_vocabulary.dart` (Task 1)
- Produces: `class VoiceoverTask { const VoiceoverTask({required this.text, required this.outputPath}); final String text; final String outputPath; }`
- Produces: `List<VoiceoverTask> buildVoiceoverTasks()` — pure function, no I/O; Task 3's script consumes this list

- [ ] **Step 1: Write the failing test**

Create `test/tool/voiceover_tasks_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/voiceover_tasks.dart';

void main() {
  test('includes all 4 system phrases with the agreed text', () {
    final tasks = buildVoiceoverTasks();
    final byPath = {for (final t in tasks) t.outputPath: t.text};

    expect(byPath['assets/audio/system/find_intro.wav'], 'Найди:');
    expect(byPath['assets/audio/system/wrong_hint.wav'], 'Попробуй ещё раз');
    expect(byPath['assets/audio/system/correct.wav'], 'Молодец!');
    expect(byPath['assets/audio/system/round_complete.wav'], 'Ура, ты всё нашёл!');
  });

  test('includes one task per scene object, at the path scene.json expects', () {
    final tasks = buildVoiceoverTasks();
    final byPath = {for (final t in tasks) t.outputPath: t.text};

    expect(byPath['assets/demo_content/kitchen/apple.wav'], 'Яблоко');
    expect(byPath['assets/demo_content/street/road_sign.wav'], 'Дорожный знак');
    expect(byPath['assets/demo_content/bathroom/duck_toy.wav'], 'Уточка');
  });

  test('produces exactly 54 tasks with no duplicate output paths', () {
    final tasks = buildVoiceoverTasks();
    expect(tasks.length, 54);
    expect(tasks.map((t) => t.outputPath).toSet().length, 54);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/tool/voiceover_tasks_test.dart`
Expected: FAIL — `tool/src/voiceover_tasks.dart` does not exist (import error)

- [ ] **Step 3: Write the implementation**

Create `tool/src/voiceover_tasks.dart`:

```dart
import 'scene_vocabulary.dart';

/// One word or phrase to synthesize, and where the resulting WAV belongs —
/// the exact same relative path `scene.json` (for objects) or
/// `AudioPlayerService` (for system phrases) already expects.
class VoiceoverTask {
  const VoiceoverTask({required this.text, required this.outputPath});
  final String text;
  final String outputPath;
}

const _systemPhrases = [
  VoiceoverTask(text: 'Найди:', outputPath: 'assets/audio/system/find_intro.wav'),
  VoiceoverTask(text: 'Попробуй ещё раз', outputPath: 'assets/audio/system/wrong_hint.wav'),
  VoiceoverTask(text: 'Молодец!', outputPath: 'assets/audio/system/correct.wav'),
  VoiceoverTask(text: 'Ура, ты всё нашёл!', outputPath: 'assets/audio/system/round_complete.wav'),
];

/// The full list of voiceover tasks: 4 system phrases, then every scene
/// object's name, in scene/object declaration order.
List<VoiceoverTask> buildVoiceoverTasks() {
  final tasks = <VoiceoverTask>[..._systemPhrases];
  for (final scene in scenes) {
    for (final object in scene.objects) {
      tasks.add(VoiceoverTask(
        text: object.label,
        outputPath: 'assets/demo_content/${scene.id}/${object.id}.wav',
      ));
    }
  }
  return tasks;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/tool/voiceover_tasks_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add tool/src/voiceover_tasks.dart test/tool/voiceover_tasks_test.dart
git commit -m "feat: add pure mapping from scene vocabulary to voiceover tasks"
```

---

### Task 3: Voiceover generator script — synthesize and replace the silent assets

**Files:**
- Create: `tool/generate_voiceover.dart`
- Modify (regenerated binary assets, not hand-edited): `assets/demo_content/*/*.wav` (50 files), `assets/audio/system/*.wav` (4 files)

**Interfaces:**
- Consumes: `buildVoiceoverTasks()` (`List<VoiceoverTask>`) from `tool/src/voiceover_tasks.dart` (Task 2)

This task shells out to macOS `say` and `afconvert`, so — matching the existing `tool/generate_placeholder_assets.dart`, which is also untested — it has no automated unit test. Its correctness is verified by actually running it and inspecting the resulting files.

- [ ] **Step 1: Write the script**

Create `tool/generate_voiceover.dart`:

```dart
import 'dart:io';

import 'src/voiceover_tasks.dart';

const _voice = 'Milena';
const _rateWpm = 150;
const _sampleRateHz = 22050;

Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp('yandee_voiceover_');
  var failures = 0;
  try {
    for (final task in buildVoiceoverTasks()) {
      final tempAiff = File('${tempDir.path}/tts.aiff');

      final sayResult = await Process.run('say', [
        '-v', _voice,
        '-r', '$_rateWpm',
        '-o', tempAiff.path,
        task.text,
      ]);
      if (sayResult.exitCode != 0) {
        stderr.writeln('say failed for "${task.text}" (${task.outputPath}): ${sayResult.stderr}');
        failures++;
        continue;
      }

      final outputFile = File(task.outputPath);
      await outputFile.parent.create(recursive: true);
      final convertResult = await Process.run('afconvert', [
        '-f', 'WAVE',
        '-d', 'LEI16@$_sampleRateHz',
        '-c', '1',
        tempAiff.path,
        outputFile.path,
      ]);
      if (convertResult.exitCode != 0) {
        stderr.writeln('afconvert failed for "${task.outputPath}": ${convertResult.stderr}');
        failures++;
        continue;
      }

      final bytes = await outputFile.length();
      stdout.writeln('wrote ${task.outputPath} ($bytes bytes)');
      await tempAiff.delete();
    }
  } finally {
    await tempDir.delete(recursive: true);
  }

  if (failures > 0) {
    stderr.writeln('$failures task(s) failed — see above.');
    exitCode = 1;
  }
}
```

- [ ] **Step 2: Run the script**

Run: `dart run tool/generate_voiceover.dart`
Expected: 54 lines of `wrote assets/.../....wav (N bytes)`, exit code 0, no lines on stderr

- [ ] **Step 3: Spot-check the output**

Run: `file assets/demo_content/kitchen/apple.wav assets/audio/system/find_intro.wav`
Expected: both report `WAVE audio, Microsoft PCM, 16 bit, mono 22050 Hz` (not the old silent placeholders, which were 8000 Hz)

Run: `afplay assets/demo_content/kitchen/apple.wav` and `afplay assets/audio/system/correct.wav`
Expected: audibly hear "Яблоко" and "Молодец!" spoken in Russian

- [ ] **Step 4: Run the full app verification**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all tests pass (app code and `scene.json` are unchanged, so this confirms the asset swap didn't break anything — `content_repository_test.dart` and `demo_content_seeder_test.dart` in particular exercise the asset-loading path)

- [ ] **Step 5: Commit**

```bash
git add tool/generate_voiceover.dart assets/demo_content assets/audio/system
git commit -m "feat: generate real TTS voiceover for scene objects and system phrases"
```

---

## Self-Review Notes

- **Spec coverage:** §2 (architecture/script) → Tasks 1–3; §3 (voice/text) → Global Constraints + Task 2's phrase texts; §4 (hybrid status note) → already recorded in the spec doc itself, no code artifact needed; §5 (run/verify) → Task 3 Steps 2–4.
- **No placeholders:** every step has literal code/commands, no "TBD" or "handle errors appropriately".
- **Type consistency:** `ObjectSpec`/`SceneSpec` (Task 1) → consumed by `voiceover_tasks.dart` (Task 2) via `scenes: List<SceneSpec>`; `VoiceoverTask` (Task 2) → consumed by `generate_voiceover.dart` (Task 3) via `buildVoiceoverTasks(): List<VoiceoverTask>`. Names match exactly across all three tasks.
