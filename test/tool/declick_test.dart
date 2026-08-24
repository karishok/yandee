import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/click_detector.dart';
import '../../tool/src/declick.dart';

Float64List _sine(int n, int sampleRate, double freq, double amp) {
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    out[i] = amp * math.sin(2 * math.pi * freq * i / sampleRate);
  }
  return out;
}

void main() {
  group('repairClickArtifact', () {
    const sampleRate = 44100;
    const n = sampleRate; // 1 second

    test('removes a dropped-buffer discontinuity so the detector no longer flags it', () {
      // Same fingerprint as click_detector_test's "dropped-buffer" case: a
      // quiet passage whose underlying phase jumps forward by
      // `skipSamples` mid-clip — exactly what avfoundation's capture does
      // when it silently drops a buffer at an I/O callback boundary.
      final glitchIndex = (n * 0.45).round();
      const skipSamples = 137;
      final withDrop = Float64List(n);
      for (var i = 0; i < n; i++) {
        final srcIndex = i < glitchIndex ? i : i + skipSamples;
        withDrop[i] = 0.05 * math.sin(2 * math.pi * 440 * srcIndex / sampleRate);
      }
      // Sanity check: the detector does see a click before repair.
      expect(detectClickArtifact(withDrop, sampleRate), isNotEmpty);

      final repaired = repairClickArtifact(withDrop, sampleRate);

      expect(detectClickArtifact(repaired, sampleRate), isEmpty);
    });

    test('closes the step at the glitch point instead of just fading it', () {
      final glitchIndex = 20000;
      final withStep = Float64List(n);
      for (var i = 0; i < n; i++) {
        // A quiet, slowly-drifting signal (like room tone) that steps to a
        // new DC level at glitchIndex and drifts on from there — the exact
        // shape observed in real captures, as opposed to an impulse that
        // recovers.
        final base = 0.001 * i / n;
        withStep[i] = i < glitchIndex ? base : base - 0.004;
      }

      final repaired = repairClickArtifact(withStep, sampleRate);

      final jumpBefore = (withStep[glitchIndex] - withStep[glitchIndex - 1]).abs();
      final jumpAfter = (repaired[glitchIndex] - repaired[glitchIndex - 1]).abs();
      expect(jumpBefore, greaterThan(0.003));
      expect(jumpAfter, lessThan(0.0005));
    });

    test('leaves a clean continuous tone untouched', () {
      final clean = _sine(n, sampleRate, 440, 0.4);

      final repaired = repairClickArtifact(clean, sampleRate);

      for (var i = 0; i < n; i++) {
        expect(repaired[i], closeTo(clean[i], 1e-12));
      }
    });

    test('does not flag a fast but physically continuous onset', () {
      // Same shape as click_detector_test's onset case: a real consonant
      // attack, not a discontinuity.
      final glitchIndex = (n * 0.45).round();
      const rampSamples = 132;
      final onset = Float64List(n);
      for (var i = 0; i < n; i++) {
        final env = i < glitchIndex
            ? 0.0
            : i < glitchIndex + rampSamples
                ? (i - glitchIndex) / rampSamples
                : 1.0;
        onset[i] = env * 0.6 * math.sin(2 * math.pi * 440 * i / sampleRate);
      }

      final repaired = repairClickArtifact(onset, sampleRate);

      for (var i = 0; i < n; i++) {
        expect(repaired[i], closeTo(onset[i], 1e-12));
      }
    });

    test('leaves a near-silent noise floor untouched', () {
      final random = math.Random(7);
      final silence = Float64List(n);
      for (var i = 0; i < n; i++) {
        silence[i] = 0.001 * (random.nextDouble() * 2 - 1);
      }

      final repaired = repairClickArtifact(silence, sampleRate);

      for (var i = 0; i < n; i++) {
        expect(repaired[i], closeTo(silence[i], 1e-12));
      }
    });

    test('returns the input unchanged for clips too short to analyze', () {
      final short = Float64List.fromList([0.1, 0.2]);
      expect(repairClickArtifact(short, sampleRate), same(short));
      expect(repairClickArtifact(Float64List(0), sampleRate), isEmpty);
    });
  });
}
