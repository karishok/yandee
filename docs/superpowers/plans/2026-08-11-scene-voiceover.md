# Scene Voiceover (Live Recording) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 54 silent placeholder WAV files (50 object-name words + 4 system phrases) with real recordings of the developer's own voice, without touching `scene.json` or any app code.

**Architecture:** Tasks 1–2 (already complete) extracted the scene vocabulary into a shared, reusable module and built a pure mapping from that vocabulary to a flat list of `{text, outputPath}` voiceover tasks. Task 3 adds an interactive CLI, `tool/record_voiceover.dart`, that walks that list one word at a time — record via `ffmpeg`/AVFoundation, play it back via `afplay`, keep/redo/skip — writing accepted takes directly to the paths the app already expects. A small pure helper module (`tool/src/voiceover_queue.dart`) decides which tasks still need recording (scene filter + "is this file still an unrecorded placeholder") and is the only part of Task 3 that gets automated unit tests — the live record/playback loop itself needs a real microphone and a real human pressing Enter, so it is exercised by the developer manually, not by an agent.

**Tech Stack:** Dart (`dart:io` `Process`/`Process.start`), `ffmpeg` with the `avfoundation` input device (already installed, records the Mac's microphone) + `afplay` (preinstalled, plays the take back for review), `flutter_test` for the pure-function unit tests.

## Global Constraints

- Output audio format for new recordings: WAV, 16-bit PCM, mono, **44100 Hz**
- Output paths are unchanged from today: `assets/demo_content/<scene_id>/<object_id>.wav`, `assets/audio/system/<phrase>.wav`
- Placeholder marker: every not-yet-recorded WAV is exactly **6444 bytes** (0.4s of silence at 8000 Hz, 16-bit mono — see `tool/src/placeholder_wav.dart`). A file at any other size already has a real recording.
- Interactive controls: Enter to start recording, Enter to stop, then `K` (keep) / `R` (re-record) / `S` (skip) — no other keybindings
- `--dry-run` must never touch `ffmpeg`, the microphone, or `stdin` — it only prints the filtered queue and returns
- No changes to `scene.json`, `lib/`, or any app runtime code — this plan only touches `tool/`, `test/`, and (once the developer actually records, by hand, after this plan ships) binary assets under `assets/`
- No CI/build-time hook — this is a manually-run dev tool, same as the existing `tool/generate_placeholder_assets.dart`
- **The actual recording session (54 live takes) is out of scope for any agent** — Task 3 builds and mechanically verifies the tool; running it to completion with a real voice is a manual follow-up the developer does herself

---

### Task 1: Extract shared scene vocabulary — ✅ COMPLETE

Already implemented and reviewed clean (commits `e5bc0a5..8ca56ff`). See `tool/src/scene_vocabulary.dart` (`ObjectSpec`, `SceneSpec`, `const scenes`) and `test/tool/scene_vocabulary_test.dart`. No further action.

---

### Task 2: Pure mapping from vocabulary to voiceover tasks — ✅ COMPLETE

Already implemented and reviewed clean (commits `8ca56ff..9bf7069`). See `tool/src/voiceover_tasks.dart` (`VoiceoverTask`, `buildVoiceoverTasks()`) and `test/tool/voiceover_tasks_test.dart`. No further action.

---

### Task 3: Interactive recording tool

**Files:**
- Create: `tool/src/voiceover_queue.dart`
- Create: `tool/record_voiceover.dart`
- Test: `test/tool/voiceover_queue_test.dart`

**Interfaces:**
- Consumes: `VoiceoverTask` (`text`, `outputPath`) and `buildVoiceoverTasks()` from `tool/src/voiceover_tasks.dart` (Task 2)
- Produces (from `voiceover_queue.dart`): `const placeholderWavSizeBytes = 6444`; `bool isUnrecorded(File file)`; `bool taskMatchesFilter(VoiceoverTask task, String? sceneFilter)`; `List<VoiceoverTask> buildRecordingQueue(List<VoiceoverTask> tasks, {String? sceneFilter, bool Function(String path) isUnrecordedAt})`
- `tool/record_voiceover.dart`'s `main()` consumes `buildRecordingQueue` and is not itself unit-tested (see rationale above) — verified instead by the non-interactive `--dry-run` steps below, which exercise the real queue-building logic end to end without touching `ffmpeg`/`stdin`

- [ ] **Step 1: Write the failing tests for the queue logic**

Create `test/tool/voiceover_queue_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/voiceover_queue.dart';
import '../../tool/src/voiceover_tasks.dart';

void main() {
  group('isUnrecorded', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('voiceover_queue_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('true for a missing file', () {
      final file = File('${tempDir.path}/missing.wav');
      expect(isUnrecorded(file), isTrue);
    });

    test('true for a file at exactly the placeholder size', () {
      final file = File('${tempDir.path}/placeholder.wav')
        ..writeAsBytesSync(List.filled(placeholderWavSizeBytes, 0));
      expect(isUnrecorded(file), isTrue);
    });

    test('false for a file at any other size', () {
      final file = File('${tempDir.path}/recorded.wav')
        ..writeAsBytesSync(List.filled(placeholderWavSizeBytes + 500, 0));
      expect(isUnrecorded(file), isFalse);
    });
  });

  group('taskMatchesFilter', () {
    const kitchenTask = VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav');
    const farmTask = VoiceoverTask(text: 'Корова', outputPath: 'assets/demo_content/farm/cow.wav');
    const systemTask = VoiceoverTask(text: 'Найди:', outputPath: 'assets/audio/system/find_intro.wav');

    test('null filter matches everything', () {
      expect(taskMatchesFilter(kitchenTask, null), isTrue);
      expect(taskMatchesFilter(systemTask, null), isTrue);
    });

    test('scene filter matches only that scene\'s objects', () {
      expect(taskMatchesFilter(kitchenTask, 'kitchen'), isTrue);
      expect(taskMatchesFilter(farmTask, 'kitchen'), isFalse);
      expect(taskMatchesFilter(systemTask, 'kitchen'), isFalse);
    });

    test('"system" filter matches only system phrases', () {
      expect(taskMatchesFilter(systemTask, 'system'), isTrue);
      expect(taskMatchesFilter(kitchenTask, 'system'), isFalse);
    });
  });

  group('buildRecordingQueue', () {
    test('combines scene filter and unrecorded-check', () {
      const tasks = [
        VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav'),
        VoiceoverTask(text: 'Хлеб', outputPath: 'assets/demo_content/kitchen/bread.wav'),
        VoiceoverTask(text: 'Корова', outputPath: 'assets/demo_content/farm/cow.wav'),
      ];

      final queue = buildRecordingQueue(
        tasks,
        sceneFilter: 'kitchen',
        isUnrecordedAt: (path) => path == 'assets/demo_content/kitchen/bread.wav',
      );

      expect(queue.map((t) => t.outputPath), ['assets/demo_content/kitchen/bread.wav']);
    });

    test('with no filter and everything unrecorded, returns all tasks', () {
      const tasks = [
        VoiceoverTask(text: 'Яблоко', outputPath: 'assets/demo_content/kitchen/apple.wav'),
        VoiceoverTask(text: 'Корова', outputPath: 'assets/demo_content/farm/cow.wav'),
      ];

      final queue = buildRecordingQueue(tasks, isUnrecordedAt: (_) => true);

      expect(queue.length, 2);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/tool/voiceover_queue_test.dart`
Expected: FAIL — `tool/src/voiceover_queue.dart` does not exist (import error)

- [ ] **Step 3: Write the queue logic**

Create `tool/src/voiceover_queue.dart`:

```dart
import 'dart:io';

import 'voiceover_tasks.dart';

/// Placeholder WAVs written by `generate_placeholder_assets.dart` are
/// always exactly this many bytes (0.4s of silence at 8000 Hz, 16-bit
/// mono — see `tool/src/placeholder_wav.dart`). A file at any other size
/// has already been recorded over.
const placeholderWavSizeBytes = 6444;

/// True if nobody has recorded over [file] yet — it's missing, or still
/// exactly the placeholder's byte size.
bool isUnrecorded(File file) {
  if (!file.existsSync()) return true;
  return file.lengthSync() == placeholderWavSizeBytes;
}

/// True if [task] belongs to the requested recording session. `null`
/// matches everything; `'system'` matches only the 4 system phrases; any
/// scene id matches only that scene's objects.
bool taskMatchesFilter(VoiceoverTask task, String? sceneFilter) {
  if (sceneFilter == null) return true;
  if (sceneFilter == 'system') return task.outputPath.startsWith('assets/audio/system/');
  return task.outputPath.startsWith('assets/demo_content/$sceneFilter/');
}

bool _isUnrecordedAt(String path) => isUnrecorded(File(path));

/// The ordered queue of tasks still needing a real recording: [tasks]
/// (normally `buildVoiceoverTasks()`) filtered by scene/system and by
/// whether their output file is still an unrecorded placeholder.
/// [isUnrecordedAt] defaults to a real filesystem check; tests inject a
/// fake to stay off disk.
List<VoiceoverTask> buildRecordingQueue(
  List<VoiceoverTask> tasks, {
  String? sceneFilter,
  bool Function(String path) isUnrecordedAt = _isUnrecordedAt,
}) {
  return tasks
      .where((t) => taskMatchesFilter(t, sceneFilter))
      .where((t) => isUnrecordedAt(t.outputPath))
      .toList();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/tool/voiceover_queue_test.dart`
Expected: PASS (7 tests)

- [ ] **Step 5: Write the interactive recording script**

Create `tool/record_voiceover.dart`:

```dart
import 'dart:io';

import 'src/voiceover_queue.dart';
import 'src/voiceover_tasks.dart';

Future<void> main(List<String> args) async {
  final dryRun = args.remove('--dry-run');
  final sceneFilter = args.isNotEmpty ? args.first : null;

  final queue = buildRecordingQueue(buildVoiceoverTasks(), sceneFilter: sceneFilter);

  if (queue.isEmpty) {
    stdout.writeln('Нечего записывать — все подходящие слова уже озвучены.');
    return;
  }

  if (dryRun) {
    stdout.writeln('${queue.length} слов(о/а) будет записано:');
    for (final task in queue) {
      stdout.writeln('  ${task.text} -> ${task.outputPath}');
    }
    return;
  }

  final device = await _pickDevice();

  for (var i = 0; i < queue.length; i++) {
    final task = queue[i];
    stdout.writeln('\nСкажи: «${task.text}» (${i + 1}/${queue.length})');
    await _recordOne(task, device);
  }

  stdout.writeln('\nГотово!');
}

Future<String> _pickDevice() async {
  final listing = await Process.run('ffmpeg', ['-f', 'avfoundation', '-list_devices', 'true', '-i', '']);
  // ffmpeg prints the device list to stderr regardless of exit code.
  stdout.writeln(listing.stderr);
  stdout.write('Номер микрофона (audio device index): ');
  final input = stdin.readLineSync();
  return input?.trim() ?? '0';
}

Future<void> _recordOne(VoiceoverTask task, String device) async {
  while (true) {
    stdout.write('Enter — начать запись... ');
    stdin.readLineSync();

    final tempFile = File('${Directory.systemTemp.path}/yandee_record_${DateTime.now().microsecondsSinceEpoch}.wav');
    final process = await Process.start('ffmpeg', [
      '-f', 'avfoundation',
      '-i', ':$device',
      '-ar', '44100',
      '-ac', '1',
      '-y',
      tempFile.path,
    ]);

    stdout.write('Enter — остановить запись... ');
    stdin.readLineSync();
    process.kill(ProcessSignal.sigint);
    await process.exitCode;

    await Process.run('afplay', [tempFile.path]);

    stdout.write('[K]eep / [R]e-record / [S]kip: ');
    final choice = stdin.readLineSync()?.trim().toLowerCase();

    if (choice == 'k') {
      final outputFile = File(task.outputPath);
      await outputFile.parent.create(recursive: true);
      await tempFile.copy(outputFile.path);
      await tempFile.delete();
      stdout.writeln('Записано: ${task.outputPath}');
      return;
    }
    if (choice == 's') {
      await tempFile.delete();
      stdout.writeln('Пропущено.');
      return;
    }
    // Anything else (including 'r'): delete the take and loop to re-record.
    await tempFile.delete();
  }
}
```

- [ ] **Step 6: Run the non-interactive smoke checks**

These exercise the real `buildRecordingQueue` logic end to end without touching `ffmpeg`, the microphone, or `stdin` — safe to run directly.

Run: `dart run tool/record_voiceover.dart --dry-run`
Expected: prints `54 слов(о/а) будет записано:` followed by 54 `  <text> -> <path>` lines (every placeholder WAV in the repo is still exactly 6444 bytes at this point, so nothing is filtered out)

Run: `dart run tool/record_voiceover.dart kitchen --dry-run`
Expected: prints `10 слов(о/а) будет записано:` followed by exactly the 10 `assets/demo_content/kitchen/*.wav` lines

Run: `dart run tool/record_voiceover.dart system --dry-run`
Expected: prints `4 слов(о/а) будет записано:` followed by exactly the 4 `assets/audio/system/*.wav` lines

- [ ] **Step 7: Run the full app verification**

Run: `flutter analyze`
Expected: `No issues found!`

Run: `flutter test`
Expected: all tests pass (this step only adds new files under `tool/` and `test/` — no app code or existing assets change, so this confirms nothing broke)

- [ ] **Step 8: Commit**

```bash
git add tool/src/voiceover_queue.dart tool/record_voiceover.dart test/tool/voiceover_queue_test.dart
git commit -m "feat: add interactive live-voice recording tool for scene voiceover"
```

- [ ] **Step 9: Hand off the manual recording session**

This step is performed by the developer, not an agent — note it as the plan's final deliverable rather than executing it:

> Run `dart run tool/record_voiceover.dart <scene-id-or-system, or nothing for everything>` from a real terminal with a working microphone. Work through the prompts (Enter to start/stop, listen to the playback, K/R/S). Safe to stop anytime and resume later — already-recorded words are skipped automatically. Once done, `git add assets/ && git commit` the recorded `.wav` files.

---

## Self-Review Notes

- **Spec coverage:** §2 (architecture) → Task 3 Steps 1–5; §3 (format/interaction) → Global Constraints + Task 3 Step 5's code; §4 (manual vs. automated split) → Task 3's framing note + Step 9; §5 (run/verify) → Task 3 Steps 6–8, with Step 9 as the explicit manual handoff.
- **No placeholders:** every step has literal code/commands, no "TBD" or "handle errors appropriately".
- **Type consistency:** `VoiceoverTask`/`buildVoiceoverTasks()` (Task 2, already built) → consumed by `voiceover_queue.dart`'s `buildRecordingQueue` (Task 3) and by `record_voiceover.dart`'s `main()`. `isUnrecorded`/`taskMatchesFilter`/`buildRecordingQueue` names match exactly between the implementation and the test file above.
