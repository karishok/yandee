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

  /// Announces [target] as the next thing to find: its name audio, with
  /// the "Где" lead-in word immediately before it when [announceIntro]
  /// is true. Callers pass true only for the first target of a round —
  /// hearing "Где" again before every single subsequent target (once
  /// per correct tap) is what got called out as repetitive/annoying, on
  /// top of adding a full phrase's worth of delay to every tap in a row.
  void promptFind(SceneObject target, {bool announceIntro = true});

  /// Like [playObjectAudio], for a caller that has something to do after
  /// the name: completes once the name has been said to its end (or right
  /// away, if a later name took its place before its turn came).
  Future<void> announceObject(SceneObject object);

  /// Play a bundled system phrase (hint, correct, fanfare, ...).
  Future<void> playSystemPhrase(SystemPhrase phrase);

  /// Called once when a round finishes (all objects found).
  void onRoundCompleted();
}
