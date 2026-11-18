import 'dart:io';

import 'monsters_parts.dart';
import 'scene_vocabulary.dart';
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

/// The filter value that selects every phrase of the "Монстрики" game.
const monstersFilter = 'monsters';

/// The "Монстрики" phrases in parts of 5–10, so they can be recorded in
/// short sittings instead of all in one go: `monsters-1` … `monsters-10`.
final List<MonstersPart> _monstersParts = buildMonstersParts();

/// Every filter value that selects "Монстрики" phrases: the whole set
/// first, then each part.
final List<String> monstersFilters = [
  monstersFilter,
  for (final part in _monstersParts) part.filter,
];

/// How long a silence has to be, in a single-take recording of "Монстрики"
/// phrases, to count as the gap between two phrases rather than a pause
/// inside one.
const double monstersPhraseGapMs = 900;

/// True if [filter] is about the "Монстрики" game at all.
bool isMonstersFilter(String? filter) => filter != null && monstersFilters.contains(filter);

bool _matchesMonstersFilter(VoiceoverTask task, String filter) {
  if (!task.outputPath.startsWith(monstersVoiceoverDir)) return false;
  if (filter == monstersFilter) return true;
  final part = _monstersParts.firstWhere((part) => part.filter == filter);
  return part.clips.any((clip) => task.outputPath == '$monstersVoiceoverDir${clip.id}.wav');
}

/// True if [task] belongs to the requested recording session. `null`
/// matches everything; `'system'` matches only the 4 system phrases;
/// `'monsters'` and its parts `'monsters-1'`… match the "Монстрики" game's
/// phrases; any scene id matches only that scene's objects.
bool taskMatchesFilter(VoiceoverTask task, String? sceneFilter) {
  if (sceneFilter == null) return true;
  if (sceneFilter == 'system') return task.outputPath.startsWith('assets/audio/system/');
  if (isMonstersFilter(sceneFilter)) return _matchesMonstersFilter(task, sceneFilter);
  return task.outputPath.startsWith('assets/demo_content/$sceneFilter/');
}

/// True if [filter] is a value `taskMatchesFilter` can actually match
/// against: `null` (everything), `'system'`, one of [monstersFilters], or
/// a real scene id. Guards against a typo'd/mis-cased scene filter silently
/// matching nothing and being reported as "already fully recorded".
bool isValidSceneFilter(String? filter) {
  if (filter == null || filter == 'system' || isMonstersFilter(filter)) return true;
  return scenes.any((s) => s.id == filter);
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
