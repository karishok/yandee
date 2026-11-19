import '../models/scene_object.dart';

/// Bundled system phrases used across modes — not tied to any scene's
/// content, so they ship as app assets rather than downloaded content.
enum SystemPhrase { findIntro, wrongHint, correct, roundComplete }

/// The side-effect port a [SceneMode] talks to. Keeping mode logic behind
/// this interface (instead of calling an audio service directly) is what
/// makes `ExploreMode`/`FindMode` unit-testable with a plain fake, and lets
/// `SceneController` own all audio/timing/UI side effects.
abstract class SceneModeEffects {
  /// Play an object's own recorded name, followed by the sound the thing
  /// itself makes when it has one (an animal's voice).
  void playObjectAudio(SceneObject object);

  /// Announces [target] as the next thing to find: its name audio, with
  /// the "Где" lead-in word immediately before it when [announceIntro]
  /// is true. Callers pass true only for the first target of a round —
  /// hearing "Где" again before every single subsequent target (once
  /// per correct tap) is what got called out as repetitive/annoying, on
  /// top of adding a full phrase's worth of delay to every tap in a row.
  void promptFind(SceneObject target, {bool announceIntro = true});

  /// Plays [target]'s own sound (see `SceneObject.sound`) as the thing to
  /// find by ear — the "Где" lead-in word right before it when
  /// [announceIntro] is true (the first target of a round), the sound
  /// alone otherwise. Does nothing for an object without a sound.
  void promptSound(SceneObject target, {bool announceIntro = true});

  /// A wrong guess while finding [target] by ear: the "try again" hint,
  /// then [target]'s sound again once the hint has finished. Several in a
  /// row give one hint and one sound at its end; any other system phrase
  /// (a correct answer) or a mode switch before then cancels the sound.
  void hintThenRepeatSound(SceneObject target);

  /// Like [playObjectAudio], for a caller that has something to do after
  /// the name: completes once the name has been said to its end (or right
  /// away, if a later name took its place before its turn came).
  Future<void> announceObject(SceneObject object);

  /// Play a bundled system phrase (hint, correct, fanfare, ...).
  Future<void> playSystemPhrase(SystemPhrase phrase);

  /// Called once when a round finishes (all objects found).
  void onRoundCompleted();
}
