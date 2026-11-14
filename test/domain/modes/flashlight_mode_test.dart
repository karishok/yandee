import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_outline.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/flashlight_mode.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

import '../../support/fake_scene_mode_effects.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const outline = ObjectOutline([(x: 0, y: 0), (x: 0.1, y: 0), (x: 0.05, y: 0.1)]);
  const fox = SceneObject(id: 'fox', label: 'Лиса', audio: 'fox.wav', rect: rect, outline: outline);
  const hare1 = SceneObject(id: 'hare_1', label: 'Заяц', audio: 'hare.wav', rect: rect, outline: outline);
  const hare2 = SceneObject(id: 'hare_2', label: 'Заяц', audio: 'hare.wav', rect: rect, outline: outline);
  const bear = SceneObject(id: 'bear', label: 'Медведь', audio: 'bear.wav', rect: rect, outline: outline);
  // Scenery: no outline, so not something to find.
  const tree = SceneObject(id: 'tree', label: 'Дерево', audio: 'tree.wav', rect: rect);
  final objects = [fox, tree, hare1, hare2, bear];

  test('counts things to find by label, starting with none found', () {
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    expect(mode.totalCount, 3);
    expect(mode.foundCount, 0);
    expect(mode.isComplete, isFalse);
    expect(mode.isFound(fox), isFalse);
  });

  test('only objects with an outline are things to find', () {
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    expect(mode.isTarget(fox), isTrue);
    expect(mode.isTarget(tree), isFalse);
  });

  test('an object is a target on any picture, outline or not', () {
    // The realistic picture may have no outline marked up for it.
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    expect(mode.isTarget(fox.placedAt(rect: rect, outline: null)), isTrue);
  });

  test('lighting a target finds it and says its name', () {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(fox);
    expect(mode.isFound(fox), isTrue);
    expect(mode.foundCount, 1);
    expect(effects.objectAudioCalls, [fox]);
  });

  test('lighting anything else does nothing at all', () {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(tree);
    expect(mode.foundCount, 0);
    expect(mode.isFound(tree), isFalse);
    expect(effects.objectAudioCalls, isEmpty);
    expect(effects.announceObjectCalls, isEmpty);
  });

  test('lighting one instance lights every instance with that label', () {
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    mode.onObjectTapped(hare2);
    expect(mode.isFound(hare1), isTrue);
    expect(mode.foundCount, 1);
  });

  test('lighting a found target again asks for its name again without counting twice', () {
    // Whether it is actually said is up to the effects: a name being said
    // is never cut off, and only the latest one asked for meanwhile follows.
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(hare1);
    mode.onObjectTapped(hare2);
    expect(mode.foundCount, 1);
    expect(effects.objectAudioCalls, [hare1, hare2]);
  });

  test('finding the last target says its name, plays the fanfare, then completes the round', () async {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(fox);
    mode.onObjectTapped(hare1);
    mode.onObjectTapped(bear);
    expect(mode.isComplete, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(effects.objectAudioCalls, [fox, hare1]);
    expect(effects.announceObjectCalls, [bear]);
    expect(effects.systemPhraseCalls, [SystemPhrase.roundComplete]);
    expect(effects.roundCompletedCalls, 1);
  });

  test('the fanfare waits for the last name to be said', () async {
    final gate = Completer<void>();
    final effects = FakeSceneModeEffects()..announcementGate = gate;
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(fox);
    mode.onObjectTapped(hare1);
    mode.onObjectTapped(bear);
    await Future<void>.delayed(Duration.zero);
    expect(effects.announceObjectCalls, [bear]);
    expect(effects.systemPhraseCalls, isEmpty);
    expect(effects.roundCompletedCalls, 0);

    gate.complete();
    await Future<void>.delayed(Duration.zero);
    expect(effects.systemPhraseCalls, [SystemPhrase.roundComplete]);
    expect(effects.roundCompletedCalls, 1);
  });

  test('taps after the lights are on are ignored', () async {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    for (final object in objects) {
      mode.onObjectTapped(object);
    }
    await Future<void>.delayed(Duration.zero);
    effects.objectAudioCalls.clear();
    effects.announceObjectCalls.clear();
    mode.onObjectTapped(fox);
    expect(effects.objectAudioCalls, isEmpty);
    expect(effects.announceObjectCalls, isEmpty);
    expect(effects.roundCompletedCalls, 1);
  });
}
