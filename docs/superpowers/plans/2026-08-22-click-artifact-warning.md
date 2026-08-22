# Click-artifact warning in record_voiceover — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Warn the person recording a voiceover take when the raw capture contains a likely digital-capture click, before they decide whether to keep it.

**Architecture:** A new pure function `detectClickArtifact` (in a new `tool/src/click_detector.dart`, mirroring the existing `tool/src/denoise.dart`) flags sample-to-sample jumps that are large relative to the clip's *own* typical jump size (median + `madMultiplier` × MAD of deltas), with an absolute floor so near-silent clips don't false-positive. `record_voiceover.dart` calls it on the raw temp-file samples right after the `afplay` preview and prints a warning line if it finds anything — `[K]/[R]/[S]` behavior is unchanged.

**Tech Stack:** Dart (`dart:typed_data` `Float64List`, `dart:math`), `flutter_test` for unit tests (existing convention for `tool/src/*` in `test/tool/*_test.dart`).

## Global Constraints

- Detection thresholds, validated against synthetic signals during design: `madMultiplier = 12`, `minAbsoluteDelta = 0.002`, `mergeWindowMs = 50`. Do not retune without re-running the four scenarios below.
- This does not fix the underlying capture glitch (confirmed to be outside this repo — reproducible with a bare `ffmpeg -f avfoundation` capture). It only warns.
- `[K]eep / [R]e-record / [S]kip` behavior must not change — the warning is informational only, printed before that prompt.

---

### Task 1: `detectClickArtifact` pure function + tests

**Files:**
- Create: `tool/src/click_detector.dart`
- Test: `test/tool/click_detector_test.dart`

**Interfaces:**
- Produces: `List<double> detectClickArtifact(Float64List samples, int sampleRate, {double madMultiplier = 12, double minAbsoluteDelta = 0.002, double mergeWindowMs = 50})` — returns times in seconds of flagged discontinuities, empty if none found. Later tasks (Task 2) call this exact signature.

- [ ] **Step 1: Write the failing tests**

Create `test/tool/click_detector_test.dart`:

```dart
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/tool/click_detector_test.dart`
Expected: compile error — `click_detector.dart` doesn't exist yet (`Error when reading '.../tool/src/click_detector.dart': No such file or directory` or similar "Target of URI doesn't exist").

- [ ] **Step 3: Implement `detectClickArtifact`**

Create `tool/src/click_detector.dart`:

```dart
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/tool/click_detector_test.dart`
Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tool/src/click_detector.dart test/tool/click_detector_test.dart
git commit -m "feat: add detectClickArtifact for record_voiceover click warnings

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Wire the warning into record_voiceover.dart

**Files:**
- Modify: `tool/record_voiceover.dart` (imports near line 9; `_recordOne` around line 138)

**Interfaces:**
- Consumes: `detectClickArtifact(Float64List samples, int sampleRate, {...})` from Task 1 (`tool/src/click_detector.dart`); `readMonoWav16(File file) -> WavAudio` (`sampleRate`, `samples`) already imported from `tool/src/wav_io.dart`.

- [ ] **Step 1: Add the import**

In `tool/record_voiceover.dart`, add alongside the existing `tool/src` imports (after the `denoise.dart` import on line 5):

```dart
import 'src/click_detector.dart';
```

- [ ] **Step 2: Read the raw take and warn before the K/R/S prompt**

In `_recordOne`, replace:

```dart
    await Process.run('afplay', [tempFile.path]);

    stdout.write('[K]eep / [R]e-record / [S]kip: ');
```

with:

```dart
    await Process.run('afplay', [tempFile.path]);

    final rawAudio = readMonoWav16(tempFile);
    final clickTimes = detectClickArtifact(rawAudio.samples, rawAudio.sampleRate);
    if (clickTimes.isNotEmpty) {
      final times = clickTimes.map((t) => '~${t.toStringAsFixed(2)}с').join(', ');
      stdout.writeln('⚠ Похоже на щелчок на $times — прислушайся ещё раз.');
    }

    stdout.write('[K]eep / [R]e-record / [S]kip: ');
```

This reads `tempFile` a second time on `K` (the existing `readMonoWav16(tempFile)` call further down, for denoising, is untouched) — an acceptable duplicate read for a single short WAV, per the design doc.

- [ ] **Step 3: Verify it compiles and analyzes clean**

Run: `flutter analyze tool/record_voiceover.dart tool/src/click_detector.dart`
Expected: `No issues found!`

- [ ] **Step 4: Verify `--dry-run` still works (sanity check, no ffmpeg/mic involved)**

Run: `dart run tool/record_voiceover.dart --dry-run`
Expected: same queue-listing behavior as before this change (unaffected — the new code only runs inside `_recordOne`, which `--dry-run` never reaches).

- [ ] **Step 5: Commit**

```bash
git add tool/record_voiceover.dart
git commit -m "feat: warn about likely click artifacts before keep/re-record/skip

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

**Manual verification (not automatable — needs a live microphone):** next real recording session, confirm the warning prints when a click is audible in the raw preview, and stays silent on clean takes.
