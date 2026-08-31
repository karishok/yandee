import 'scene_vocabulary.dart';

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
  VoiceoverTask(text: 'Найди:', outputPath: 'assets/audio/system/find_intro.wav'),
  VoiceoverTask(text: 'Попробуй ещё раз', outputPath: 'assets/audio/system/wrong_hint.wav'),
  VoiceoverTask(text: 'Ура, ты всё нашёл!', outputPath: 'assets/audio/system/round_complete.wav'),
];

/// The full list of voiceover tasks: 4 system phrases, then every scene
/// object's name, in scene/object declaration order.
List<VoiceoverTask> buildVoiceoverTasks() {
  final tasks = <VoiceoverTask>[..._systemPhrases];
  for (final scene in scenes) {
    for (final object in scene.objects) {
      tasks.add(VoiceoverTask(
        text: object.label,
        outputPath: 'assets/demo_content/${scene.id}/${object.id}.wav',
      ));
    }
  }
  return tasks;
}
