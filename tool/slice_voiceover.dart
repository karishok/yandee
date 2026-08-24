import 'dart:io';

import 'src/denoise.dart';
import 'src/scene_vocabulary.dart';
import 'src/silence_split.dart';
import 'src/voiceover_queue.dart';
import 'src/voiceover_tasks.dart';
import 'src/wav_io.dart';

/// Slices a single Logic Pro bounce — one scene's (or `system`'s) words,
/// said in order with a pause between each — into per-word `assets/*.wav`
/// files, replacing the mic-capture path in `record_voiceover.dart` for
/// people who'd rather record in a proper DAW than through
/// `ffmpeg -f avfoundation`.
///
/// Usage: `dart run tool/slice_voiceover.dart <scene-id|system> <path/to/bounce.wav>`
Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  if (args.length != 2) {
    stderr.writeln('Использование: dart run tool/slice_voiceover.dart <scene-id|system> <path/to/bounce.wav>');
    exitCode = 1;
    return;
  }

  final sceneFilter = args[0];
  final bouncePath = args[1];

  if (!isValidSceneFilter(sceneFilter)) {
    final validValues = [...scenes.map((s) => s.id), 'system'];
    stderr.writeln('Неизвестный фильтр сцены: "$sceneFilter".');
    stderr.writeln('Допустимые значения: ${validValues.join(', ')}.');
    exitCode = 1;
    return;
  }

  final bounceFile = File(bouncePath);
  if (!bounceFile.existsSync()) {
    stderr.writeln('Файл не найден: $bouncePath');
    exitCode = 1;
    return;
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
  final segments = splitOnSilence(audio.samples, audio.sampleRate);

  if (segments.length != tasks.length) {
    stderr.writeln('Ожидалось ${tasks.length} слов ($sceneFilter), найдено ${segments.length} кусков:');
    for (var i = 0; i < segments.length; i++) {
      final startSec = segments[i].startSample / audio.sampleRate;
      final endSec = segments[i].endSample / audio.sampleRate;
      final durationSec = endSec - startSec;
      stderr.writeln(
        '  $i: ${startSec.toStringAsFixed(2)}–${endSec.toStringAsFixed(2)}с (${durationSec.toStringAsFixed(2)}с)',
      );
    }
    stderr.writeln(
      'Проверь дубль в Logic на волну — где-то не хватает паузы (слова склеились) или пауза внутри слова (слово разрезано).',
    );
    exitCode = 1;
    await tempFile.delete();
    return;
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
    final cleaned = cleanRecording(wordSamples, audio.sampleRate);

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
