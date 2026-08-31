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

  test('activate() prompts the first object, with the intro word', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects, shuffle: (list) => list)..activate();
    expect(mode.currentTarget, ball);
    expect(effects.promptFindCalls, [ball]);
    expect(effects.promptFindAnnounceIntroCalls, [true]);
  });

  test('wrong tap gives a hint and does not advance', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects, shuffle: (list) => list)..activate();
    mode.onObjectTapped(cat);
    expect(effects.systemPhraseCalls, [SystemPhrase.wrongHint]);
    expect(mode.currentTarget, ball);
    expect(effects.promptFindCalls, [ball]); // no new prompt
  });

  test('correct tap on a non-final target advances to the next object, without the intro word', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects, shuffle: (list) => list)..activate();
    mode.onObjectTapped(ball);
    expect(effects.systemPhraseCalls, [SystemPhrase.correct]);
    expect(mode.currentTarget, cat);
    expect(effects.promptFindCalls, [ball, cat]);
    expect(effects.promptFindAnnounceIntroCalls, [true, false]);
    expect(effects.roundCompletedCalls, 0);
  });

  test('finding the last object plays the fanfare and completes the round', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: objects, effects: effects, shuffle: (list) => list)..activate();
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
    final mode = FindMode(objects: objects, effects: effects, shuffle: (list) => list)..activate();
    mode.onObjectTapped(ball);
    mode.onObjectTapped(cat);
    mode.onObjectTapped(tree);
    effects.systemPhraseCalls.clear();
    mode.onObjectTapped(ball);
    expect(effects.systemPhraseCalls, isEmpty);
  });

  test('orders the round using the injected shuffle', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(
      objects: objects,
      effects: effects,
      shuffle: (list) => list.reversed.toList(),
    )..activate();

    expect(mode.currentTarget, tree);
    expect(effects.promptFindCalls, [tree]);
  });

  test('defaults to shuffling the round order instead of always using scene order', () {
    // Not a statistical proof — a real Random() could in principle produce
    // the identity permutation — but with 3! = 6 equally likely orderings,
    // 200 independent rounds landing on the exact input order every single
    // time has probability (1/6)^200, i.e. this only fails from an actual
    // regression (shuffle silently turned into a no-op), never from bad luck.
    final sawNonIdentityOrder = List.generate(200, (_) {
      final effects = FakeSceneModeEffects();
      FindMode(objects: objects, effects: effects).activate();
      return effects.promptFindCalls;
    }).any((calls) => calls.single != ball);

    expect(sawNonIdentityOrder, isTrue);
  });

  test('a scene with exactly one object completes on the first correct tap', () {
    final effects = FakeSceneModeEffects();
    final mode = FindMode(objects: [ball], effects: effects, shuffle: (list) => list)..activate();

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

  group('multiple objects sharing one label (e.g. 3 houses drawn in a scene)', () {
    const house1 = SceneObject(id: 'house', label: 'Дом', audio: 'house.wav', rect: rect);
    const house2 = SceneObject(id: 'house_2', label: 'Дом', audio: 'house.wav', rect: rect);
    const house3 = SceneObject(id: 'house_3', label: 'Дом', audio: 'house.wav', rect: rect);
    final objectsWithDuplicates = [house1, house2, house3, cat];

    test('collapses same-label objects into a single target, asked once', () {
      final effects = FakeSceneModeEffects();
      final mode = FindMode(objects: objectsWithDuplicates, effects: effects, shuffle: (list) => list)..activate();
      expect(mode.currentTarget, house1);
      expect(effects.promptFindCalls, [house1]); // not asked 3 times for the 3 houses
    });

    test('tapping any instance of the target label counts as correct, not just the first one', () {
      final effects = FakeSceneModeEffects();
      final mode = FindMode(objects: objectsWithDuplicates, effects: effects, shuffle: (list) => list)..activate();
      mode.onObjectTapped(house3); // a different instance than currentTarget (house1)
      expect(effects.systemPhraseCalls, [SystemPhrase.correct]);
      expect(mode.currentTarget, cat);
    });

    test('a wrong tap on an unrelated object still gives the hint', () {
      final effects = FakeSceneModeEffects();
      final mode = FindMode(objects: objectsWithDuplicates, effects: effects, shuffle: (list) => list)..activate();
      mode.onObjectTapped(cat);
      expect(effects.systemPhraseCalls, [SystemPhrase.wrongHint]);
      expect(mode.currentTarget, house1);
    });

    test('the round only has as many targets as distinct labels', () {
      final effects = FakeSceneModeEffects();
      final mode = FindMode(objects: objectsWithDuplicates, effects: effects, shuffle: (list) => list)..activate();
      mode.onObjectTapped(house1);
      expect(mode.currentTarget, cat);
      mode.onObjectTapped(cat);
      expect(effects.roundCompletedCalls, 1); // 2 targets (Дом, Кот), not 4 objects
    });
  });
}
