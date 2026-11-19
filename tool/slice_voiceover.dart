import 'dart:io';

import 'src/denoise.dart';
import 'src/loudness.dart';
import 'src/scene_vocabulary.dart';
import 'src/silence_split.dart';
import 'src/voiceover_queue.dart';
import 'src/voiceover_tasks.dart';
import 'src/wav_io.dart';

/// Slices a single Logic Pro bounce — one scene's (or `system`'s) words, or
/// one part of the "Монстрики" game's phrases (`monsters-1` … `monsters-10`,
/// see docs/monsters_phrases.md), said in order with a pause between each — into
/// per-word `assets/*.wav`
/// files, replacing the mic-capture path in `record_voiceover.dart` for
/// people who'd rather record in a proper DAW than through
/// `ffmpeg -f avfoundation`.
///
/// Usage: `dart run tool/slice_voiceover.dart <scene-id|system|parents|monsters…> <path/to/bounce.wav>`
Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  if (args.length != 2) {
    stderr.writeln('Использование: dart run tool/slice_voiceover.dart <scene-id|system|parents|monsters…> <path/to/bounce.wav>');
    exitCode = 1;
    return;
  }

  final sceneFilter = args[0];
  final bouncePath = args[1];

  if (!isValidSceneFilter(sceneFilter)) {
    final validValues = [...scenes.map((s) => s.id), 'system', 'parents', ...monstersFilters];
    stderr.writeln('Неизвестный фильтр сцены: "$sceneFilter".');
    stderr.writeln('Допустимые значения: ${validValues.join(', ')}.');
    exitCode = 1;
    return;
  }

  final bounceFile = findBounce(bouncePath);
  if (bounceFile == null) {
    stderr.writeln('Файл не найден: $bouncePath');
    final nearby = recordingsNearby();
    if (nearby.isNotEmpty) {
      stderr.writeln('Зато вижу такие записи — может, одна из них?');
      for (final path in nearby) {
        stderr.writeln('  $path');
      }
    }
    exitCode = 1;
    return;
  }
  if (bounceFile.path != bouncePath) {
    stdout.writeln('Беру запись: ${bounceFile.path}');
  }

  final tasks = buildVoiceoverTasks().where((t) => taskMatchesFilter(t, sceneFilter)).toList();

  // Normalize to mono/44.1kHz with the same ffmpeg dependency
  // record_voiceover.dart already uses — bit depth is left untouched, the
  // input is expected to already be 16-bit PCM.
  final tempFile = File('${Directory.systemTemp.path}/yandee_slice_${DateTime.now().microsecondsSinceEpoch}.wav');
  final normalizeResult = await Process.run('ffmpeg', [
    '-i', bounceFile.path,
    '-ar', '44100',
    '-ac', '1',
    '-y',
    tempFile.path,
  ]);
  if (normalizeResult.exitCode != 0) {
    stderr.writeln('ffmpeg не смог нормализовать файл:');
    stderr.writeln(normalizeResult.stderr);
    exitCode = 1;
    return;
  }

  final audio = readMonoWav16(tempFile);
  // A scene's words are single words, so half a second of silence is
  // always a gap between two of them. Some "Монстрики" phrases are whole
  // sentences with pauses of their own («Спасибо! Пока-пока!»); in a part
  // that has such phrases a gap only counts as "between phrases" once it
  // is close to a second.
  final segments = isMonstersFilter(sceneFilter)
      ? splitOnSilence(audio.samples, audio.sampleRate, minSilenceMs: monstersPhraseGapMsFor(sceneFilter))
      : splitOnSilence(audio.samples, audio.sampleRate);

  if (segments.length != tasks.length) {
    stderr.writeln('Ожидалось ${tasks.length} слов ($sceneFilter), найдено ${segments.length} кусков:');
    for (var i = 0; i < segments.length; i++) {
      final startSec = segments[i].startSample / audio.sampleRate;
      final endSec = segments[i].endSample / audio.sampleRate;
      final durationSec = endSec - startSec;
      // Next to each chunk, the phrase it would become — reading down the
      // list, the first one that doesn't fit its length is where it went off.
      final expected = i < tasks.length ? '«${tasks[i].text}»' : '— лишний кусок';
      stderr.writeln(
        '  ${i + 1}: ${startSec.toStringAsFixed(2)}–${endSec.toStringAsFixed(2)}с '
        '(${durationSec.toStringAsFixed(2)}с)  $expected',
      );
    }
    for (var i = segments.length; i < tasks.length; i++) {
      stderr.writeln('  ${i + 1}: нет куска для «${tasks[i].text}»');
    }
    stderr.writeln(
      'Проверь дубль в Logic на волну — где-то не хватает паузы (слова склеились) или пауза внутри слова (слово разрезано).',
    );
    exitCode = 1;
    await tempFile.delete();
    return;
  }

  // A take that starts or stops in the middle of a word has lost part of
  // it for good; say so now rather than let it be discovered in the app.
  final cutOff = cutOffEdges(audio.samples, audio.sampleRate);
  if (cutOff.start) {
    stdout.writeln(
      '⚠ Запись начинается прямо с голоса, без тишины: у первой фразы «${tasks.first.text}» '
      'обрезано начало. Сохрани запись из Logic заново, захватив немного тишины перед первым словом.',
    );
  }
  if (cutOff.end) {
    stdout.writeln(
      '⚠ Запись обрывается прямо на голосе: у последней фразы «${tasks.last.text}» обрезан конец. '
      'Сохрани запись из Logic заново, захватив немного тишины после последнего слова.',
    );
  }

  // All-or-nothing: the count already matched above, so every segment now
  // gets cleaned and written — no partial output on a failed run.
  for (var i = 0; i < tasks.length; i++) {
    final task = tasks[i];
    final segment = segments[i];
    final wordSamples = audio.samples.sublist(segment.startSample, segment.endSample);
    // Same cleanup pipeline mic takes get, for consistent loudness/noise
    // floor with older words and to smooth away any click the
    // silence-padding might leave at a cut edge.
    var cleaned = cleanRecording(wordSamples, audio.sampleRate);
    // The game's phrases are joined back to back («Ням!» + «Красная
    // клубника»), so a part bounced quieter than another is heard at once;
    // every phrase is brought to the same level.
    if (isMonstersFilter(sceneFilter)) cleaned = normalizeLoudness(cleaned, audio.sampleRate);

    final outputFile = File(task.outputPath);
    await outputFile.parent.create(recursive: true);
    writeMonoWav16(outputFile, WavAudio(sampleRate: audio.sampleRate, samples: cleaned));
  }

  await tempFile.delete();

  stdout.writeln('Готово! Записано ${tasks.length} слов(о/а):');
  for (final task in tasks) {
    stdout.writeln('  ${task.text} -> ${task.outputPath}');
  }
}

/// The recording [path] points at. A bare file name is also looked for in
/// `tool/`, next to this script — the natural place to drop a bounce, and
/// easy to forget to spell out in the command.
File? findBounce(String path, {String toolDir = 'tool'}) {
  final asGiven = File(path);
  if (asGiven.existsSync()) return asGiven;
  if (!path.contains('/')) {
    final inToolDir = File('$toolDir/$path');
    if (inToolDir.existsSync()) return inToolDir;
  }
  return null;
}

/// Audio files lying in the project folder and in `tool/`, to suggest when
/// the one asked for can't be found.
List<String> recordingsNearby({String root = '.', String toolDir = 'tool'}) {
  const extensions = ['.wav', '.aif', '.aiff', '.m4a', '.mp3', '.caf'];
  final found = <String>[];
  for (final dir in [Directory(root), Directory(toolDir)]) {
    if (!dir.existsSync()) continue;
    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (extensions.any(name.toLowerCase().endsWith)) {
        found.add(dir.path == '.' ? name : '${dir.path}/$name');
      }
    }
  }
  return found..sort();
}
