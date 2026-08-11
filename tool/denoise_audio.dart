import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'src/denoise.dart';
import 'src/wav_io.dart';

/// Cleans background noise (hiss, fabric/mic rustling) out of every
/// recorded voiceover WAV already committed under `assets/` — a one-off
/// (re-runnable) pass over existing recordings. New recordings made via
/// `record_voiceover.dart` are cleaned automatically at record time; this
/// script exists to reprocess whatever was recorded before that, or to
/// re-clean everything if the algorithm improves later.
///
/// Usage: `dart run tool/denoise_audio.dart [--dry-run]`
Future<void> main(List<String> args) async {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }

  final dryRun = args.contains('--dry-run');
  final files = _findWavFiles();

  if (files.isEmpty) {
    stdout.writeln('Звуковые файлы не найдены.');
    return;
  }

  stdout.writeln('Найдено ${files.length} файл(ов).${dryRun ? ' (сухой прогон — ничего не меняем)' : ''}\n');
  for (final file in files) {
    final audio = readMonoWav16(file);
    final cleaned = reduceNoise(highPass(audio.samples, audio.sampleRate));
    final beforeDb = _rmsDb(audio.samples);
    final afterDb = _rmsDb(cleaned);
    final relativePath = file.path.startsWith('${Directory.current.path}/')
        ? file.path.substring(Directory.current.path.length + 1)
        : file.path;
    stdout.writeln(
      '$relativePath: ${beforeDb.toStringAsFixed(1)} dB RMS -> ${afterDb.toStringAsFixed(1)} dB RMS',
    );
    if (!dryRun) {
      writeMonoWav16(file, WavAudio(sampleRate: audio.sampleRate, samples: cleaned));
    }
  }
  stdout.writeln(dryRun ? '\nСухой прогон завершён — файлы не изменены.' : '\nГотово.');
}

List<File> _findWavFiles() {
  final files = <File>[];
  final systemDir = Directory('assets/audio/system');
  if (systemDir.existsSync()) {
    files.addAll(systemDir.listSync().whereType<File>().where((f) => f.path.endsWith('.wav')));
  }
  final demoRoot = Directory('assets/demo_content');
  if (demoRoot.existsSync()) {
    for (final sceneDir in demoRoot.listSync().whereType<Directory>()) {
      files.addAll(sceneDir.listSync().whereType<File>().where((f) => f.path.endsWith('.wav')));
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

double _rmsDb(Float64List samples) {
  if (samples.isEmpty) return double.negativeInfinity;
  var sumSquares = 0.0;
  for (final s in samples) {
    sumSquares += s * s;
  }
  final rms = math.sqrt(sumSquares / samples.length);
  return 20 * math.log(rms + 1e-9) / math.ln10;
}
