import 'dart:math' as math;
import 'dart:typed_data';

/// How loud the loud part of a levelled clip is (about −9 dB): the level
/// of its louder syllables, not of its single highest peak.
const double targetLoudness = 0.355;

/// No sample of a levelled clip goes above this (−1 dB): nothing clips on
/// the way to 16-bit or in the phone's own resampling.
const double loudnessCeiling = 0.89;

/// The most a clip is ever amplified (40 dB). A clip quieter than that is
/// silence or noise, and turning it up would only make it loud noise.
const double maxLoudnessGain = 100;

// Below this a sample passes through the limiter untouched; above it the
// sample is eased towards [loudnessCeiling] instead of being cut flat.
const double _limiterKnee = 0.6;

/// How loud a clip sounds: the level its louder moments reach — the 90th
/// percentile of its volume measured over 50 ms stretches. Unlike the
/// single highest peak, this is close to what an ear judges loudness by: a
/// short sharp «Ням!» and a long even «Красная клубника» can share a peak
/// and still sound very different in volume.
double loudnessOf(Float64List samples, int sampleRate) {
  if (samples.isEmpty) return 0;
  final window = math.max(1, (sampleRate * 0.05).round());
  final levels = <double>[];
  for (var start = 0; start < samples.length; start += window) {
    final end = math.min(start + window, samples.length);
    var sumSquares = 0.0;
    for (var i = start; i < end; i++) {
      sumSquares += samples[i] * samples[i];
    }
    levels.add(math.sqrt(sumSquares / (end - start)));
  }
  levels.sort();
  return levels[((levels.length - 1) * 0.9).round()];
}

/// Brings a clip to the common loudness ([targetLoudness]).
///
/// Phrases recorded in different sittings — or bounced from Logic with
/// different settings — come out at very different levels; one part of
/// the "Монстрики" phrases arrived 24 dB quieter than the rest, so «Ням!»
/// could barely be heard next to «Красная клубника», which it is played
/// right before.
///
/// The clip is scaled as a whole, so its sound is unchanged; only the few
/// peaks that would then overshoot [loudnessCeiling] are eased back under
/// it by a soft limiter.
Float64List normalizeLoudness(Float64List samples, int sampleRate) {
  final loudness = loudnessOf(samples, sampleRate);
  if (loudness == 0) return Float64List.fromList(samples);
  final gain = math.min(targetLoudness / loudness, maxLoudnessGain);
  final out = Float64List(samples.length);
  for (var i = 0; i < samples.length; i++) {
    out[i] = _softLimit(samples[i] * gain);
  }
  return out;
}

double _softLimit(double value) {
  final size = value.abs();
  if (size <= _limiterKnee) return value;
  const room = loudnessCeiling - _limiterKnee;
  final limited = _limiterKnee + room * _tanh((size - _limiterKnee) / room);
  return value.isNegative ? -limited : limited;
}

double _tanh(double x) {
  final e = math.exp(2 * x);
  return e.isInfinite ? 1 : (e - 1) / (e + 1);
}
