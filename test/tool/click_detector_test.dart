import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/click_detector.dart';

Float64List _sine(int n, int sampleRate, double freq, double amp) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * math.sin(2 * math.pi * freq * i / sampleRate);
  }
  return out;
}

void main() {
  group('detectClickArtifact', () {
    const sampleRate = 44100;
    const n = sampleRate; // 1 second

    test('a clean continuous tone has nothing to flag', () {
      final clean = _sine(n, sampleRate, 440, 0.4);
      expect(detectClickArtifact(clean, sampleRate), isEmpty);
    });

    test('finds a dropped-buffer discontinuity at the point it occurs', () {
      // Classic fingerprint of a skipped audio buffer: the underlying
      // waveform's phase jumps forward by `skipSamples`, producing a real
      // value discontinuity right at the drop, then continuing smoothly.
      final glitchIndex = (n * 0.45).round();
      const skipSamples = 137; // not a near-multiple of the ~100-sample
      // period at 440Hz/44100Hz, so the skip actually lands mid-cycle
      // instead of coincidentally aliasing back to a similar value.
      final withDrop = Float64List(n);
      for (var i = 0; i < n; i++) {
        final srcIndex = i < glitchIndex ? i : i + skipSamples;
        withDrop[i] = 0.4 * math.sin(2 * math.pi * 440 * srcIndex / sampleRate);
      }

      final times = detectClickArtifact(withDrop, sampleRate);

      expect(times, hasLength(1));
      expect(times.single, closeTo(glitchIndex / sampleRate, 0.01));
    });

    test('does not flag a fast but physically continuous onset', () {
      // Stands in for a sharp-but-real consonant onset: a ~3ms linear
      // ramp from silence into a loud tone, with no value discontinuity.
      final glitchIndex = (n * 0.45).round();
      const rampSamples = 132; // ~3ms
      final onset = Float64List(n);
      for (var i = 0; i < n; i++) {
        final env = i < glitchIndex
            ? 0.0
            : i < glitchIndex + rampSamples
                ? (i - glitchIndex) / rampSamples
                : 1.0;
        onset[i] = env * 0.6 * math.sin(2 * math.pi * 440 * i / sampleRate);
      }

      expect(detectClickArtifact(onset, sampleRate), isEmpty);
    });

    test('does not flag a near-silent noise floor', () {
      final random = math.Random(7);
      final silence = Float64List(n);
      for (var i = 0; i < n; i++) {
        silence[i] = 0.001 * (random.nextDouble() * 2 - 1);
      }

      expect(detectClickArtifact(silence, sampleRate), isEmpty);
    });

    test('returns empty for clips too short to analyze', () {
      expect(detectClickArtifact(Float64List.fromList([0.1, 0.2]), sampleRate), isEmpty);
      expect(detectClickArtifact(Float64List(0), sampleRate), isEmpty);
    });
  });
}
