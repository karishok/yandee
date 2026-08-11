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
