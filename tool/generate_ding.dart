import 'dart:io';

import 'src/ding.dart';
import 'src/wav_io.dart';

/// Writes the success sound — the "дзынь" a correct Find-mode tap plays —
/// to `assets/audio/system/correct.wav`, replacing whatever is there.
///
/// This is the one system sound that isn't a recorded voice, so it is
/// generated rather than committed as an opaque blob: to retune it, edit
/// the constants in `tool/src/ding.dart` and re-run this. Same format as
/// every other asset (44100 Hz, mono, 16-bit).
///
/// Usage: `dart run tool/generate_ding.dart`
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  const sampleRate = 44100;
  const outputPath = 'assets/audio/system/correct.wav';

  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  writeMonoWav16(file, WavAudio(sampleRate: sampleRate, samples: buildDing(sampleRate: sampleRate)));

  stdout.writeln('$outputPath (${file.lengthSync()} байт)');
}
