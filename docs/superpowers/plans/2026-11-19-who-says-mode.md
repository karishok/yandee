# «Кто это?» (find by sound) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new scene mode in which an object's own sound plays and the child taps whoever (or whatever) makes it, switched on from Find mode with an ear button.

**Architecture:** A new `WhoSaysMode implements SceneMode`, next to `FindMode`, talking to the outside world only through `SceneModeEffects`, which gains `promptSound`, `hintThenRepeatSound` and a `withSound` flag on `announceObject`. `SceneController` implements those effects on top of the existing `AudioSink` (no sink changes), and gets a `whoSays` mode type. `scene_screen.dart` shows the flashlight button only in the Explore family of modes, and the ear button plus a repeat-sound button only in the Find family.

**Tech Stack:** Flutter 3.47, Dart, `provider`, `flutter_test`.

Spec: `docs/superpowers/specs/2026-11-19-who-says-mode-design.md`.

## Global Constraints

- The mode exists in a scene with **at least 5 distinct sounds** (objects with `sound`, deduplicated by `label`); a constant, not a `scene.json` field.
- A round is **up to 5** targets: the sound objects (one per label), shuffled, first 5.
- First target of a round: the existing «Где» phrase (`SystemPhrase.findIntro`), then the sound. Later targets and repeats: the sound alone.
- Correct tap: `SystemPhrase.correct`, then the object's name **without** its own sound, then the next sound.
- Wrong tap: «Попробуй ещё раз» (`SystemPhrase.wrongHint`, existing dedupe), then the target's sound once the hint has finished; a correct answer, a mode switch or closing the scene cancels that sound.
- No new audio files, no `AudioSink` changes, no new `scene.json` fields.
- The target's name is never shown on screen in this mode.
- UI text is Russian; buttons are wordless round 52 px buttons with Russian `Semantics` labels.
- Run everything from the worktree root: `/Users/karina/flutter/yandee/.claude/worktrees/who-says-mode-798ab9`.

## File Structure

- Modify `lib/domain/modes/scene_mode_effects.dart` — the three new effect capabilities.
- Modify `lib/presentation/controllers/scene_controller.dart` — implements them; `whoSays` mode type, `hasWhoSays`, `whoSays`, `repeatWhoSaysSound`.
- Create `lib/domain/modes/who_says_mode.dart` — the game rules.
- Modify `lib/presentation/screens/scene_screen.dart` — buttons and mode-switch highlighting.
- Modify `test/support/fake_scene_mode_effects.dart` — records the new effects.
- Create `test/domain/modes/who_says_mode_test.dart`.
- Modify `test/presentation/controllers/scene_controller_test.dart`, `test/presentation/screens/scene_screen_test.dart`.

---

### Task 1: Sound effects in `SceneModeEffects` and `SceneController`

**Files:**
- Modify: `lib/domain/modes/scene_mode_effects.dart`
- Modify: `lib/presentation/controllers/scene_controller.dart`
- Modify: `test/support/fake_scene_mode_effects.dart`
- Test: `test/presentation/controllers/scene_controller_test.dart`

**Interfaces:**
- Produces (on `SceneModeEffects`, implemented by `SceneController` and `FakeSceneModeEffects`):
  - `void promptSound(SceneObject target, {bool announceIntro = true})`
  - `void hintThenRepeatSound(SceneObject target)`
  - `Future<void> announceObject(SceneObject object, {bool withSound = true})`
- Produces (on `FakeSceneModeEffects`): `List<SceneObject> promptSoundCalls`, `List<bool> promptSoundAnnounceIntroCalls`, `List<SceneObject> hintThenRepeatSoundCalls`, `List<bool> announceObjectWithSoundCalls`.

- [ ] **Step 1: Write the failing controller tests**

Append inside `main()` of `test/presentation/controllers/scene_controller_test.dart` (it already defines `rect`, `ball`, imports `CachedScene`, `Scene`, `SceneObject`, `SystemPhrase`, `FakeAudioSink`):

```dart
  group('sound effects', () {
    const cow = SceneObject(id: 'cow', label: 'Корова', audio: 'cow.wav', rect: rect, sound: 'cow_sound.wav');
    final farm = CachedScene(
      scene: Scene(
        id: 'farm',
        version: 1,
        title: 'Ферма',
        minAgeMonths: 12,
        background: 'background.png',
        objects: [cow, ball],
      ),
      directoryPath: '/cache/farm',
    );
    final cowSound = farm.soundPathFor(cow)!;

    test('promptSound with the intro says «Где», then the sound', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      controller.promptSound(cow);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedSequences, [(SystemPhrase.findIntro, cowSound)]);
      expect(audio.playedFiles, isEmpty);
    });

    test('promptSound without the intro plays just the sound', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      controller.promptSound(cow, announceIntro: false);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [cowSound]);
      expect(audio.playedSequences, isEmpty);
    });

    test('announceObject without its sound says only the name', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      await controller.announceObject(cow, withSound: false);
      expect(audio.playedFiles, [farm.audioPathFor(cow)]);
    });

    test('hintThenRepeatSound: the hint, then the sound once the hint has finished', () async {
      final audio = FakeAudioSink()..holdInterruptiblePhrase(SystemPhrase.wrongHint);
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      controller.hintThenRepeatSound(cow);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedInterruptibleSystemPhrases, [SystemPhrase.wrongHint]);
      expect(audio.playedFiles, isEmpty, reason: 'the sound waits for the hint');

      audio.releaseInterruptiblePhrase(SystemPhrase.wrongHint);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [cowSound]);
    });

    test('several misses in a row: one hint, and the sound once at its end', () async {
      final audio = FakeAudioSink()..holdInterruptiblePhrase(SystemPhrase.wrongHint);
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      controller.hintThenRepeatSound(cow);
      controller.hintThenRepeatSound(cow);
      controller.hintThenRepeatSound(cow);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedInterruptibleSystemPhrases, [SystemPhrase.wrongHint]);

      audio.releaseInterruptiblePhrase(SystemPhrase.wrongHint);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [cowSound]);
    });

    test('a correct answer while the hint is playing cancels the sound after it', () async {
      final audio = FakeAudioSink()..holdInterruptiblePhrase(SystemPhrase.wrongHint);
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      controller.hintThenRepeatSound(cow);
      unawaited(controller.playSystemPhrase(SystemPhrase.correct));
      audio.releaseInterruptiblePhrase(SystemPhrase.wrongHint);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedSystemPhrases, [SystemPhrase.correct]);
      expect(audio.playedFiles, isEmpty);
    });

    test('switching mode while the hint is playing cancels the sound after it', () async {
      final audio = FakeAudioSink()..holdInterruptiblePhrase(SystemPhrase.wrongHint);
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      controller.hintThenRepeatSound(cow);
      controller.setMode(SceneModeType.find);
      audio.releaseInterruptiblePhrase(SystemPhrase.wrongHint);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, isEmpty);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/controllers/scene_controller_test.dart`
Expected: compile errors — `promptSound`, `hintThenRepeatSound` not defined, no named parameter `withSound`.

- [ ] **Step 3: Extend the `SceneModeEffects` interface**

In `lib/domain/modes/scene_mode_effects.dart`, replace the `announceObject` declaration and add two methods after `promptFind`:

```dart
  /// Plays [target]'s own sound (see `SceneObject.sound`) as the thing to
  /// find by ear — the "Где" lead-in word right before it when
  /// [announceIntro] is true (the first target of a round), the sound
  /// alone otherwise. Does nothing for an object without a sound.
  void promptSound(SceneObject target, {bool announceIntro = true});

  /// A wrong guess while finding [target] by ear: the "try again" hint,
  /// then [target]'s sound again once the hint has finished. Several in a
  /// row give one hint and one sound at its end; any other system phrase
  /// (a correct answer) or a mode switch before then cancels the sound.
  void hintThenRepeatSound(SceneObject target);

  /// Like [playObjectAudio], for a caller that has something to do after
  /// the name: completes once the name has been said to its end (or right
  /// away, if a later name took its place before its turn came). With
  /// [withSound] false the object's own sound is not made after the name.
  Future<void> announceObject(SceneObject object, {bool withSound = true});
```

- [ ] **Step 4: Update the fake**

Replace `test/support/fake_scene_mode_effects.dart` with:

```dart
import 'dart:async';

import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

class FakeSceneModeEffects implements SceneModeEffects {
  final List<SceneObject> objectAudioCalls = [];
  final List<SceneObject> promptFindCalls = [];
  final List<bool> promptFindAnnounceIntroCalls = [];
  final List<SceneObject> promptSoundCalls = [];
  final List<bool> promptSoundAnnounceIntroCalls = [];
  final List<SceneObject> hintThenRepeatSoundCalls = [];
  final List<SystemPhrase> systemPhraseCalls = [];
  final List<SceneObject> announceObjectCalls = [];
  final List<bool> announceObjectWithSoundCalls = [];
  int roundCompletedCalls = 0;

  /// While set, [announceObject] records its call but doesn't finish until
  /// this completes — a name that is still being said.
  Completer<void>? announcementGate;

  @override
  void playObjectAudio(SceneObject object) => objectAudioCalls.add(object);

  @override
  void promptFind(SceneObject target, {bool announceIntro = true}) {
    promptFindCalls.add(target);
    promptFindAnnounceIntroCalls.add(announceIntro);
  }

  @override
  void promptSound(SceneObject target, {bool announceIntro = true}) {
    promptSoundCalls.add(target);
    promptSoundAnnounceIntroCalls.add(announceIntro);
  }

  @override
  void hintThenRepeatSound(SceneObject target) => hintThenRepeatSoundCalls.add(target);

  @override
  Future<void> announceObject(SceneObject object, {bool withSound = true}) async {
    announceObjectCalls.add(object);
    announceObjectWithSoundCalls.add(withSound);
    await announcementGate?.future;
  }

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) async => systemPhraseCalls.add(phrase);

  @override
  void onRoundCompleted() => roundCompletedCalls++;
}
```

- [ ] **Step 5: Implement in `SceneController`**

In `lib/presentation/controllers/scene_controller.dart`:

a) Next to `_wrongHintPlaying`, add the field:

```dart
  // The target whose sound is to follow the "try again" hint now playing
  // (find by sound). Cleared — so the sound is not made — by any other
  // system phrase, a mode switch, or when the sound has been made.
  SceneObject? _soundAfterHint;
```

b) In `setMode`, right after `_showCongrats = false;`, add `_soundAfterHint = null;`.

c) Replace `playObjectAudio`, `_sayName`'s signature line and its `name` record so the sound can be left out:

```dart
  @override
  void playObjectAudio(SceneObject object) => unawaited(_sayName(object));
```

```dart
  Future<void> _sayName(SceneObject object, {bool withSound = true}) {
    final done = Completer<void>();
    final name = (
      path: cachedScene.audioPathFor(object),
      soundPath: withSound ? cachedScene.soundPathFor(object) : null,
      done: done,
    );
```

(the rest of `_sayName` unchanged).

d) After `promptFind`, add:

```dart
  @override
  void promptSound(SceneObject target, {bool announceIntro = true}) {
    final soundPath = cachedScene.soundPathFor(target);
    if (soundPath == null) return;
    _voiceQueue = _voiceQueue.then(
      (_) => announceIntro
          ? _audio.playSystemPhraseThenFile(SystemPhrase.findIntro, soundPath)
          : _audio.playFile(soundPath),
    );
  }

  @override
  void hintThenRepeatSound(SceneObject target) {
    // Set before the hint starts: a hint already playing (a miss a moment
    // ago) makes this one a no-op, and it is that hint's end that plays
    // the sound — once, for the whole run of misses.
    _soundAfterHint = target;
    unawaited(playSystemPhrase(SystemPhrase.wrongHint));
  }

  void _playSoundAfterHint() {
    final target = _soundAfterHint;
    _soundAfterHint = null;
    if (target == null || _disposed) return;
    promptSound(target, announceIntro: false);
  }
```

e) Replace `announceObject`:

```dart
  @override
  Future<void> announceObject(SceneObject object, {bool withSound = true}) =>
      _sayName(object, withSound: withSound);
```

f) In `playSystemPhrase`, the wrong-hint branch's completion becomes:

```dart
      playback.whenComplete(() {
        _wrongHintPlaying = false;
        _playSoundAfterHint();
      });
```

and right after the existing `_wrongHintPlaying = false;` that follows `_audio.stopInterruptible();`, add `_soundAfterHint = null;`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/presentation/controllers/scene_controller_test.dart test/domain/modes`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/modes/scene_mode_effects.dart lib/presentation/controllers/scene_controller.dart test/support/fake_scene_mode_effects.dart test/presentation/controllers/scene_controller_test.dart
git commit -m "feat: scene effects for finding by sound"
```

---

### Task 2: `WhoSaysMode`

**Files:**
- Create: `lib/domain/modes/who_says_mode.dart`
- Test: `test/domain/modes/who_says_mode_test.dart`

**Interfaces:**
- Consumes: `SceneModeEffects.promptSound`, `.hintThenRepeatSound`, `.announceObject(…, withSound:)`, `.playSystemPhrase`, `.onRoundCompleted` (Task 1); `shuffleFindOrder` from `find_mode.dart`.
- Produces:
  - `class WhoSaysMode implements SceneMode` with ctor `WhoSaysMode({required List<SceneObject> objects, required SceneModeEffects effects, List<SceneObject> Function(List<SceneObject>) shuffle = shuffleFindOrder})`
  - `static const int minSounds = 5`, `static const int roundSize = 5`
  - `static List<SceneObject> soundObjects(List<SceneObject> objects)`
  - `static bool isAvailableIn(List<SceneObject> objects)`
  - getters `SceneObject? currentTarget`, `int roundLength`, `bool isComplete`
  - `void repeatSound()`

- [ ] **Step 1: Write the failing tests**

Create `test/domain/modes/who_says_mode_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';
import 'package:yandee/domain/modes/who_says_mode.dart';

import '../../support/fake_scene_mode_effects.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const cow = SceneObject(id: 'cow', label: 'Корова', audio: 'cow.wav', rect: rect, sound: 'cow_sound.wav');
  const cow2 = SceneObject(id: 'cow2', label: 'Корова', audio: 'cow.wav', rect: rect, sound: 'cow_sound.wav');
  const pig = SceneObject(id: 'pig', label: 'Свинья', audio: 'pig.wav', rect: rect, sound: 'pig_sound.wav');
  const hen = SceneObject(id: 'hen', label: 'Курица', audio: 'hen.wav', rect: rect, sound: 'hen_sound.wav');
  const horse = SceneObject(id: 'horse', label: 'Лошадь', audio: 'horse.wav', rect: rect, sound: 'horse_sound.wav');
  const sheep = SceneObject(id: 'sheep', label: 'Овца', audio: 'sheep.wav', rect: rect, sound: 'sheep_sound.wav');
  const duck = SceneObject(id: 'duck', label: 'Утка', audio: 'duck.wav', rect: rect, sound: 'duck_sound.wav');
  const tree = SceneObject(id: 'tree', label: 'Дерево', audio: 'tree.wav', rect: rect);
  final farm = [cow, tree, pig, cow2, hen, horse, sheep, duck];
  List<SceneObject> keepOrder(List<SceneObject> list) => list;

  WhoSaysMode start(FakeSceneModeEffects effects, {List<SceneObject>? objects}) =>
      WhoSaysMode(objects: objects ?? farm, effects: effects, shuffle: keepOrder)..activate();

  Future<void> answer(WhoSaysMode mode, SceneObject object) async {
    mode.onObjectTapped(object);
    await Future<void>.delayed(Duration.zero);
  }

  test('only objects with a sound are things to find, one per label', () {
    expect(WhoSaysMode.soundObjects(farm), [cow, pig, hen, horse, sheep, duck]);
  });

  test('is available from 5 distinct sounds', () {
    expect(WhoSaysMode.isAvailableIn(farm), isTrue);
    expect(WhoSaysMode.isAvailableIn([cow, pig, hen, horse, sheep]), isTrue);
    expect(WhoSaysMode.isAvailableIn([cow, cow2, pig, hen, horse, tree]), isFalse);
  });

  test('a round is the first 5 of the shuffled sound objects', () {
    List<SceneObject>? shuffled;
    final mode = WhoSaysMode(
      objects: farm,
      effects: FakeSceneModeEffects(),
      shuffle: (list) {
        shuffled = list;
        return list.reversed.toList();
      },
    );
    expect(shuffled, [cow, pig, hen, horse, sheep, duck]);
    expect(mode.roundLength, 5);
    expect(mode.currentTarget, duck);
  });

  test('a scene with fewer sounds than a round has them all in it', () {
    final mode = start(FakeSceneModeEffects(), objects: [cow, pig, tree]);
    expect(mode.roundLength, 2);
  });

  test('activate() plays the first sound, with the intro word', () {
    final effects = FakeSceneModeEffects();
    final mode = start(effects);
    expect(mode.currentTarget, cow);
    expect(effects.promptSoundCalls, [cow]);
    expect(effects.promptSoundAnnounceIntroCalls, [true]);
  });

  test('a wrong tap gives the hint with the sound again and does not advance', () async {
    final effects = FakeSceneModeEffects();
    final mode = start(effects);
    await answer(mode, tree);
    await answer(mode, pig);
    expect(effects.hintThenRepeatSoundCalls, [cow, cow]);
    expect(mode.currentTarget, cow);
    expect(effects.promptSoundCalls, [cow]);
    expect(effects.systemPhraseCalls, isEmpty);
  });

  test('a correct tap: the chime, the name without its sound, then the next sound', () async {
    final effects = FakeSceneModeEffects();
    final mode = start(effects);
    await answer(mode, cow);
    expect(effects.systemPhraseCalls, [SystemPhrase.correct]);
    expect(effects.announceObjectCalls, [cow]);
    expect(effects.announceObjectWithSoundCalls, [false]);
    expect(mode.currentTarget, pig);
    expect(effects.promptSoundCalls, [cow, pig]);
    expect(effects.promptSoundAnnounceIntroCalls, [true, false]);
  });

  test('another one with the same label counts as the right answer', () async {
    final effects = FakeSceneModeEffects();
    final mode = start(effects);
    await answer(mode, cow2);
    expect(mode.currentTarget, pig);
    expect(effects.hintThenRepeatSoundCalls, isEmpty);
  });

  test('while the right answer is being named, taps and repeats are ignored', () async {
    final effects = FakeSceneModeEffects()..announcementGate = Completer<void>();
    final mode = start(effects);
    await answer(mode, cow);
    await answer(mode, tree);
    mode.repeatSound();
    expect(effects.hintThenRepeatSoundCalls, isEmpty);
    expect(effects.promptSoundCalls, [cow]);

    effects.announcementGate!.complete();
    await Future<void>.delayed(Duration.zero);
    expect(effects.promptSoundCalls, [cow, pig]);
  });

  test('repeatSound() plays the current sound again, without the intro word', () {
    final effects = FakeSceneModeEffects();
    final mode = start(effects);
    mode.repeatSound();
    expect(effects.promptSoundCalls, [cow, cow]);
    expect(effects.promptSoundAnnounceIntroCalls, [true, false]);
  });

  test('the fifth right answer ends the round with the fanfare', () async {
    final effects = FakeSceneModeEffects();
    final mode = start(effects);
    for (final animal in [cow, pig, hen, horse, sheep]) {
      await answer(mode, animal);
    }
    expect(effects.systemPhraseCalls, [
      SystemPhrase.correct,
      SystemPhrase.correct,
      SystemPhrase.correct,
      SystemPhrase.correct,
      SystemPhrase.correct,
      SystemPhrase.roundComplete,
    ]);
    expect(effects.roundCompletedCalls, 1);
    expect(mode.isComplete, isTrue);
    expect(mode.currentTarget, isNull);
    expect(effects.promptSoundCalls, [cow, pig, hen, horse, sheep]);

    await answer(mode, duck);
    mode.repeatSound();
    expect(effects.hintThenRepeatSoundCalls, isEmpty);
    expect(effects.promptSoundCalls, hasLength(5));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/domain/modes/who_says_mode_test.dart`
Expected: FAIL — `who_says_mode.dart` does not exist.

- [ ] **Step 3: Implement**

Create `lib/domain/modes/who_says_mode.dart`:

```dart
import 'dart:async';

import '../models/scene_object.dart';
import 'find_mode.dart' show shuffleFindOrder;
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// «Кто это?» — Find mode by ear. The child hears the sound a thing makes
/// (a cow's moo, a tractor's rattle) and taps whoever or whatever makes it;
/// the right answer is named, so the sound and the word come together.
///
/// Only objects with a sound of their own take part, one per label (like
/// in Find mode, several cows are one thing to find and tapping any of
/// them counts). A round is a few of them — a toddler's attention runs out
/// long before a farm's ten sounds do — picked afresh for every round (a
/// new round is a new instance, see `SceneController.setMode`).
class WhoSaysMode implements SceneMode {
  /// [shuffle] orders the sound objects before the round takes the first
  /// [roundSize] of them; tests pass a fixed order.
  WhoSaysMode({
    required List<SceneObject> objects,
    required this.effects,
    List<SceneObject> Function(List<SceneObject>) shuffle = shuffleFindOrder,
  }) : _targets = List.unmodifiable(shuffle(soundObjects(objects)).take(roundSize)) {
    assert(_targets.isNotEmpty, 'WhoSaysMode requires at least one object with a sound');
  }

  /// How many distinct sounds a scene needs for this game to be offered:
  /// with fewer, guessing is too easy for it to be a game.
  static const int minSounds = 5;

  /// How many sounds one round asks for.
  static const int roundSize = 5;

  /// The objects with a sound of their own, one per label, in scene order.
  static List<SceneObject> soundObjects(List<SceneObject> objects) {
    final seenLabels = <String>{};
    return [
      for (final object in objects)
        if (object.sound != null && seenLabels.add(object.label)) object,
    ];
  }

  /// Whether a scene with these objects offers the game.
  static bool isAvailableIn(List<SceneObject> objects) => soundObjects(objects).length >= minSounds;

  final SceneModeEffects effects;
  final List<SceneObject> _targets;

  int _foundCount = 0;
  bool _waitingForCorrectFeedback = false;

  /// How many sounds this round asks for.
  int get roundLength => _targets.length;

  /// Whether every sound of the round has been found.
  bool get isComplete => _foundCount == _targets.length;

  /// The object whose sound is to be found, or null once the round is over.
  SceneObject? get currentTarget => isComplete ? null : _targets[_foundCount];

  @override
  void activate() {
    _foundCount = 0;
    _waitingForCorrectFeedback = false;
    effects.promptSound(_targets.first); // first of the round: with "Где"
  }

  @override
  void onObjectTapped(SceneObject object) {
    if (_waitingForCorrectFeedback) return;
    final target = currentTarget;
    if (target == null) return;

    if (object.label != target.label) {
      effects.hintThenRepeatSound(target);
      return;
    }
    _waitingForCorrectFeedback = true;
    unawaited(_advanceAfterCorrectAnswer(target));
  }

  /// Plays the current sound once more (the repeat button). Does nothing
  /// while a right answer is being named or once the round is over.
  void repeatSound() {
    if (_waitingForCorrectFeedback) return;
    final target = currentTarget;
    if (target == null) return;
    effects.promptSound(target, announceIntro: false);
  }

  Future<void> _advanceAfterCorrectAnswer(SceneObject found) async {
    await effects.playSystemPhrase(SystemPhrase.correct);
    // The name alone: its sound right after would run into the next one.
    await effects.announceObject(found, withSound: false);
    _foundCount++;

    if (isComplete) {
      await effects.playSystemPhrase(SystemPhrase.roundComplete);
      effects.onRoundCompleted();
    } else {
      effects.promptSound(_targets[_foundCount], announceIntro: false);
    }
    _waitingForCorrectFeedback = false;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/domain/modes/who_says_mode_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/modes/who_says_mode.dart test/domain/modes/who_says_mode_test.dart
git commit -m "feat: WhoSaysMode — find by sound"
```

---

### Task 3: Wire `WhoSaysMode` into `SceneController`

**Files:**
- Modify: `lib/presentation/controllers/scene_controller.dart`
- Test: `test/presentation/controllers/scene_controller_test.dart`

**Interfaces:**
- Consumes: `WhoSaysMode` (Task 2).
- Produces: `SceneModeType.whoSays`; ctor param `whoSaysShuffle` (default `shuffleFindOrder`); `bool get hasWhoSays`; `WhoSaysMode? get whoSays`; `void repeatWhoSaysSound()`.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/presentation/controllers/scene_controller_test.dart`:

```dart
  group('find by sound', () {
    SceneObject animal(String id, String label) =>
        SceneObject(id: id, label: label, audio: '$id.wav', rect: rect, sound: '${id}_sound.wav');
    final cow = animal('cow', 'Корова');
    final pig = animal('pig', 'Свинья');
    final hen = animal('hen', 'Курица');
    final horse = animal('horse', 'Лошадь');
    final sheep = animal('sheep', 'Овца');
    final farm = CachedScene(
      scene: Scene(
        id: 'farm',
        version: 1,
        title: 'Ферма',
        minAgeMonths: 12,
        background: 'background.png',
        objects: [cow, ball, pig, hen, horse, sheep],
      ),
      directoryPath: '/cache/farm',
    );
    SceneController farmController(FakeAudioSink audio) => SceneController(
          cachedScene: farm,
          audioSink: audio,
          whoSaysShuffle: (list) => list,
        );

    test('is offered where the scene has 5 distinct sounds', () {
      expect(farmController(FakeAudioSink()).hasWhoSays, isTrue);
      expect(SceneController(cachedScene: cachedScene, audioSink: FakeAudioSink()).hasWhoSays, isFalse);
    });

    test('cannot be switched on in a scene that does not offer it', () {
      final controller = SceneController(cachedScene: cachedScene, audioSink: FakeAudioSink());
      controller.setMode(SceneModeType.whoSays);
      expect(controller.modeType, SceneModeType.explore);
      expect(controller.whoSays, isNull);
    });

    test('switching it on says «Где» and the first sound; the repeat button plays it again', () async {
      final audio = FakeAudioSink();
      final controller = farmController(audio);
      controller.setMode(SceneModeType.whoSays);
      expect(controller.whoSays, isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedSequences, [(SystemPhrase.findIntro, farm.soundPathFor(cow)!)]);

      controller.repeatWhoSaysSound();
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [farm.soundPathFor(cow)!]);
    });

    test('a wrong tap: the hint, then the sound again', () async {
      final audio = FakeAudioSink();
      final controller = farmController(audio)..setMode(SceneModeType.whoSays);
      controller.onObjectTapped(ball);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedInterruptibleSystemPhrases, [SystemPhrase.wrongHint]);
      expect(audio.playedFiles, [farm.soundPathFor(cow)!]);
    });

    test('a right tap names the object without its sound, then plays the next one', () async {
      final audio = FakeAudioSink();
      final controller = farmController(audio)..setMode(SceneModeType.whoSays);
      controller.onObjectTapped(cow);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(audio.playedSystemPhrases, [SystemPhrase.correct]);
      expect(audio.playedFiles, [farm.audioPathFor(cow), farm.soundPathFor(pig)!]);
      expect(controller.whoSays!.currentTarget, pig);
    });

    test('five right taps end in the congratulations', () async {
      final audio = FakeAudioSink();
      final controller = farmController(audio)..setMode(SceneModeType.whoSays);
      for (final object in [cow, pig, hen, horse, sheep]) {
        controller.onObjectTapped(object);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      expect(audio.playedSystemPhrases.last, SystemPhrase.roundComplete);
      expect(controller.showCongrats, isTrue);
      // The return to Explore after the congratulations is the same timer
      // as for a Find round, covered by the Find tests.
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/controllers/scene_controller_test.dart`
Expected: compile errors — no `whoSaysShuffle`, `hasWhoSays`, `SceneModeType.whoSays`.

- [ ] **Step 3: Implement**

In `lib/presentation/controllers/scene_controller.dart`:

a) Import `'../../domain/modes/who_says_mode.dart';` and change the enum:

```dart
enum SceneModeType { explore, find, flashlight, whoSays }
```

b) Constructor gets `this.whoSaysShuffle = shuffleFindOrder,` after `this.findModeShuffle = shuffleFindOrder,`, with the field:

```dart
  // Passed straight through to WhoSaysMode, for the same reason as
  // [findModeShuffle].
  final List<SceneObject> Function(List<SceneObject>) whoSaysShuffle;
```

c) After the `flashlight` getter, add:

```dart
  /// Whether this scene offers finding by sound: it does when it has
  /// enough distinct sounds (see [WhoSaysMode.minSounds]).
  bool get hasWhoSays => WhoSaysMode.isAvailableIn(cachedScene.scene.objects);

  /// The running find-by-sound game, or null in any other mode.
  WhoSaysMode? get whoSays => _mode is WhoSaysMode ? _mode as WhoSaysMode : null;

  /// Plays the sound to find once more (the repeat button).
  void repeatWhoSaysSound() => whoSays?.repeatSound();
```

d) In `setMode`, change the first line to

```dart
    if (type == _modeType || (type == SceneModeType.whoSays && !hasWhoSays)) return;
```

and add the switch arm:

```dart
      SceneModeType.whoSays => WhoSaysMode(objects: cachedScene.scene.objects, effects: this, shuffle: whoSaysShuffle),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/controllers/scene_controller_test.dart`
Expected: all PASS. (If a "right tap" test needs more event-loop turns, raise the loop count — the chain is voice queue → correct → name → next prompt.)

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/controllers/scene_controller.dart test/presentation/controllers/scene_controller_test.dart
git commit -m "feat: find-by-sound mode in SceneController"
```

---

### Task 4: Buttons on the scene screen

**Files:**
- Modify: `lib/presentation/screens/scene_screen.dart`
- Test: `test/presentation/screens/scene_screen_test.dart`

**Interfaces:**
- Consumes: `SceneController.hasWhoSays`, `.repeatWhoSaysSound()`, `SceneModeType.whoSays` (Task 3).
- Produces: widget keys `who_says_button`, `who_says_repeat` (existing: `flashlight_button`, `find_banner`, `mode_switch`).

- [ ] **Step 1: Write the failing widget tests**

In `test/presentation/screens/scene_screen_test.dart`, add a fixture after `_seedCacheWithRealisticPicture`:

```dart
// A farm-like scene: five animals with a sound of their own (enough for
// finding by sound), the first with an outline (so the flashlight is there
// too).
Future<Directory> _seedCacheWithSounds() async {
  final cacheRoot = await Directory.systemTemp.createTemp('yandee_scene_screen_sounds_test_');
  final sceneDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName, 'demo'));
  await sceneDir.create(recursive: true);
  await writeFixturePng(sceneDir, 'background.png', width: 400, height: 300);
  const animals = {'cow': 'Корова', 'pig': 'Свинья', 'hen': 'Курица', 'horse': 'Лошадь', 'duck': 'Утка'};
  final ids = animals.keys.toList();
  for (final id in ids) {
    await File(p.join(sceneDir.path, '$id.wav')).writeAsBytes([0]);
    await File(p.join(sceneDir.path, '${id}_sound.wav')).writeAsBytes([0]);
  }
  await File(p.join(sceneDir.path, 'scene.json')).writeAsString(jsonEncode({
    'id': 'demo',
    'version': 1,
    'title': 'Демо',
    'minAgeMonths': 12,
    'background': 'background.png',
    'objects': [
      for (var i = 0; i < ids.length; i++)
        {
          'id': ids[i],
          'label': animals[ids[i]],
          'audio': '${ids[i]}.wav',
          'sound': '${ids[i]}_sound.wav',
          'rect': {'x': 0.02 + i * 0.19, 'y': 0.4, 'width': 0.15, 'height': 0.15},
          if (i == 0)
            'outline': [
              [0.02, 0.4],
              [0.17, 0.4],
              [0.1, 0.55],
            ],
        },
    ],
  }));
  return cacheRoot;
}

// Opens the scene in [cacheRoot] and waits until it is on screen (see the
// first test for why all of this runs inside runAsync).
Future<void> _openScene(WidgetTester tester, Future<Directory> Function() seed, FakeAudioSink audio,
    void Function(Directory) onCacheRoot) async {
  await tester.runAsync(() async {
    final cacheRoot = await seed();
    onCacheRoot(cacheRoot);
    final repository = ContentRepository.local(cacheRootProvider: () async => cacheRoot);
    await tester.pumpWidget(MaterialApp(
      home: SceneScreen(contentRepository: repository, sceneId: 'demo', audioSinkFactory: () => audio),
    ));
    for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    }
  });
  await tester.pump();
}

// Like _pumpUntilFound, for a condition on what has been played.
Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20 && !condition(); i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}
```

and these tests at the end of `main()`:

```dart
  testWidgets('the flashlight button is in Explore only, the ear button in Find only', (tester) async {
    final audio = FakeAudioSink();
    await _openScene(tester, _seedCacheWithSounds, audio, (root) => addTearDown(() => root.delete(recursive: true)));

    expect(find.byKey(const ValueKey('flashlight_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('who_says_button')), findsNothing);

    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flashlight_button')), findsNothing);
    expect(find.byKey(const ValueKey('who_says_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
  });

  testWidgets('while the flashlight is on, Explore stays highlighted', (tester) async {
    final audio = FakeAudioSink();
    await _openScene(tester, _seedCacheWithSounds, audio, (root) => addTearDown(() => root.delete(recursive: true)));

    await tester.tap(find.byKey(const ValueKey('flashlight_button')));
    await tester.pump();
    expect(tester.widget<ToggleButtons>(find.byType(ToggleButtons)).isSelected, [true, false]);

    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
  });

  testWidgets('the ear button finds by sound: a repeat button instead of the name, Find highlighted', (tester) async {
    final audio = FakeAudioSink();
    await _openScene(tester, _seedCacheWithSounds, audio, (root) => addTearDown(() => root.delete(recursive: true)));
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('who_says_button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('find_banner')), findsNothing);
    expect(find.byKey(const ValueKey('who_says_repeat')), findsOneWidget);
    expect(tester.widget<ToggleButtons>(find.byType(ToggleButtons)).isSelected, [false, true]);
    for (final label in ['Корова', 'Свинья', 'Курица', 'Лошадь', 'Утка']) {
      expect(find.text(label), findsNothing, reason: 'the name would give the answer away');
    }

    bool introWithSound() => audio.playedSequences.any(
          (s) => s.$1 == SystemPhrase.findIntro && s.$2.endsWith('_sound.wav'),
        );
    await _pumpUntil(tester, introWithSound);
    expect(introWithSound(), isTrue);

    await tester.tap(find.byKey(const ValueKey('who_says_repeat')));
    await _pumpUntil(tester, () => audio.playedFiles.isNotEmpty);
    expect(audio.playedFiles.single, endsWith('_sound.wav'));

    await tester.tap(find.byKey(const ValueKey('who_says_button')));
    await tester.pump();
    expect(find.byKey(const ValueKey('find_banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('who_says_repeat')), findsNothing);
  });

  testWidgets('a scene with too few sounds has no ear button in Find', (tester) async {
    await _openScene(tester, _seedCache, FakeAudioSink(), (root) => addTearDown(() => root.delete(recursive: true)));
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('who_says_button')), findsNothing);
  });
```

Add `import 'package:yandee/domain/modes/scene_mode_effects.dart';` at the top for `SystemPhrase`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/presentation/screens/scene_screen_test.dart`
Expected: the four new tests FAIL (flashlight button still shown in Find; no `who_says_button`; highlighting `[false, false]` in flashlight).

- [ ] **Step 3: Implement**

In `lib/presentation/screens/scene_screen.dart`, `_SceneView.build`:

a) Replace `final showBanner = controller.modeType == SceneModeType.find && !controller.showCongrats;` with:

```dart
    final modeType = controller.modeType;
    // The flashlight is a way to explore and finding by sound a way to
    // find, so each one's button lives with its own half of the switch.
    final inFindFamily = modeType == SceneModeType.find || modeType == SceneModeType.whoSays;
    final showFlashlightButton = controller.hasFlashlight && !inFindFamily;
    final showWhoSaysButton = controller.hasWhoSays && inFindFamily;
    final showBanner = modeType == SceneModeType.find && !controller.showCongrats;
    final showRepeatButton = modeType == SceneModeType.whoSays && !controller.showCongrats;
```

b) The second-row condition becomes:

```dart
                  if (showBanner ||
                      showRepeatButton ||
                      controller.hasRealisticPicture ||
                      showFlashlightButton ||
                      showWhoSaysButton) ...[
```

c) In the second row, replace `if (controller.hasFlashlight) ...[` with `if (showFlashlightButton) ...[`, and after that block add:

```dart
                        if (showWhoSaysButton) ...[
                          _WhoSaysButton(
                            isOn: modeType == SceneModeType.whoSays,
                            onPressed: () => controller.setMode(
                              modeType == SceneModeType.whoSays ? SceneModeType.find : SceneModeType.whoSays,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
```

d) The right-hand child becomes:

```dart
                            child: showBanner
                                ? _FindBanner(target: controller.currentFindTarget)
                                : showRepeatButton
                                    ? _RepeatSoundButton(onPressed: controller.repeatWhoSaysSound)
                                    : flashlight != null
                                        ? _FlashlightStars(found: flashlight.foundCount, total: flashlight.totalCount)
                                        : const SizedBox.shrink(),
```

e) In `_ModeSwitch`, `isSelected` becomes:

```dart
        // The flashlight belongs with Explore and finding by sound with
        // Find; tapping either half starts that half's plain mode.
        isSelected: [
          modeType == SceneModeType.explore || modeType == SceneModeType.flashlight,
          modeType == SceneModeType.find || modeType == SceneModeType.whoSays,
        ],
```

f) Add the two widgets after `_FlashlightButton`:

```dart
/// Switches Find mode between finding by name and finding by sound.
/// Wordless, like the flashlight button: an ear on a round button.
class _WhoSaysButton extends StatelessWidget {
  const _WhoSaysButton({required this.isOn, required this.onPressed});

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isOn ? 'Искать по названию' : 'Кто это? Искать по голосу',
      child: Material(
        key: const ValueKey('who_says_button'),
        color: isOn ? colorScheme.primary : Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.hearing, color: isOn ? Colors.white : colorScheme.primary, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Plays the sound to find once more. Stands where Find mode shows the
/// name — which, here, would give the answer away.
class _RepeatSoundButton extends StatelessWidget {
  const _RepeatSoundButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Послушать ещё раз',
      child: Material(
        key: const ValueKey('who_says_repeat'),
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(Icons.volume_up_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/presentation/screens/scene_screen_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/scene_screen.dart test/presentation/screens/scene_screen_test.dart
git commit -m "feat: ear and repeat buttons for finding by sound"
```

---

### Task 5: Full verification

- [ ] **Step 1:** `flutter analyze` — expected: `No issues found!`
- [ ] **Step 2:** `flutter test` — expected: all tests pass.
- [ ] **Step 3:** Add to `test/data/bundled_scenes_test.dart` (it reads every `assets/demo_content/*/scene.json` with `readScene(dir)` over `sceneDirs`), after the `there are bundled scenes to check` test, with `import 'package:yandee/domain/modes/who_says_mode.dart';`:

```dart
  test('finding by sound is offered on the farm and in the zoo', () {
    final offered = {
      for (final dir in sceneDirs)
        if (WhoSaysMode.isAvailableIn(readScene(dir).objects)) p.basename(dir.path),
    };
    // At least these two: other scenes get it too once they have enough
    // sounds (new scenes are being added in parallel), with no code change.
    expect(offered, containsAll(['farm', 'zoo']));
    expect(offered, isNot(contains('forest')), reason: '4 sounds are below the threshold');
  });
```

Run: `flutter test test/data/bundled_scenes_test.dart` — expected PASS.
- [ ] **Step 4:** Commit:

```bash
git add test/data/bundled_scenes_test.dart
git commit -m "test: finding by sound on the bundled scenes"
```
