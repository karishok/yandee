import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'src/denoise.dart';
import 'src/scene_vocabulary.dart';
import 'src/voiceover_queue.dart';
import 'src/voiceover_tasks.dart';
import 'src/wav_io.dart';

Future<void> main(List<String> args) async {
  // Output paths are relative to the repo root; running from anywhere else
  // would silently create a fresh `assets/` tree and re-record everything.
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  // `dart run` passes a fixed-length list, so mutate a copy rather than
  // calling args.remove() directly (which throws UnsupportedError).
  final remaining = args.toList()..remove('--dry-run');
  final dryRun = remaining.length != args.length;
  final sceneFilter = remaining.isNotEmpty ? remaining.first : null;

  if (!isValidSceneFilter(sceneFilter)) {
    final validValues = [...scenes.map((s) => s.id), 'system'];
    stderr.writeln('Неизвестный фильтр сцены: "$sceneFilter".');
    stderr.writeln('Допустимые значения: ${validValues.join(', ')}.');
    exitCode = 1;
    return;
  }

  final queue = buildRecordingQueue(buildVoiceoverTasks(), sceneFilter: sceneFilter);

  if (queue.isEmpty) {
    stdout.writeln('Нечего записывать — все подходящие слова уже озвучены.');
    return;
  }

  if (dryRun) {
    stdout.writeln('${queue.length} слов(о/а) будет записано:');
    for (final task in queue) {
      stdout.writeln('  ${task.text} -> ${task.outputPath}');
    }
    return;
  }

  final device = await _pickDevice();

  for (var i = 0; i < queue.length; i++) {
    final task = queue[i];
    stdout.writeln('\nСкажи: «${task.text}» (${i + 1}/${queue.length})');
    await _recordOne(task, device);
  }

  stdout.writeln('\nГотово!');
}

/// Reads one line from stdin, or exits the whole process if stdin has hit
/// EOF (e.g. launched non-interactively/piped) — without this, a `null`
/// read would otherwise spin an unbounded loop that keeps spawning ffmpeg.
///
/// If [processToCleanUpOnExit] is given, it is killed before exiting — used
/// at the "stop recording" read site, where a live ffmpeg child would
/// otherwise be orphaned (mic left open, temp file left growing) if stdin
/// hits EOF while a recording is in progress.
String _readLineOrExit({Process? processToCleanUpOnExit}) {
  final line = stdin.readLineSync();
  if (line == null) {
    processToCleanUpOnExit?.kill(ProcessSignal.sigint);
    stderr.writeln('Похоже, нет интерактивного ввода — выхожу.');
    exit(1);
  }
  return line;
}

Future<String> _pickDevice() async {
  final listing = await Process.run('ffmpeg', ['-f', 'avfoundation', '-list_devices', 'true', '-i', '']);
  // ffmpeg prints the device list to stderr regardless of exit code.
  stdout.writeln(listing.stderr);
  stdout.write('Номер микрофона (audio device index): ');
  final input = stdin.readLineSync();
  return input?.trim() ?? '0';
}

Future<void> _recordOne(VoiceoverTask task, String device) async {
  while (true) {
    stdout.write('Enter — начать запись... ');
    _readLineOrExit();

    final tempFile = File('${Directory.systemTemp.path}/yandee_record_${DateTime.now().microsecondsSinceEpoch}.wav');
    final process = await Process.start('ffmpeg', [
      '-f', 'avfoundation',
      '-i', ':$device',
      '-ar', '44100',
      '-ac', '1',
      '-y',
      tempFile.path,
    ]);
    // Drain stdout (unneeded) so it can never back up and block ffmpeg, but
    // buffer stderr so we have something to show the developer if the
    // recording fails — ffmpeg writes its progress/errors there.
    unawaited(process.stdout.drain());
    final stderrLines = <String>[];
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderrLines.add)
        .asFuture<void>();

    stdout.write('Enter — остановить запись... ');
    _readLineOrExit(processToCleanUpOnExit: process);
    process.kill(ProcessSignal.sigint);
    await process.exitCode;
    await stderrDone;

    // ffmpeg terminated by our own SIGINT exits non-zero (255) even on a
    // clean recording, so exit code is not the success signal here — file
    // existence/size is. A bare WAV header with no audio is ~44 bytes.
    final recordedOk = tempFile.existsSync() && tempFile.lengthSync() > 44;
    if (!recordedOk) {
      stdout.writeln('Не удалось записать звук (нет файла или он пустой).');
      if (stderrLines.isNotEmpty) {
        stdout.writeln('Последние строки вывода ffmpeg:');
        final tail = stderrLines.length > 20 ? stderrLines.sublist(stderrLines.length - 20) : stderrLines;
        for (final line in tail) {
          stdout.writeln('  $line');
        }
      }
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      stdout.writeln('Повторяем это же слово.');
      continue;
    }

    await Process.run('afplay', [tempFile.path]);

    stdout.write('[K]eep / [R]e-record / [S]kip: ');
    final choice = _readLineOrExit().trim().toLowerCase();

    if (choice == 'k') {
      final outputFile = File(task.outputPath);
      await outputFile.parent.create(recursive: true);
      // The mic on a laptop/phone reliably picks up handling noise and
      // room hiss under a kid-word take — clean it up before it ever lands
      // in the repo, rather than shipping raw mic noise and hoping nobody
      // notices. The preview above plays the raw take (so re-record
      // decisions are about the words/timing, not this), and denoising
      // happens only once a take is actually kept.
      final recorded = readMonoWav16(tempFile);
      final cleaned = cleanRecording(recorded.samples, recorded.sampleRate);
      writeMonoWav16(outputFile, WavAudio(sampleRate: recorded.sampleRate, samples: cleaned));
      await tempFile.delete();
      stdout.writeln('Записано (шум почищен): ${task.outputPath}');
      return;
    }
    if (choice == 's') {
      await tempFile.delete();
      stdout.writeln('Пропущено.');
      return;
    }
    // Anything else (including 'r'): delete the take and loop to re-record.
    await tempFile.delete();
  }
}
