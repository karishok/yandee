import 'monster_color.dart';
import 'monster_food.dart';

/// One recorded piece of speech: a whole short sentence, stored as its own
/// audio file.
class VoiceClip {
  const VoiceClip(this.id, this.text);

  /// File name without the extension, e.g. `food_red_strawberry`.
  final String id;

  /// What to say when recording it.
  final String text;

  @override
  bool operator ==(Object other) => other is VoiceClip && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VoiceClip($id: $text)';
}

/// Something a monster or the narrator says: one or more [clips] played
/// back to back.
class MonsterLine {
  const MonsterLine(this.clips);

  final List<VoiceClip> clips;

  String get text => clips.map((clip) => clip.text).join(' ');

  @override
  String toString() => 'MonsterLine($text)';
}

/// Every phrase of the "Монстрики" game.
///
/// A colour word is never glued to a food word from separate recordings —
/// its ending depends on the food's gender («красная клубника», «красный
/// помидор»), so each colour + food pair is one clip, recorded whole. What
/// *is* joined are whole exclamations with a natural pause between them:
/// «Ням!» + «Красная клубника», or «Фу!» + «Синяя черника» + «— синему!».
/// That keeps the grammar right with 79 recordings instead of 182.
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
  static MonsterLine foodName(MonsterFood food) => MonsterLine([MonsterPhrases.food(food)]);

  /// A monster ate it: «Ням! Красная клубника».
  static MonsterLine ate(MonsterFood food) => MonsterLine([yum, MonsterPhrases.food(food)]);

  /// A monster spat it out: «Фу! Синяя черника — синему!».
  static MonsterLine refused(MonsterFood food) =>
      MonsterLine([yuck, MonsterPhrases.food(food), forColor(food.color)]);

  /// A monster was poked with no treat in hand: «Я красный!».
  static MonsterLine introduce(MonsterColor color) => MonsterLine([iAm(color)]);

  /// A newcomer hopped in: «Привет! Я новенький! Я оранжевый!», or just
  /// «Привет! Я красный!» for a colour the child already knows.
  static MonsterLine greet(MonsterColor color, {required bool firstMeeting}) =>
      MonsterLine([firstMeeting ? helloNew : hello, iAm(color)]);

  static const introLine = MonsterLine([intro]);
  static const byeLine = MonsterLine([bye]);
  static const winLine = MonsterLine([win]);

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
