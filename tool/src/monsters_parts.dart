import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';

/// One sitting's worth of "Монстрики" phrases: 5–10 of them, read in this
/// order into one recording and then cut apart by
/// `tool/slice_voiceover.dart monsters-<number>`.
class MonstersPart {
  const MonstersPart(this.number, this.title, this.clips);

  /// 1-based; also the end of the filter name.
  final int number;

  /// What the part is about, for the person recording it.
  final String title;
  final List<VoiceClip> clips;

  /// The value to pass to the recording tools to select this part.
  String get filter => 'monsters-$number';
}

String _capitalized(String text) => '${text[0].toUpperCase()}${text.substring(1)}';

/// The 79 phrases of the game cut into parts small enough to record in one
/// breath of concentration. Related phrases stay together — all the «Я
/// …!», all the food of one colour — so the voice keeps one intonation
/// across things that will be heard side by side.
List<MonstersPart> buildMonstersParts() {
  const colors = MonsterColor.values;
  final firstColors = colors.sublist(0, 6);
  final lastColors = colors.sublist(6);

  // Food goes colour by colour, two colours to a part where they fit.
  const foodGroups = [
    [MonsterColor.red, MonsterColor.blue],
    [MonsterColor.yellow, MonsterColor.green],
    [MonsterColor.orange, MonsterColor.purple],
    [MonsterColor.pink, MonsterColor.brown],
    [MonsterColor.lightblue, MonsterColor.black],
    [MonsterColor.white],
  ];

  final parts = <(String, List<VoiceClip>)>[
    (
      'Общие фразы',
      const [
        MonsterPhrases.intro,
        MonsterPhrases.yum,
        MonsterPhrases.yuck,
        MonsterPhrases.bye,
        MonsterPhrases.hello,
        MonsterPhrases.helloNew,
        MonsterPhrases.win,
      ],
    ),
    ('Монстрик называет свой цвет — первые шесть', firstColors.map(MonsterPhrases.iAm).toList()),
    ('Монстрик называет свой цвет — остальные пять', lastColors.map(MonsterPhrases.iAm).toList()),
    ('Кому отдать еду — первые шесть', firstColors.map(MonsterPhrases.forColor).toList()),
    ('Кому отдать еду — остальные пять', lastColors.map(MonsterPhrases.forColor).toList()),
    for (final group in foodGroups)
      (
        'Еда: ${group.map((color) => color.feminine).join(' и ')}',
        [for (final color in group) ...foodsFor(color).map(MonsterPhrases.food)],
      ),
  ];

  return [
    for (var i = 0; i < parts.length; i++) MonstersPart(i + 1, _capitalized(parts[i].$1), parts[i].$2),
  ];
}
