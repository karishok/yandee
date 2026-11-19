import '../domain/monsters/monster_phrases.dart';

/// The short non-speech sounds of the "Монстрики" game. Each is a
/// generated file in `assets/audio/system/` — see
/// `tool/generate_monster_sfx.dart`.
enum MonsterSfx {
  /// A treat was picked up, or a monster was poked.
  boing('monster_boing'),

  /// Three quick munches.
  chomp('monster_chomp'),

  /// Two hand claps, timed to the clapping animation.
  clap('monster_clap'),

  /// A disgusted "bleh".
  yuck('monster_yuck'),

  /// A monster slides away.
  leave('monster_leave'),

  /// A newcomer pops out.
  pop('monster_pop'),

  /// The fanfare and applause for knowing every colour.
  win('monster_win');

  const MonsterSfx(this.fileName);

  /// File name in `assets/audio/system/`, without the extension.
  final String fileName;
}

/// Everything the "Монстрики" screen needs to make a sound — the seam that
/// lets tests run the game with no audio plugin behind it.
abstract class MonsterVoice {
  /// Says [line] — but never over another line: whatever is being said is
  /// said to its end first, and of the lines asked for meanwhile only the
  /// latest is said next (the same rule scene taps follow). Completes when
  /// the line has been said to its end, or has been skipped or stopped.
  Future<void> say(MonsterLine line);

  /// Plays a sound effect on top of whatever else is sounding.
  void playSfx(MonsterSfx sfx);

  /// Silences the line being said and forgets the one waiting, if any.
  void stop();

  /// Releases the native players. Call exactly once.
  void dispose();
}
