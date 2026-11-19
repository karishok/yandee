import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/loudness.dart';

void main() {
  const sampleRate = 44100;

  // One second of an even tone at [amplitude].
  Float64List tone(double amplitude, {double seconds = 1}) => Float64List.fromList([
        for (var i = 0; i < (sampleRate * seconds).round(); i++)
          amplitude * math.sin(2 * math.pi * 220 * i / sampleRate),
      ]);

  // A short sharp burst in the middle of near-silence: one high peak, little body.
  Float64List spike(double amplitude) {
    final samples = tone(amplitude * 0.15);
    for (var i = 20000; i < 20040; i++) {
      samples[i] = amplitude;
    }
    return samples;
  }

  double peakOf(Float64List samples) => samples.fold(0.0, (peak, s) => math.max(peak, s.abs()));

  test('a quiet take and a loud take of the same thing come out equally loud', () {
    final quiet = normalizeLoudness(tone(0.02), sampleRate);
    final loud = normalizeLoudness(tone(0.5), sampleRate);
    expect(loudnessOf(quiet, sampleRate), closeTo(targetLoudness, 0.005));
    expect(loudnessOf(loud, sampleRate), closeTo(targetLoudness, 0.005));
  });

  test('loudness follows the body of the sound, not its single highest peak', () {
    // Same peak, very different loudness — the «Ням!» next to «Красная клубника» case.
    final even = tone(0.5);
    final spiky = spike(0.5);
    expect(peakOf(spiky), closeTo(peakOf(even), 0.01));
    expect(loudnessOf(spiky, sampleRate), lessThan(loudnessOf(even, sampleRate) / 3));

    // Levelled, the two sound alike in volume.
    final levelledSpiky = normalizeLoudness(spiky, sampleRate);
    expect(loudnessOf(levelledSpiky, sampleRate), closeTo(targetLoudness, 0.02));
  });

  test('nothing ever goes above the ceiling, however much a clip is turned up', () {
    for (final clip in [tone(0.01), tone(0.9), spike(0.9), spike(0.05)]) {
      expect(peakOf(normalizeLoudness(clip, sampleRate)), lessThanOrEqualTo(loudnessCeiling));
    }
  });

  test('a clip that fits under the limiter is only scaled — its shape is untouched', () {
    final original = tone(0.1);
    final levelled = normalizeLoudness(original, sampleRate);
    final gain = targetLoudness / loudnessOf(original, sampleRate);
    expect(peakOf(levelled), lessThan(0.6));
    for (var i = 0; i < original.length; i += 997) {
      expect(levelled[i], closeTo(original[i] * gain, 1e-9));
    }
  });

  test('silence stays silence', () {
    expect(normalizeLoudness(Float64List(4410), sampleRate), everyElement(0.0));
    expect(normalizeLoudness(Float64List(0), sampleRate), isEmpty);
  });

  test('near-silence is not blown up into loud noise', () {
    final hiss = tone(0.00001);
    expect(peakOf(normalizeLoudness(hiss, sampleRate)), lessThan(0.002));
  });

  test('the input is left unchanged', () {
    final original = tone(0.3);
    final copy = Float64List.fromList(original);
    normalizeLoudness(original, sampleRate);
    expect(original, copy);
  });
}
