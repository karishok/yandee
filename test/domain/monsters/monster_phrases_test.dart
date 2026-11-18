import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';

void main() {
  const strawberry = MonsterFood(FoodKind.strawberry, MonsterColor.red);
  const blueberry = MonsterFood(FoodKind.blueberry, MonsterColor.blue);

  test('a picked-up treat is named: «Красная клубника»', () {
    final line = MonsterPhrases.foodName(strawberry);
    expect(line.text, 'Красная клубника');
    expect(line.clips.map((clip) => clip.id), ['food_red_strawberry']);
  });

  test('an eaten treat: «Ням! Красная клубника»', () {
    final line = MonsterPhrases.ate(strawberry);
    expect(line.text, 'Ням! Красная клубника');
    expect(line.clips.map((clip) => clip.id), ['yum', 'food_red_strawberry']);
  });

  test('a refused treat says whose it is: «Фу! Синяя черника — синему!»', () {
    final line = MonsterPhrases.refused(blueberry);
    expect(line.text, 'Фу! Синяя черника — синему!');
    expect(line.clips.map((clip) => clip.id), ['yuck', 'food_blue_blueberry', 'for_blue']);
  });

  test('right after the treat was named, the monster does not say its name again', () {
    expect(MonsterPhrases.ateJustNamed.text, 'Ням!');
    expect(MonsterPhrases.refusedJustNamed(blueberry).text, 'Фу! — синему!');
    expect(MonsterPhrases.refusedJustNamed(blueberry).clips.map((clip) => clip.id), ['yuck', 'for_blue']);
  });

  test('a poked monster names its colour: «Я красный!»', () {
    expect(MonsterPhrases.introduce(MonsterColor.red).text, 'Я красный!');
    expect(MonsterPhrases.introduce(MonsterColor.lightblue).text, 'Я голубой!');
  });

  test('a newcomer says it is new only the first time', () {
    expect(
      MonsterPhrases.greet(MonsterColor.orange, firstMeeting: true).text,
      'Привет! Я новенький! Я оранжевый!',
    );
    expect(MonsterPhrases.greet(MonsterColor.orange, firstMeeting: false).text, 'Привет! Я оранжевый!');
  });

  test('the fixed lines', () {
    expect(MonsterPhrases.introLine.text, 'Покорми монстриков! Красный ест красное, синий — синее.');
    expect(MonsterPhrases.byeLine.text, 'Спасибо! Пока-пока!');
    expect(MonsterPhrases.winLine.text, 'Ура! Ты знаешь все цвета!');
  });

  test('71 clips to record, each with its own file name', () {
    final clips = MonsterPhrases.allClips;
    expect(clips, hasLength(71));
    expect(clips.map((clip) => clip.id).toSet(), hasLength(71));
    for (final clip in clips) {
      expect(clip.id, matches(RegExp(r'^[a-z_]+$')), reason: 'file names stay plain latin');
    }
  });

  test('every clip any line can use is in the list to record', () {
    final recorded = MonsterPhrases.allClips.toSet();
    final lines = [
      MonsterPhrases.introLine,
      MonsterPhrases.byeLine,
      MonsterPhrases.winLine,
      for (final color in MonsterColor.values) ...[
        MonsterPhrases.introduce(color),
        MonsterPhrases.greet(color, firstMeeting: true),
        MonsterPhrases.greet(color, firstMeeting: false),
      ],
      for (final food in allFoods) ...[
        MonsterPhrases.foodName(food),
        MonsterPhrases.ate(food),
        MonsterPhrases.refused(food),
      ],
    ];
    for (final line in lines) {
      expect(recorded, containsAll(line.clips), reason: line.text);
    }
  });
}
