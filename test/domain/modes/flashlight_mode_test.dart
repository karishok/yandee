import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/flashlight_mode.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

import '../../support/fake_scene_mode_effects.dart';

void main() {
  const rect = ObjectRect(x: 0, y: 0, width: 0.1, height: 0.1);
  const fox = SceneObject(id: 'fox', label: 'Лиса', audio: 'fox.wav', rect: rect);
  const tree1 = SceneObject(id: 'tree_1', label: 'Дерево', audio: 'tree.wav', rect: rect);
  const tree2 = SceneObject(id: 'tree_2', label: 'Дерево', audio: 'tree.wav', rect: rect);
  const bear = SceneObject(id: 'bear', label: 'Медведь', audio: 'bear.wav', rect: rect);
  final objects = [fox, tree1, tree2, bear];

  test('counts things to find by label, starting with none found', () {
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    expect(mode.totalCount, 3);
    expect(mode.foundCount, 0);
    expect(mode.isComplete, isFalse);
    expect(mode.isFound(fox), isFalse);
  });

  test('lighting an object finds it and says its name', () {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(fox);
    expect(mode.isFound(fox), isTrue);
    expect(mode.foundCount, 1);
    expect(effects.objectAudioCalls, [fox]);
  });

  test('lighting one instance lights every instance with that label', () {
    final mode = FlashlightMode(objects: objects, effects: FakeSceneModeEffects())..activate();
    mode.onObjectTapped(tree2);
    expect(mode.isFound(tree1), isTrue);
    expect(mode.foundCount, 1);
  });

  test('lighting a found object again repeats its name without counting twice', () {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(tree1);
    mode.onObjectTapped(tree2);
    expect(mode.foundCount, 1);
    expect(effects.objectAudioCalls, [tree1, tree2]);
  });

  test('finding the last thing says its name, plays the fanfare, then completes the round', () async {
    final effects = FakeSceneModeEffects();
    final mode = FlashlightMode(objects: objects, effects: effects)..activate();
    mode.onObjectTapped(fox);
    mode.onObjectTapped(tree1);
    mode.onObjectTapped(bear);
    expect(mode.isComplete, isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(effects.objectAudioCalls, [fox, tree1]);
    expect(effects.announceObjectCalls, [bear]);
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
    mode.onObjectTapped(fox);
    expect(effects.objectAudioCalls, isEmpty);
    expect(effects.roundCompletedCalls, 1);
  });
}
