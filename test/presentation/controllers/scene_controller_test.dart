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

  test('switching to find mode prompts the first object', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    controller.setMode(SceneModeType.find);
    expect(controller.modeType, SceneModeType.find);
    expect(controller.currentFindTarget, ball);

    // The prompt is dispatched through the voice queue, so it lands on the
    // sink a microtask after being requested rather than synchronously.
    await Future<void>.delayed(Duration.zero);
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);
  });

  test('find mode: the "correct" phrase finishes before the next find prompt starts', () async {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    controller.setMode(SceneModeType.find);
    await Future<void>.delayed(Duration.zero); // let the first find prompt land

    audio.holdPhrase(SystemPhrase.correct);

    controller.onObjectTapped(ball); // correct, advances target to cat
    await Future<void>.delayed(Duration.zero);

    // "correct" has started playing but hasn't finished — the next find
    // prompt must not have been dispatched to the sink yet.
    expect(audio.playedSystemPhrases, [SystemPhrase.correct]);
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);

    audio.releasePhrase(SystemPhrase.correct);
    await Future<void>.delayed(Duration.zero);

    expect(audio.playedSequences, [
      (SystemPhrase.findIntro, cachedScene.audioPathFor(ball)),
      (SystemPhrase.findIntro, cachedScene.audioPathFor(cat)),
    ]);
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

    // showCongrats is set synchronously by FindMode itself, independent of
    // the voice queue's playback timing.
    expect(controller.showCongrats, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(audio.playedSystemPhrases, contains(SystemPhrase.roundComplete));

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

  test('dispose releases the audio sink', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    expect(audio.disposeCalled, isFalse);
    controller.dispose();
    expect(audio.disposeCalled, isTrue);
  });
}
