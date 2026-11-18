import 'dart:io';

import 'src/monster_sfx.dart';
import 'src/wav_io.dart';

/// Writes the sound effects of the "Монстрики" game — munching, clapping,
/// "bleh", the pop of a newcomer and the rest — to
/// `assets/audio/system/monster_*.wav`, replacing whatever is there.
///
/// Same format as every other asset (44100 Hz, mono, 16-bit). To retune a
/// sound, edit its recipe in `tool/src/monster_sfx.dart` and re-run this.
///
/// Usage: `dart run tool/generate_monster_sfx.dart`
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  const sampleRate = 44100;
  monsterSfxBuilders.forEach((name, build) {
    final file = File('assets/audio/system/$name.wav');
    file.parent.createSync(recursive: true);
    writeMonoWav16(file, WavAudio(sampleRate: sampleRate, samples: build(sampleRate: sampleRate)));
    stdout.writeln('${file.path} (${file.lengthSync()} байт)');
  });
}
