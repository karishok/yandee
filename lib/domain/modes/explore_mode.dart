import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// Tap any object, hear its name. No round to complete, no wrong answers.
class ExploreMode implements SceneMode {
  ExploreMode({required this.effects});

  final SceneModeEffects effects;

  @override
  void activate() {
    // Nothing to announce — the child explores at their own pace.
  }

  @override
  void onObjectTapped(SceneObject object) => effects.playObjectAudio(object);
}
