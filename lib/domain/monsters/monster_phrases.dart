import 'monster_color.dart';
import 'monster_food.dart';
import '../voice/voice_line.dart';

export '../voice/voice_line.dart';

/// Every phrase of the "Монстрики" game.
///
/// A colour word is never glued to a food word from separate recordings —
/// its ending depends on the food's gender («красная клубника», «красный
/// помидор»), so each colour + food pair is one clip, recorded whole. What
/// *is* joined are whole exclamations with a natural pause between them:
/// «Ням!» + «Красная клубника», or «Фу!» + «Синяя черника» + «— синему!».
/// That keeps the grammar right with 71 recordings instead of about 160.
abstract final class MonsterPhrases {
  static const intro = VoiceClip('intro', 'Покорми монстриков! Красный ест красное, синий — синее.');
  static const yum = VoiceClip('yum', 'Ням!');
  static const yuck = VoiceClip('yuck', 'Фу!');
  static const bye = VoiceClip('bye', 'Спасибо! Пока-пока!');
  static const hello = VoiceClip('hello', 'Привет!');
  static const helloNew = VoiceClip('hello_new', 'Привет! Я новенький!');
  static const win = VoiceClip('win', 'Ура! Ты знаешь все цвета!');

  /// «Красная клубника».
  static VoiceClip food(MonsterFood food) {
    final name = food.name;
    return VoiceClip(
      'food_${food.color.name}_${food.kind.fileId}',
      '${name[0].toUpperCase()}${name.substring(1)}',
    );
  }

  /// «Я красный!»
  static VoiceClip iAm(MonsterColor color) => VoiceClip('iam_${color.name}', 'Я ${color.masculine}!');

  /// «— синему!» — the tail of «Фу! Синяя черника — синему!».
  static VoiceClip forColor(MonsterColor color) => VoiceClip('for_${color.name}', '— ${color.dative}!');

  /// A treat was picked up: «Красная клубника».
  static VoiceLine foodName(MonsterFood food) => VoiceLine([MonsterPhrases.food(food)]);

  /// A monster ate it: «Ням! Красная клубника».
  static VoiceLine ate(MonsterFood food) => VoiceLine([yum, MonsterPhrases.food(food)]);

  /// A monster spat it out: «Фу! Синяя черника — синему!».
  static VoiceLine refused(MonsterFood food) =>
      VoiceLine([yuck, MonsterPhrases.food(food), forColor(food.color)]);

  /// A monster ate a treat whose name is still being said from when it
  /// was picked up: just «Ням!», so the name isn't said twice in a row.
  static const ateJustNamed = VoiceLine([yum]);

  /// A monster was poked with no treat in hand: «Я красный!».
  static VoiceLine introduce(MonsterColor color) => VoiceLine([iAm(color)]);

  /// A newcomer hopped in: «Привет! Я новенький! Я оранжевый!», or just
  /// «Привет! Я красный!» for a colour the child already knows.
  static VoiceLine greet(MonsterColor color, {required bool firstMeeting}) =>
      VoiceLine([firstMeeting ? helloNew : hello, iAm(color)]);

  static const introLine = VoiceLine([intro]);
  static const byeLine = VoiceLine([bye]);
  static const winLine = VoiceLine([win]);

  /// Every clip that needs a recording, in the order they are listed for
  /// the person recording them.
  static List<VoiceClip> get allClips => [
        intro,
        yum,
        yuck,
        bye,
        hello,
        helloNew,
        win,
        for (final color in MonsterColor.values) iAm(color),
        for (final color in MonsterColor.values) forColor(color),
        for (final food in allFoods) MonsterPhrases.food(food),
      ];
}
