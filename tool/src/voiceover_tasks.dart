import 'monsters_parts.dart';
import 'scene_vocabulary.dart';
import 'shapes_parts.dart';

/// One word or phrase to synthesize, and where the resulting WAV belongs —
/// the exact same relative path `scene.json` (for objects) or
/// `AudioPlayerService` (for system phrases) already expects.
class VoiceoverTask {
  const VoiceoverTask({required this.text, required this.outputPath});
  final String text;
  final String outputPath;
}

/// `assets/audio/system/correct.wav` is deliberately absent: the success
/// sound is a generated chime (`tool/generate_ding.dart`), not speech, and
/// listing it here would have `record_voiceover.dart system` cheerfully
/// offer to record "Молодец!" over the top of it.
const _systemPhrases = [
  VoiceoverTask(text: 'Где', outputPath: 'assets/audio/system/find_intro.wav'),
  VoiceoverTask(text: 'Попробуй ещё раз', outputPath: 'assets/audio/system/wrong_hint.wav'),
  VoiceoverTask(text: 'Ура, ты всё нашёл!', outputPath: 'assets/audio/system/round_complete.wav'),
];

/// The parents menu's play-timer phrase. It lives in the system folder (the
/// app already bundles that one) but is recorded on its own —
/// `slice_voiceover.dart parents` — so adding it never means re-recording
/// the Find mode's phrases.
const parentsPhrases = [
  VoiceoverTask(text: 'Пора отдыхать!', outputPath: 'assets/audio/system/rest_time.wav'),
];

/// Where the phrases of the "Монстрики" colour game are recorded to — the
/// folder `MonsterVoicePlayer` looks in before falling back to the
/// computer voice.
const monstersVoiceoverDir = 'assets/audio/monsters/';

/// One task per phrase of the "Монстрики" game, in the order of its
/// recording parts (`buildMonstersParts`). The text and file name both
/// come straight from the game's own phrase list, so the recordings can
/// never drift from what the game asks to play.
List<VoiceoverTask> buildMonstersVoiceoverTasks() => [
      for (final part in buildMonstersParts())
        for (final clip in part.clips)
          VoiceoverTask(text: clip.text, outputPath: '$monstersVoiceoverDir${clip.id}.wav'),
    ];

/// Where the phrases of the "Фигурки" game are recorded to — the folder
/// `ShapesVoicePlayer` plays from.
const shapesVoiceoverDir = 'assets/audio/shapes/';

/// One task per phrase of the "Фигурки" game, in recording order.
List<VoiceoverTask> buildShapesVoiceoverTasks() => [
      for (final part in buildShapesParts())
        for (final clip in part.clips)
          VoiceoverTask(text: clip.text, outputPath: '$shapesVoiceoverDir${clip.id}.wav'),
    ];

/// The full list of voiceover tasks: the system phrases, the parents menu
/// phrases, then every scene object's name, in scene/object declaration
/// order, then the phrases of the "Монстрики" and "Фигурки" games.
List<VoiceoverTask> buildVoiceoverTasks() {
  final tasks = <VoiceoverTask>[..._systemPhrases, ...parentsPhrases];
  for (final scene in scenes) {
    for (final object in scene.objects) {
      tasks.add(VoiceoverTask(
        text: object.label,
        outputPath: 'assets/demo_content/${scene.id}/${object.id}.wav',
      ));
    }
  }
  tasks
    ..addAll(buildMonstersVoiceoverTasks())
    ..addAll(buildShapesVoiceoverTasks());
  return tasks;
}
