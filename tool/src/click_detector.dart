import 'dart:math' as math;
import 'dart:typed_data';

/// Flags likely digital-capture discontinuities ("clicks") in a raw
/// recording — a genuine dropped/duplicated audio buffer shows up as a
/// sample-to-sample jump far outside this *specific* clip's own normal
/// range of movement, regardless of how loud or quiet the clip is overall.
/// A fixed absolute threshold doesn't work here: a quiet clip and a loud
/// clip have very different normal jump sizes, but a real glitch is always
/// far above whichever one applies.
///
/// Returns the time (in seconds) of each flagged point, empty if none
/// found. Neighboring flagged samples within [mergeWindowMs] of each other
/// are collapsed into a single reported time, since one glitch shows up as
/// a short run of large deltas, not one isolated sample.
List<double> detectClickArtifact(
  Float64List samples,
  int sampleRate, {
  double madMultiplier = 12,
  double minAbsoluteDelta = 0.002,
  double mergeWindowMs = 50,
}) {
  if (samples.length < 3) return const [];

  final deltas = Float64List(samples.length - 1);
  for (var i = 0; i < deltas.length; i++) {
    deltas[i] = (samples[i + 1] - samples[i]).abs();
  }

  // Median and MAD (median absolute deviation) of the deltas: a robust
  // stand-in for "this clip's typical sample-to-sample movement" that
  // isn't thrown off by the handful of genuinely large deltas a click (or
  // a loud word) produces.
  final sortedDeltas = Float64List.fromList(deltas)..sort();
  final median = sortedDeltas[sortedDeltas.length ~/ 2];
  final absDeviations = Float64List(deltas.length);
  for (var i = 0; i < deltas.length; i++) {
    absDeviations[i] = (deltas[i] - median).abs();
  }
  final sortedDeviations = Float64List.fromList(absDeviations)..sort();
  final mad = sortedDeviations[sortedDeviations.length ~/ 2];

  // The `minAbsoluteDelta` floor matters near silence, where both median
  // and MAD are themselves close to zero and a relative threshold alone
  // would flag ordinary noise-floor jitter.
  final threshold = math.max(median + madMultiplier * mad, minAbsoluteDelta);

  final mergeWindow = (sampleRate * mergeWindowMs / 1000).round();
  final times = <double>[];
  var lastFlagged = -mergeWindow - 1;
  for (var i = 0; i < deltas.length; i++) {
    if (deltas[i] <= threshold) continue;
    if (i - lastFlagged > mergeWindow) {
      // deltas[i] is the jump from samples[i] to samples[i + 1]; report
      // the later sample, where the jump actually lands.
      times.add((i + 1) / sampleRate);
    }
    lastFlagged = i;
  }
  return times;
}
