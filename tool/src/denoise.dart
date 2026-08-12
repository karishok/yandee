import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';

/// A gentle one-pole high-pass filter — cuts low rumble (handling noise,
/// mic thumps, room hum) below [cutoffHz] without touching the voice band
/// above it.
Float64List highPass(Float64List samples, int sampleRate, {double cutoffHz = 90}) {
  if (samples.isEmpty) return samples;
  final rc = 1 / (2 * math.pi * cutoffHz);
  final dt = 1 / sampleRate;
  final alpha = rc / (rc + dt);

  final out = Float64List(samples.length);
  var prevIn = samples[0];
  var prevOut = 0.0;
  out[0] = 0;
  for (var i = 1; i < samples.length; i++) {
    final y = alpha * (prevOut + samples[i] - prevIn);
    out[i] = y;
    prevOut = y;
    prevIn = samples[i];
  }
  return out;
}

/// Ramps the first/last [fadeMs] of [samples] to/from zero with a
/// half-cosine (equal-power) curve, so a clip starting or ending mid-wave —
/// which is exactly what happens when a recording is manually stopped, or
/// when spectral gating leaves a non-zero residual right at the edge —
/// doesn't produce an audible click/pop on playback. A hard cut to silence
/// is itself a sharp discontinuity; nothing about denoising removes that,
/// which is why this runs last, after [highPass]/[reduceNoise].
Float64List fadeEdges(Float64List samples, int sampleRate, {double fadeMs = 8}) {
  final fadeSamples = math.min(samples.length ~/ 2, (sampleRate * fadeMs / 1000).round());
  if (fadeSamples <= 0) return samples;

  final out = Float64List.fromList(samples);
  for (var i = 0; i < fadeSamples; i++) {
    // 0 at the very edge, 1 by the end of the fade window.
    final gain = 0.5 - 0.5 * math.cos(math.pi * i / fadeSamples);
    out[i] *= gain;
    out[out.length - 1 - i] *= gain;
  }
  return out;
}

/// The full per-take cleanup pipeline, in the order it should always run:
/// cut low rumble, gate out steady background noise, then fade the very
/// edges so neither step (nor however the original recording ended) leaves
/// a clicky discontinuity. Shared by `record_voiceover.dart` (new takes)
/// and `denoise_audio.dart` (reprocessing what's already committed) so the
/// two can't drift out of sync.
Float64List cleanRecording(Float64List samples, int sampleRate) {
  return fadeEdges(reduceNoise(highPass(samples, sampleRate)), sampleRate);
}

Float64List _hannWindow(int n) {
  final w = Float64List(n);
  for (var i = 0; i < n; i++) {
    w[i] = n == 1 ? 1.0 : 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
  }
  return w;
}

/// Removes steady background noise (hiss, fabric/mic rustling, room tone)
/// via spectral gating: for each frequency bin, the quietest
/// [noisePercentile] fraction of frames across the *whole* clip is taken as
/// that bin's noise estimate — this works without a dedicated silent
/// lead-in, which these tightly-cropped single-word recordings don't have
/// — and that much magnitude is subtracted everywhere, floored at
/// [floorGain] so voiced audio is attenuated rather than gated to silence
/// (a hard gate produces "musical noise" artifacts on speech).
///
/// Clips shorter than [fftSize] are returned unchanged rather than risking
/// a mangled result from too few analysis frames.
Float64List reduceNoise(
  Float64List samples, {
  int fftSize = 2048,
  int hopSize = 512,
  double noisePercentile = 0.2,
  double oversubtraction = 1.6,
  double floorGain = 0.08,
}) {
  if (samples.length < fftSize) return samples;

  final window = _hannWindow(fftSize);
  final numFrames = 1 + (samples.length - fftSize) ~/ hopSize;
  final numBins = fftSize ~/ 2 + 1; // 0 (DC) .. Nyquist, inclusive

  final magnitudes = List.generate(numFrames, (_) => Float64List(numBins));
  final phases = List.generate(numFrames, (_) => Float64List(numBins));

  final real = Float64List(fftSize);
  final imag = Float64List(fftSize);
  for (var f = 0; f < numFrames; f++) {
    final start = f * hopSize;
    for (var i = 0; i < fftSize; i++) {
      real[i] = samples[start + i] * window[i];
      imag[i] = 0;
    }
    fftInPlace(real, imag);
    final mag = magnitudes[f];
    final phase = phases[f];
    for (var k = 0; k < numBins; k++) {
      mag[k] = math.sqrt(real[k] * real[k] + imag[k] * imag[k]);
      phase[k] = math.atan2(imag[k], real[k]);
    }
  }

  // Per-bin noise floor: a low percentile of that bin's magnitude across
  // every analysis frame in the clip.
  final noiseFloor = Float64List(numBins);
  final column = Float64List(numFrames);
  final percentileIndex = ((numFrames - 1) * noisePercentile).round().clamp(0, numFrames - 1);
  for (var k = 0; k < numBins; k++) {
    for (var f = 0; f < numFrames; f++) {
      column[f] = magnitudes[f][k];
    }
    column.sort();
    noiseFloor[k] = column[percentileIndex];
  }

  // Spectral-subtract with a gain floor, then smooth the mask across time
  // (a 3-frame moving average) so it doesn't chatter frame-to-frame —
  // that chatter is what causes "musical noise" artifacts.
  final gains = List.generate(numFrames, (_) => Float64List(numBins));
  for (var f = 0; f < numFrames; f++) {
    final mag = magnitudes[f];
    final gain = gains[f];
    for (var k = 0; k < numBins; k++) {
      final raw = mag[k] <= 1e-12 ? 1.0 : 1 - oversubtraction * (noiseFloor[k] / mag[k]);
      gain[k] = raw.clamp(floorGain, 1.0);
    }
  }
  final smoothedGains = List.generate(numFrames, (_) => Float64List(numBins));
  for (var f = 0; f < numFrames; f++) {
    final prev = gains[f == 0 ? 0 : f - 1];
    final cur = gains[f];
    final next = gains[f == numFrames - 1 ? f : f + 1];
    final out = smoothedGains[f];
    for (var k = 0; k < numBins; k++) {
      out[k] = (prev[k] + cur[k] + next[k]) / 3;
    }
  }

  // Inverse STFT with overlap-add, normalized by the summed window energy.
  final output = Float64List(samples.length);
  final windowSum = Float64List(samples.length);
  for (var f = 0; f < numFrames; f++) {
    final mag = magnitudes[f];
    final phase = phases[f];
    final gain = smoothedGains[f];
    for (var k = 0; k < numBins; k++) {
      final m = mag[k] * gain[k];
      real[k] = m * math.cos(phase[k]);
      imag[k] = m * math.sin(phase[k]);
      // Mirror into the conjugate-symmetric upper half so the inverse FFT
      // of this real-valued signal's spectrum comes out real-valued too.
      // Bins 0 (DC) and numBins-1 (Nyquist) are their own mirror.
      if (k != 0 && k != numBins - 1) {
        real[fftSize - k] = real[k];
        imag[fftSize - k] = -imag[k];
      }
    }
    fftInPlace(real, imag, inverse: true);
    final start = f * hopSize;
    for (var i = 0; i < fftSize; i++) {
      output[start + i] += real[i] * window[i];
      windowSum[start + i] += window[i] * window[i];
    }
  }
  // A Hann window tapers to exactly 0 at both ends, so right near the very
  // start/end of the whole clip only one frame's already-small window tail
  // contributes to windowSum, instead of the ~4 overlapping frames that
  // give the interior its steady, near-constant sum. Normalizing by that
  // near-zero (but not quite zero, so the "uncovered" branch above wouldn't
  // catch it) sum amplifies whatever noise is left there — audibly, and in
  // a few cases past full scale. Falling back to the original sample
  // whenever coverage is well below the clip's typical level sidesteps
  // this without needing to reason about exactly how many samples that is.
  var maxWindowSum = 0.0;
  for (final w in windowSum) {
    if (w > maxWindowSum) maxWindowSum = w;
  }
  final minReliableWindowSum = math.max(1e-8, maxWindowSum * 0.1);
  for (var i = 0; i < output.length; i++) {
    output[i] = windowSum[i] > minReliableWindowSum ? output[i] / windowSum[i] : samples[i];
  }
  return output;
}
