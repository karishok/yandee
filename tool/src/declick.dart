import 'dart:math' as math;
import 'dart:typed_data';

/// Repairs isolated capture-glitch discontinuities — the specific defect
/// confirmed in raw `ffmpeg -f avfoundation` recordings on macOS: an
/// abrupt, small level *step* at an isolated point, with the waveform
/// staying smooth (just shifted) on both sides. That's the fingerprint of
/// avfoundation's demuxer silently dropping or duplicating a buffer's
/// worth of samples at a CoreAudio I/O callback boundary — it doesn't
/// compensate for delivery jitter, so the two sides of the recording no
/// longer line up in time. ffmpeg gives no CLI knob to fix this at the
/// source, so it's repaired here, right after capture, before anything
/// else touches the samples.
///
/// This deliberately does *not* reuse [detectClickArtifact]'s whole-clip
/// statistical threshold: that one is tuned to flag anything unusual
/// (including a loud consonant onset) for a human to listen to. A blind
/// repair needs to be far more conservative — it only touches a sample
/// step that is large *relative to how much the signal is moving in the
/// small neighborhood right around it on both sides*. An onset is loud
/// only on one side (silence before, tone after) and builds gradually
/// rather than stepping, so it never satisfies "quiet-ish movement on
/// both sides, then a step far bigger than that". Real speech transients
/// fail the same way. That relative (not absolute) comparison is what
/// lets one threshold work on both a whispered and a shouted take.
///
/// The repair itself removes the step by subtracting it from the samples
/// right after the glitch, with the correction fading to zero over
/// [fixMs] — so the point of the glitch becomes continuous with what came
/// before, and the correction rejoins the (glitched, but internally
/// coherent) continuation smoothly rather than trading one discontinuity
/// for another at the end of the fix window.
Float64List repairClickArtifact(
  Float64List samples,
  int sampleRate, {
  double stepMultiplier = 8,
  double minAbsoluteStep = 0.001,
  int neighborhoodSamples = 8,
  double fixMs = 2,
}) {
  if (samples.length < neighborhoodSamples * 2 + 2) return samples;

  final out = Float64List.fromList(samples);
  final fixSamples = math.max(1, (sampleRate * fixMs / 1000).round());

  var i = 1;
  while (i < out.length) {
    final step = (out[i] - out[i - 1]).abs();
    if (step < minAbsoluteStep) {
      i++;
      continue;
    }

    final beforeStart = math.max(0, i - 1 - neighborhoodSamples);
    final afterEnd = math.min(out.length, i + neighborhoodSamples);
    final beforeActivity = _meanAbsDelta(out, beforeStart, i - 1);
    final afterActivity = _meanAbsDelta(out, i, afterEnd);

    final localFloor = math.max(beforeActivity, afterActivity);
    if (step > stepMultiplier * localFloor) {
      final offset = out[i] - out[i - 1];
      final span = math.min(fixSamples, out.length - i);
      for (var k = 0; k < span; k++) {
        final decay = 1 - k / fixSamples;
        out[i + k] -= offset * decay;
      }
      i += span;
      continue;
    }
    i++;
  }
  return out;
}

/// Mean absolute sample-to-sample delta over `[start, end)` — undefined
/// (returns 0) for a window with fewer than two samples, which is fine
/// here since that only happens right at a clip's very edge.
double _meanAbsDelta(Float64List samples, int start, int end) {
  if (end - start < 2) return 0;
  var sum = 0.0;
  for (var i = start + 1; i < end; i++) {
    sum += (samples[i] - samples[i - 1]).abs();
  }
  return sum / (end - start - 1);
}
