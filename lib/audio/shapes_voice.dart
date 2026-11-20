import '../domain/voice/voice_line.dart';

/// The short non-speech sounds of the "Фигурки" game — existing files in
/// `assets/audio/system/`, shared with «Монстрики».
enum ShapesSfx {
  /// A piece clicked into its place.
  placed('monster_pop'),

  /// A piece let go over a slot of another shape.
  wrong('monster_boing'),

  /// A picture is finished.
  pictureDone('monster_clap'),

  /// The whole chain is finished.
  allDone('monster_win');

  const ShapesSfx(this.fileName);

  /// File name in `assets/audio/system/`, without the extension.
  final String fileName;
}

/// Everything the "Фигурки" screen needs to make a sound — the seam that
/// lets tests run the game with no audio plugin behind it.
abstract class ShapesVoice {
  /// Says [line] — never over another line (the latest-only rule).
  /// Completes when it has been said, skipped or stopped.
  Future<void> say(VoiceLine line);

  /// Plays a sound effect on top of whatever else is sounding.
  void playSfx(ShapesSfx sfx);

  /// Silences the line being said and forgets the one waiting, if any.
  void stop();

  /// Releases the native players. Call exactly once.
  void dispose();
}
