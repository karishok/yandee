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
