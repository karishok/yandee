import 'dart:io';

import 'src/voiceover_queue.dart';
import 'src/voiceover_tasks.dart';

Future<void> main(List<String> args) async {
  // `dart run` passes a fixed-length list, so mutate a copy rather than
  // calling args.remove() directly (which throws UnsupportedError).
  final remaining = args.toList()..remove('--dry-run');
  final dryRun = remaining.length != args.length;
  final sceneFilter = remaining.isNotEmpty ? remaining.first : null;

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
    stdin.readLineSync();

    final tempFile = File('${Directory.systemTemp.path}/yandee_record_${DateTime.now().microsecondsSinceEpoch}.wav');
    final process = await Process.start('ffmpeg', [
      '-f', 'avfoundation',
      '-i', ':$device',
      '-ar', '44100',
      '-ac', '1',
      '-y',
      tempFile.path,
    ]);

    stdout.write('Enter — остановить запись... ');
    stdin.readLineSync();
    process.kill(ProcessSignal.sigint);
    await process.exitCode;

    await Process.run('afplay', [tempFile.path]);

    stdout.write('[K]eep / [R]e-record / [S]kip: ');
    final choice = stdin.readLineSync()?.trim().toLowerCase();

    if (choice == 'k') {
      final outputFile = File(task.outputPath);
      await outputFile.parent.create(recursive: true);
      await tempFile.copy(outputFile.path);
      await tempFile.delete();
      stdout.writeln('Записано: ${task.outputPath}');
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
