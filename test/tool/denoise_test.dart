import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/denoise.dart';

double _rms(Float64List samples, int start, int end) {
  var sumSquares = 0.0;
  for (var i = start; i < end; i++) {
    sumSquares += samples[i] * samples[i];
  }
  return math.sqrt(sumSquares / (end - start));
}

double _peakAbs(Float64List samples, int start, int end) {
  var peak = 0.0;
  for (var i = start; i < end; i++) {
    final v = samples[i].abs();
    if (v > peak) peak = v;
  }
  return peak;
}

void main() {
  group('highPass', () {
    const sampleRate = 44100;
    const n = 4410; // 100ms

    Float64List sineWave(double freqHz, double amplitude) {
      final out = Float64List(n);
      for (var i = 0; i < n; i++) {
        out[i] = amplitude * math.sin(2 * math.pi * freqHz * i / sampleRate);
      }
      return out;
    }

    test('attenuates a low-frequency rumble far more than a mid-frequency tone', () {
      final rumble = sineWave(20, 0.5);
      final tone = sineWave(1000, 0.5);

      // Skip the filter's brief startup transient when measuring RMS.
      final rumbleRatio = _rms(highPass(rumble, sampleRate), 1000, n) / _rms(rumble, 1000, n);
      final toneRatio = _rms(highPass(tone, sampleRate), 1000, n) / _rms(tone, 1000, n);

      expect(rumbleRatio, lessThan(0.3));
      expect(toneRatio, greaterThan(0.9));
    });
  });

  group('reduceNoise', () {
    const sampleRate = 44100;
    const n = sampleRate; // 1 second
    const noiseAmplitude = 0.03;
    const toneAmplitude = 0.4;
    final toneStart = (n * 0.3).round();
    final toneEnd = (n * 0.7).round();

    Float64List buildNoisyWordClip() {
      final random = math.Random(1234);
      final signal = Float64List(n);
      for (var i = 0; i < n; i++) {
        signal[i] = noiseAmplitude * (random.nextDouble() * 2 - 1);
      }
      for (var i = toneStart; i < toneEnd; i++) {
        signal[i] += toneAmplitude * math.sin(2 * math.pi * 440 * i / sampleRate);
      }
      return signal;
    }

    test('measurably quiets the steady background noise outside the spoken word', () {
      final signal = buildNoisyWordClip();
      final cleaned = reduceNoise(signal);

      // Comfortably inside the noise-only lead-in (well before toneStart at
      // 0.3 * n), clear of both the tone region and any STFT edge effects.
      final beforeRms = _rms(signal, 2000, 10000);
      final afterRms = _rms(cleaned, 2000, 10000);

      expect(afterRms, lessThan(beforeRms * 0.6));
    });

    test('preserves most of the spoken word rather than gating it to silence too', () {
      final signal = buildNoisyWordClip();
      final cleaned = reduceNoise(signal);

      final centerStart = (n * 0.45).round();
      final centerEnd = (n * 0.55).round();
      final beforePeak = _peakAbs(signal, centerStart, centerEnd);
      final afterPeak = _peakAbs(cleaned, centerStart, centerEnd);

      expect(afterPeak, greaterThan(beforePeak * 0.5));
    });

    test('never amplifies a sample beyond its original clip past the ends of the overlap-add coverage', () {
      // Regression test: a Hann window tapers to 0 at both ends, so right
      // at the very start/end of a clip the overlap-add windowSum can dip
      // to a value that's small but not quite the "uncovered" case — and
      // normalizing by it there used to amplify (sometimes past ±1.0)
      // instead of falling back to the original sample.
      final signal = buildNoisyWordClip();
      final cleaned = reduceNoise(signal);

      final peakBefore = _peakAbs(signal, 0, signal.length);
      final peakAfter = _peakAbs(cleaned, 0, signal.length);
      expect(peakAfter, lessThanOrEqualTo(peakBefore * 1.01)); // tiny slack for float rounding
    });

    test('returns short clips unchanged instead of risking a mangled result', () {
      final shortClip = Float64List.fromList(List.generate(100, (i) => math.sin(i / 3)));
      final result = reduceNoise(shortClip, fftSize: 2048);
      expect(result, same(shortClip));
    });
  });
}
