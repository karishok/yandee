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

  test('explore mode plays the current object then only the final object from a fast sweep', () async {
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
    // directly — no repeated "Найди:" intro.
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
}
