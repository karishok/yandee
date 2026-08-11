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

  test('switching to find mode prompts the first object', () {
    final audio = FakeAudioSink();
    final controller = SceneController(cachedScene: cachedScene, audioSink: audio);
    controller.setMode(SceneModeType.find);
    expect(controller.modeType, SceneModeType.find);
    expect(controller.currentFindTarget, ball);
    expect(audio.playedSequences, [(SystemPhrase.findIntro, cachedScene.audioPathFor(ball))]);
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

    expect(controller.showCongrats, isTrue);
    expect(audio.playedSystemPhrases, contains(SystemPhrase.roundComplete));

    await Future<void>.delayed(const Duration(milliseconds: 30));

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
}
