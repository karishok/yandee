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
