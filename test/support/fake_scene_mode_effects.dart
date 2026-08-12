import 'package:yandee/domain/models/scene_object.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

class FakeSceneModeEffects implements SceneModeEffects {
  final List<SceneObject> objectAudioCalls = [];
  final List<SceneObject> promptFindCalls = [];
  final List<bool> promptFindAnnounceIntroCalls = [];
  final List<SystemPhrase> systemPhraseCalls = [];
  int roundCompletedCalls = 0;

  @override
  void playObjectAudio(SceneObject object) => objectAudioCalls.add(object);

  @override
  void promptFind(SceneObject target, {bool announceIntro = true}) {
    promptFindCalls.add(target);
    promptFindAnnounceIntroCalls.add(announceIntro);
  }

  @override
  void playSystemPhrase(SystemPhrase phrase) => systemPhraseCalls.add(phrase);

  @override
  void onRoundCompleted() => roundCompletedCalls++;
}
