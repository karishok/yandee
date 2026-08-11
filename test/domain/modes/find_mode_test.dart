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

  test('a scene with exactly one object completes on the first correct tap', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: [ball], effects: effects)..activate();

    expect(mode.currentTarget, ball);
    expect(effects.promptFindCalls, [ball]);

    mode.onObjectTapped(ball);

    expect(
      effects.systemPhraseCalls,
      [SystemPhrase.correct, SystemPhrase.roundComplete],
    );
    expect(effects.roundCompletedCalls, 1);
    expect(mode.currentTarget, isNull);
    expect(effects.promptFindCalls, [ball]); // no second prompt was ever issued
  });
}
