import '../domain/modes/scene_mode_effects.dart';

/// The audio-playing seam `SceneController` depends on, instead of the
/// concrete `audioplayers`-backed `AudioPlayerService` — lets tests inject
/// a fake with no platform channel involved.
abstract class AudioSink {
  /// Play a locally cached audio file (a scene object's recorded name).
  Future<void> playFile(String absolutePath);

  /// Play a bundled system phrase asset.
  Future<void> playSystemPhrase(SystemPhrase phrase);

  /// Play a bundled system phrase, cutting off whatever this same call
  /// already has playing rather than queueing behind it. Used for prompts
  /// that can legitimately fire faster than they take to say (e.g. a child
  /// mistapping several times in a row) — repeats should replace each
  /// other, not pile up into a long backlog of the same phrase.
  Future<void> playInterruptibleSystemPhrase(SystemPhrase phrase);

  /// Play a system phrase, wait for it to finish, then play the object
  /// audio file — used for Find mode's "Find: `<name>`" prompt.
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath);

  /// Release any native resources held by this sink (native player, event
  /// channel registration, etc). Must be called exactly once when the sink
  /// is no longer needed.
  void dispose();
}
