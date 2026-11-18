import 'dart:io';

import 'package:yandee/domain/monsters/monster_phrases.dart';

/// Writes stand-in, computer-voice versions of every phrase of the
/// "Монстрики" game to `assets/audio/monsters_tts/<id>.m4a`, so the game
/// can be played before the phrases are recorded for real.
///
/// The app prefers a live recording (`assets/audio/monsters/<id>.wav`,
/// made with `dart run tool/record_voiceover.dart monsters`) whenever one
/// exists; these files only fill the gaps. Once everything is recorded,
/// this folder can be deleted.
///
/// Uses the macOS `say` command with the Russian voice "Milena", then
/// `ffmpeg` to raise the pitch a little (a friendlier, more childlike
/// voice, as in the prototype) and pack the result small.
///
/// Usage: `dart run tool/generate_monster_tts.dart`
Future<void> main() async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  const voice = 'Milena';
  const outputRate = 22050;
  // Pitch up by this factor without changing how fast the words are said.
  const pitch = 1.12;
  const tempo = 0.95;

  final outDir = Directory('assets/audio/monsters_tts')..createSync(recursive: true);
  // Files for phrases the game no longer has would otherwise ship forever.
  final wanted = {for (final clip in MonsterPhrases.allClips) '${clip.id}.m4a'};
  for (final file in outDir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last;
    if (name.endsWith('.m4a') && !wanted.contains(name)) {
      file.deleteSync();
      stdout.writeln('удалён лишний файл: ${file.path}');
    }
  }
  final temp = Directory.systemTemp.createTempSync('yandee_monster_tts_');
  try {
    for (final clip in MonsterPhrases.allClips) {
      final raw = '${temp.path}/${clip.id}.aiff';
      // A leading dash («— синему!») is punctuation for the reader, not
      // something to pronounce.
      final text = clip.text.replaceFirst(RegExp(r'^—\s*'), '');
      await _run('say', ['-v', voice, '-o', raw, text]);

      final output = '${outDir.path}/${clip.id}.m4a';
      await _run('ffmpeg', [
        '-y', '-loglevel', 'error',
        '-i', raw,
        '-af', 'aresample=$outputRate,asetrate=${(outputRate * pitch).round()},'
            'aresample=$outputRate,atempo=${(tempo / pitch).toStringAsFixed(4)}',
        '-ac', '1',
        '-c:a', 'aac',
        '-b:a', '48k',
        output,
      ]);
      stdout.writeln('${clip.text} -> $output');
    }
  } finally {
    temp.deleteSync(recursive: true);
  }
}

Future<void> _run(String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments);
  if (result.exitCode != 0) {
    stderr.writeln('$executable ${arguments.join(' ')}\n${result.stderr}');
    throw ProcessException(executable, arguments, 'failed', result.exitCode);
  }
}
