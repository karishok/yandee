import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/data/cached_scene.dart';
import 'package:yandee/domain/models/object_outline.dart';
import 'package:yandee/domain/models/object_rect.dart';
import 'package:yandee/domain/models/scene.dart';
import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/models/scene_variant.dart';
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

  test('a name being said is said to its end; of those asked for meanwhile only the last follows', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    final ballPath = cachedScene.audioPathFor(ball);
    final catPath = cachedScene.audioPathFor(cat);
    audio.holdFile(ballPath);

    controller.onObjectTapped(ball);
    controller.onObjectTapped(cat);
    controller.onObjectTapped(ball);
    controller.onObjectTapped(cat);

    expect(audio.playedFiles, [ballPath]);

    audio.releaseFile(ballPath);
    await Future<void>.delayed(Duration.zero);

    expect(audio.playedFiles, [ballPath, catPath]);
  });

  test('a name asked for and then overtaken by a later one is skipped, not said late', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    final ballPath = cachedScene.audioPathFor(ball);
    final catPath = cachedScene.audioPathFor(cat);
    audio.holdFile(ballPath);
    audio.holdFile(catPath);
    controller.onObjectTapped(ball); // being said

    var firstCatDone = false;
    var secondBallDone = false;
    var lastCatDone = false;
    unawaited(controller.announceObject(cat).then((_) => firstCatDone = true));
    unawaited(controller.announceObject(ball).then((_) => secondBallDone = true));
    unawaited(controller.announceObject(cat).then((_) => lastCatDone = true));
    await Future<void>.delayed(Duration.zero);

    // The two that were overtaken are over with already — nothing waits on
    // a name that will never be said — while the last one is still to come.
    expect(firstCatDone, isTrue);
    expect(secondBallDone, isTrue);
    expect(lastCatDone, isFalse);
    expect(audio.playedFiles, [ballPath]);

    audio.releaseFile(ballPath);
    await Future<void>.delayed(Duration.zero);
    expect(audio.playedFiles, [ballPath, catPath]);
    expect(lastCatDone, isFalse, reason: 'it is only done once it has been said to its end');

    audio.releaseFile(catPath);
    await Future<void>.delayed(Duration.zero);
    expect(lastCatDone, isTrue);
  });

  group('an object with a sound of its own', () {
    const cow = SceneObject(id: 'cow', label: 'Корова', audio: 'cow.wav', sound: 'cow_sound.wav', rect: rect);
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
    final namePath = farm.audioPathFor(cow);
    final soundPath = farm.soundPathFor(cow)!;

    test('makes its sound right after its name', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      audio.holdFile(namePath);

      controller.onObjectTapped(cow);
      expect(audio.playedFiles, [namePath], reason: 'the sound waits for the name to end');

      audio.releaseFile(namePath);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [namePath, soundPath]);
    });

    test('skips its sound when another name was asked for during its name', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      audio.holdFile(namePath);

      controller.onObjectTapped(cow);
      controller.onObjectTapped(ball);
      audio.releaseFile(namePath);
      await Future<void>.delayed(Duration.zero);

      expect(audio.playedFiles, [namePath, farm.audioPathFor(ball)]);
    });

    test('is only announced once its sound is over too', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio);
      audio.holdFile(soundPath);

      var done = false;
      unawaited(controller.announceObject(cow).then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [namePath, soundPath]);
      expect(done, isFalse);

      audio.releaseFile(soundPath);
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('find mode asks for it by name only', () {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: farm, audioSink: audio, findModeShuffle: (list) => list);
      controller.setMode(SceneModeType.find);
      expect(audio.playedFiles, isNot(contains(soundPath)));
    });
  });

  test('a name still waiting its turn is not said after the scene is closed', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    final ballPath = cachedScene.audioPathFor(ball);
    audio.holdFile(ballPath);
    controller.onObjectTapped(ball);
    controller.onObjectTapped(cat);

    controller.dispose();
    audio.releaseFile(ballPath);
    await Future<void>.delayed(Duration.zero);

    expect(audio.playedFiles, [ballPath]);
  });

  test('switching to find mode prompts the first object', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    expect(controller.modeType, SceneModeType.find);
    expect(controller.currentFindTarget, ball);

    // The prompt is dispatched through the voice queue, so it lands on the
    // sink a microtask after being requested rather than synchronously.
    await Future<void>.delayed(Duration.zero);
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);
  });

  test('passes findModeShuffle through to the FindMode it creates', () {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list.reversed.toList(),
    );
    controller.setMode(SceneModeType.find);
    expect(controller.currentFindTarget, cat);
  });

  test('find mode: the "correct" phrase finishes before the next find prompt starts', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero); // let the first find prompt land

    audio.holdPhrase(SystemPhrase.correct);

    controller.onObjectTapped(ball); // correct, advances target to cat
    await Future<void>.delayed(Duration.zero);

    // "correct" has started playing but hasn't finished — the next find
    // prompt must not have been dispatched to the sink yet.
    expect(audio.playedSystemPhrases, [SystemPhrase.correct]);
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);
    expect(audio.playedFiles, isEmpty);

    audio.releasePhrase(SystemPhrase.correct);
    await Future<void>.delayed(Duration.zero);

    // The second (and every later) target in a round plays its name
    // directly — no repeated "Где" intro.
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);
    expect(audio.playedFiles, [cachedScene.audioPathFor(cat)]);
  });

  test('find mode keeps the current target until the correct phrase finishes', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero);

    audio.holdPhrase(SystemPhrase.correct);
    controller.onObjectTapped(ball);
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentFindTarget, ball);

    audio.releasePhrase(SystemPhrase.correct);
    await Future<void>.delayed(Duration.zero);

    expect(controller.currentFindTarget, cat);
  });

  test('find mode does not repeat a wrong hint while it is still playing', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero);

    audio.holdInterruptiblePhrase(SystemPhrase.wrongHint);
    controller.onObjectTapped(cat);
    controller.onObjectTapped(cat);
    controller.onObjectTapped(cat);

    expect(audio.playedInterruptibleSystemPhrases, [SystemPhrase.wrongHint]);

    audio.releaseInterruptiblePhrase(SystemPhrase.wrongHint);
    await Future<void>.delayed(Duration.zero);
    controller.onObjectTapped(cat);

    expect(audio.playedInterruptibleSystemPhrases, [SystemPhrase.wrongHint, SystemPhrase.wrongHint]);
  });

  test('a correct tap while the previous "correct" phrase is still playing does not repeat it', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero); // let the first find prompt land (ball)

    audio.holdPhrase(SystemPhrase.correct);

    controller.onObjectTapped(ball); // correct: queues "correct", starts playing (held)
    await Future<void>.delayed(Duration.zero);
    expect(audio.playedSystemPhrases, [SystemPhrase.correct]);

    // The target is still ball while "Молодец" is playing, so this tap is
    // ignored instead of advancing behind the audio.
    controller.onObjectTapped(cat);
    await Future<void>.delayed(Duration.zero);

    // Still only the one "correct" in flight: the second was dropped, not
    // queued up behind it.
    expect(audio.playedSystemPhrases, [SystemPhrase.correct]);

    audio.releasePhrase(SystemPhrase.correct);
    await Future<void>.delayed(Duration.zero);

    expect(audio.playedSystemPhrases, [SystemPhrase.correct]);
    expect(controller.showCongrats, isFalse);

    controller.onObjectTapped(cat);
    await Future<void>.delayed(Duration.zero);
    expect(audio.playedSystemPhrases, [SystemPhrase.correct, SystemPhrase.correct, SystemPhrase.roundComplete]);
    expect(controller.showCongrats, isTrue);
  });

  test('completing a find round shows congrats then reverts to explore', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      congratsDuration: const Duration(milliseconds: 5),
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    controller.onObjectTapped(ball);
    await Future<void>.delayed(Duration.zero);
    controller.onObjectTapped(cat);
    await Future<void>.delayed(Duration.zero);

    expect(controller.showCongrats, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(audio.playedSystemPhrases, contains(SystemPhrase.roundComplete));

    expect(controller.showCongrats, isFalse);
    expect(controller.modeType, SceneModeType.explore);
  });

  test('wrong-hint prompts go through the interruptible path, not the serialized voice queue', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero); // let the first find prompt land

    // Mistapping repeatedly and quickly must not restart the same phrase
    // while it is still playing.
    controller.onObjectTapped(cat); // wrong: target is ball
    controller.onObjectTapped(cat); // wrong again, immediately
    controller.onObjectTapped(cat); // and again
    await Future<void>.delayed(Duration.zero);

    expect(
      audio.playedInterruptibleSystemPhrases,
      [SystemPhrase.wrongHint],
    );
    expect(audio.playedSystemPhrases, isEmpty); // never touches the serialized queue
  });

  test('a correct tap cuts off a wrong-hint that is still playing', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero);

    controller.onObjectTapped(cat); // wrong: target is ball
    expect(audio.playedInterruptibleSystemPhrases, [SystemPhrase.wrongHint]);
    expect(audio.stopInterruptibleCalls, 0);

    // "Попробуй ещё раз" is still going when the child gets it right. It has
    // to stop then and there — the hint is about to become wrong, and it
    // would otherwise drone on underneath the success chime.
    controller.onObjectTapped(ball);
    expect(audio.stopInterruptibleCalls, 1);
  });

  test('the hint is cut immediately, not after the voice queue drains', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(
      cachedScene: cachedScene,
      audioSink: audio,
      findModeShuffle: (list) => list,
    );
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero);

    // Wedge the voice queue: the success chime can't start until this
    // resolves. The stop must not be waiting behind it — "quickly" is the
    // whole point, and a queued stop would land seconds late.
    audio.holdPhrase(SystemPhrase.correct);
    controller.onObjectTapped(cat); // wrong
    controller.onObjectTapped(ball); // correct

    expect(audio.stopInterruptibleCalls, 1);
    expect(audio.playedSystemPhrases, isEmpty); // chime hasn't even started yet

    audio.releasePhrase(SystemPhrase.correct);
  });

  test('setMode with the current type is a no-op', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.setMode(SceneModeType.explore);
    expect(notifications, 0);
  });

  test('dispose releases the audio sink', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    expect(audio.disposeCalled, isFalse);
    controller.dispose();
    expect(audio.disposeCalled, isTrue);
  });

  group('realistic picture', () {
    const realisticBallRect = ObjectRect(x: 0.6, y: 0.6, width: 0.2, height: 0.2);
    final sceneWithRealistic = CachedScene(
      scene: Scene(
        id: 'demo',
        version: 1,
        title: 'Демо',
        minAgeMonths: 12,
        background: 'background.png',
        objects: [ball, cat],
        realistic: const SceneVariant(
          background: 'background_real.png',
          rects: {'ball': realisticBallRect},
        ),
      ),
      directoryPath: '/cache/demo',
    );

    test('a scene opens on its default picture', () {
      final controller = SceneController(cachedScene: sceneWithRealistic, audioSink: FakeAudioSink());
      expect(controller.hasRealisticPicture, isTrue);
      expect(controller.showsRealisticPicture, isFalse);
      expect(controller.visibleBackgroundPath, '/cache/demo/background.png');
      expect(controller.visibleObjects.first.rect, rect);
    });

    test('togglePicture switches to the realistic picture and its tap zones, then back', () {
      final controller = SceneController(cachedScene: sceneWithRealistic, audioSink: FakeAudioSink());
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.togglePicture();
      expect(controller.showsRealisticPicture, isTrue);
      expect(controller.visibleBackgroundPath, '/cache/demo/background_real.png');
      expect(controller.visibleObjects.first.rect, realisticBallRect);
      expect(notifications, 1);

      controller.togglePicture();
      expect(controller.showsRealisticPicture, isFalse);
      expect(controller.visibleObjects.first.rect, rect);
      expect(notifications, 2);
    });

    test('a scene with no realistic picture has nothing to switch to', () {
      final controller = SceneController(cachedScene: cachedScene, audioSink: FakeAudioSink());
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.hasRealisticPicture, isFalse);
      controller.togglePicture();

      expect(controller.showsRealisticPicture, isFalse);
      expect(notifications, 0);
    });

    test('switching pictures in the middle of a Find round keeps the round going', () {
      final controller = SceneController(
        cachedScene: sceneWithRealistic,
        audioSink: FakeAudioSink(),
        findModeShuffle: (list) => list,
      );
      controller.setMode(SceneModeType.find);
      expect(controller.currentFindTarget, ball);

      controller.togglePicture();

      expect(controller.modeType, SceneModeType.find);
      expect(controller.currentFindTarget, ball);
    });
  });

  group('flashlight', () {
    const outline = ObjectOutline([(x: 0, y: 0), (x: 0.1, y: 0), (x: 0.05, y: 0.1)]);
    const fox = SceneObject(id: 'fox', label: 'Лиса', audio: 'fox.wav', rect: rect, outline: outline);
    const bear = SceneObject(id: 'bear', label: 'Медведь', audio: 'bear.wav', rect: rect, outline: outline);
    // The ball has no outline: scenery, as far as the flashlight goes.
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
      await Future<void>.delayed(Duration.zero);
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

    test('each name is said to the end before the next one, and before the fanfare', () async {
      final audio = FakeAudioSink();
      final controller = SceneController(cachedScene: forest, audioSink: audio);
      final foxPath = forest.audioPathFor(fox);
      final bearPath = forest.audioPathFor(bear);
      audio.holdFile(foxPath);
      audio.holdFile(bearPath);
      controller.setMode(SceneModeType.flashlight);

      // The light goes from the fox straight on to the bear.
      controller.onObjectTapped(fox);
      controller.onObjectTapped(bear);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [foxPath], reason: 'the bear waits for the fox to be named in full');

      audio.releaseFile(foxPath);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedFiles, [foxPath, bearPath]);
      expect(audio.playedSystemPhrases, isEmpty, reason: 'the fanfare waits for the last name');
      expect(controller.showCongrats, isFalse);

      audio.releaseFile(bearPath);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playedSystemPhrases, [SystemPhrase.roundComplete]);
      expect(controller.showCongrats, isTrue);
    });
  });

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

    test('a right tap: the praise, then the next sound, without the name', () async {
      final audio = FakeAudioSink();
      final controller = farmController(audio)..setMode(SceneModeType.whoSays);
      controller.onObjectTapped(cow);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(audio.playedSystemPhrases, [SystemPhrase.correct]);
      expect(audio.playedFiles, [farm.soundPathFor(pig)!]);
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
}
