import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/wav_io.dart';

void main() {
  test('writeMonoWav16 then readMonoWav16 round-trips samples within 16-bit quantization', () async {
    final dir = await Directory.systemTemp.createTemp('yandee_wav_io_test_');
    addTearDown(() => dir.delete(recursive: true));

    const sampleRate = 44100;
    final random = math.Random(42);
    final original = Float64List(2000);
    for (var i = 0; i < original.length; i++) {
      original[i] = random.nextDouble() * 2 - 1;
    }

    final file = File('${dir.path}/roundtrip.wav');
    writeMonoWav16(file, WavAudio(sampleRate: sampleRate, samples: original));
    final read = readMonoWav16(file);

    expect(read.sampleRate, sampleRate);
    expect(read.samples.length, original.length);
    for (var i = 0; i < original.length; i++) {
      expect(read.samples[i], closeTo(original[i], 1 / 32768 + 1e-9));
    }
  });

  test('writeMonoWav16 clips out-of-range samples instead of overflowing', () async {
    final dir = await Directory.systemTemp.createTemp('yandee_wav_io_clip_test_');
    addTearDown(() => dir.delete(recursive: true));

    final file = File('${dir.path}/clipped.wav');
    writeMonoWav16(file, WavAudio(sampleRate: 8000, samples: Float64List.fromList([2.0, -2.0, 0.0])));
    final read = readMonoWav16(file);

    expect(read.samples[0], closeTo(1.0, 1e-3));
    expect(read.samples[1], closeTo(-1.0, 1e-3));
    expect(read.samples[2], closeTo(0.0, 1e-3));
  });

  test('readMonoWav16 rejects a non-WAV file', () async {
    final dir = await Directory.systemTemp.createTemp('yandee_wav_io_bad_test_');
    addTearDown(() => dir.delete(recursive: true));

    final file = File('${dir.path}/not_a_wav.wav')..writeAsBytesSync([1, 2, 3, 4]);

    expect(() => readMonoWav16(file), throwsFormatException);
  });
}
