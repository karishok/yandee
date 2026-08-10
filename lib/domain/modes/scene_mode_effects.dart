import '../models/scene_object.dart';

/// Bundled system phrases used across modes — not tied to any scene's
/// content, so they ship as app assets rather than downloaded content.
enum SystemPhrase { findIntro, wrongHint, correct, roundComplete }

/// The side-effect port a [SceneMode] talks to. Keeping mode logic behind
/// this interface (instead of calling an audio service directly) is what
/// makes `ExploreMode`/`FindMode` unit-testable with a plain fake, and lets
/// `SceneController` own all audio/timing/UI side effects.
abstract class SceneModeEffects {
  /// Play an object's own recorded name.
  void playObjectAudio(SceneObject object);

  /// Play the "Find:" intro immediately followed by [target]'s name audio.
  void promptFind(SceneObject target);

  /// Play a bundled system phrase (hint, correct, fanfare, ...).
  void playSystemPhrase(SystemPhrase phrase);

  /// Called once when a Find round finishes (all objects found).
  void onRoundCompleted();
}
