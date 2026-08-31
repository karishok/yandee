import 'dart:math' as math;
import 'dart:typed_data';

/// One partial of the chime: its frequency relative to the strike's
/// fundamental, how loud it starts, and how fast it dies away.
class _Partial {
  const _Partial(this.ratio, this.amplitude, this.decayPerSecond);
  final double ratio;
  final double amplitude;
  final double decayPerSecond;
}

/// A struck bell is not a harmonic series — its overtones sit slightly
/// sharp of whole-number multiples, and the high ones die away first.
/// That inharmonicity plus the staggered decay is what reads as "дзынь"
/// rather than "beep"; a pure sine at one frequency sounds like a test
/// tone no matter how it is enveloped.
const _partials = [
  _Partial(1.0, 1.0, 6.5),
  _Partial(2.01, 0.55, 10.0),
  _Partial(2.99, 0.28, 15.0),
  _Partial(4.18, 0.14, 22.0),
];

/// Fundamental of the strike — C6, high enough to cut through a room with
/// a toddler in it without being shrill.
const _fundamentalHz = 1046.5;

const _durationSeconds = 0.55;

/// The attack ramp. Long enough that the waveform starts from silence
/// instead of snapping to full amplitude (which pops), short enough that
/// the result still reads as a strike rather than a swell.
const _attackSeconds = 0.005;

/// The release ramp. The exponential decay alone leaves the tail quiet but
/// not silent, and wherever the sine happens to be at the final sample is a
/// step down to zero — i.e. a click. This ramps the end to actual silence
/// instead of relying on the decay landing there by luck.
const _releaseSeconds = 0.02;

/// The success sound: a single bell strike, [_durationSeconds] long,
/// as samples in [-1.0, 1.0] at [sampleRate]. Deterministic — same input,
/// same waveform — so regenerating the asset never silently changes it.
Float64List buildDing({required int sampleRate}) {
  final length = (sampleRate * _durationSeconds).round();
  final attackSamples = math.max(1, (sampleRate * _attackSeconds).round());
  final releaseSamples = math.max(1, (sampleRate * _releaseSeconds).round());
  final samples = Float64List(length);

  var peak = 0.0;
  for (var i = 0; i < length; i++) {
    final t = i / sampleRate;

    var value = 0.0;
    for (final partial in _partials) {
      value += partial.amplitude *
          math.exp(-partial.decayPerSecond * t) *
          math.sin(2 * math.pi * _fundamentalHz * partial.ratio * t);
    }

    // Half-cosine attack, matching the edge ramps `denoise.dart` uses on
    // recorded takes: 0 at the very first sample, 1 by the end of the ramp.
    if (i < attackSamples) {
      value *= 0.5 - 0.5 * math.cos(math.pi * i / attackSamples);
    }
    final fromEnd = length - 1 - i;
    if (fromEnd < releaseSamples) {
      value *= 0.5 - 0.5 * math.cos(math.pi * fromEnd / releaseSamples);
    }

    samples[i] = value;
    peak = math.max(peak, value.abs());
  }

  // Normalize to just under full scale: loud, with headroom so no sample
  // rounds up into clipping on the way to 16-bit.
  final gain = peak == 0 ? 0.0 : 0.89 / peak;
  for (var i = 0; i < length; i++) {
    samples[i] *= gain;
  }

  return samples;
}
