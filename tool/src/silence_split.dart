import 'dart:math' as math;
import 'dart:typed_data';

/// One word-sized chunk found in a longer recording, as a sample range
/// into the original [Float64List] passed to [splitOnSilence].
class WordSegment {
  const WordSegment({required this.startSample, required this.endSample});
  final int startSample;
  final int endSample;
}

/// Splits a single-take recording (multiple words, one per line, said in
/// order with a pause between each) into per-word segments by finding runs
/// of signal above an adaptive silence threshold.
///
/// Pure and file-agnostic, in the same style as `click_detector.dart`/
/// `denoise.dart` — just samples and a sample rate in, segments out.
///
/// Algorithm:
/// 1. RMS envelope over non-overlapping [windowMs] windows.
/// 2. Adaptive noise floor: the [silencePercentile]-th percentile of the
///    envelope across the whole clip, so the threshold adapts to how noisy
///    this particular take is instead of assuming a fixed dB level.
/// 3. Windows whose envelope exceeds `noiseFloor * thresholdMultiplier`
///    are grouped into continuous runs; runs shorter than [minWordMs] are
///    dropped as spurious noise (breath, rustle) rather than a word.
/// 4. Two runs separated by a silent gap shorter than [minSilenceMs] are
///    merged into one segment — that gap wasn't a real pause between
///    words, so the words are reported joined rather than being silently
///    split apart.
/// 5. Each remaining segment is padded by [padMs] on both sides (clamped
///    to the clip's bounds) so soft onsets/decays aren't clipped.
List<WordSegment> splitOnSilence(
  Float64List samples,
  int sampleRate, {
  double windowMs = 20,
  double silencePercentile = 0.2,
  double thresholdMultiplier = 4,
  double minWordMs = 150,
  double minSilenceMs = 500,
  double padMs = 50,
}) {
  final winSamples = (sampleRate * windowMs / 1000).round();
  if (winSamples <= 0 || samples.isEmpty) return const [];

  final numWindows = (samples.length / winSamples).ceil();
  final envelope = Float64List(numWindows);
  for (var w = 0; w < numWindows; w++) {
    final start = w * winSamples;
    final end = math.min(start + winSamples, samples.length);
    var sumSquares = 0.0;
    for (var i = start; i < end; i++) {
      sumSquares += samples[i] * samples[i];
    }
    envelope[w] = end > start ? math.sqrt(sumSquares / (end - start)) : 0;
  }

  final sortedEnvelope = Float64List.fromList(envelope)..sort();
  final percentileIndex = ((numWindows - 1) * silencePercentile).round().clamp(0, numWindows - 1);
  final noiseFloor = sortedEnvelope[percentileIndex];
  final threshold = noiseFloor * thresholdMultiplier;

  // Group windows above threshold into continuous runs, dropping any run
  // shorter than minWordMs.
  final minWordWindows = minWordMs / windowMs;
  final candidateRuns = <List<int>>[]; // [startSample, endSample]
  var runStart = -1;
  for (var w = 0; w <= numWindows; w++) {
    final isLoud = w < numWindows && envelope[w] > threshold;
    if (isLoud && runStart == -1) {
      runStart = w;
    } else if (!isLoud && runStart != -1) {
      if (w - runStart >= minWordWindows) {
        final startSample = runStart * winSamples;
        final endSample = math.min(w * winSamples, samples.length);
        candidateRuns.add([startSample, endSample]);
      }
      runStart = -1;
    }
  }

  // Merge runs separated by a silence shorter than minSilenceMs — that gap
  // wasn't a real pause between words, so report them joined rather than
  // silently splitting apart.
  final merged = <List<int>>[];
  for (final run in candidateRuns) {
    if (merged.isEmpty) {
      merged.add(run);
      continue;
    }
    final last = merged.last;
    final gapMs = (run[0] - last[1]) / sampleRate * 1000;
    if (gapMs < minSilenceMs) {
      last[1] = run[1];
    } else {
      merged.add(run);
    }
  }

  final padSamples = (sampleRate * padMs / 1000).round();
  return [
    for (final run in merged)
      WordSegment(
        startSample: (run[0] - padSamples).clamp(0, samples.length),
        endSample: (run[1] + padSamples).clamp(0, samples.length),
      ),
  ];
}
