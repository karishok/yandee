import '../domain/modes/scene_mode_effects.dart';

/// The audio-playing seam `SceneController` depends on, instead of the
/// concrete `audioplayers`-backed `AudioPlayerService` — lets tests inject
/// a fake with no platform channel involved.
abstract class AudioSink {
  /// Play a locally cached audio file (a scene object's recorded name).
  Future<void> playFile(String absolutePath);

  /// Play a bundled system phrase asset.
  Future<void> playSystemPhrase(SystemPhrase phrase);

  /// Play a system phrase, wait for it to finish, then play the object
  /// audio file — used for Find mode's "Find: `<name>`" prompt.
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath);
}
