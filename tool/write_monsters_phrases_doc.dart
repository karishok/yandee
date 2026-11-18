import 'dart:io';

import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';

/// Writes `docs/monsters_phrases.md` — the list of every phrase of the
/// "Монстрики" game to record, with its file name — from the game's own
/// phrase list, so the document can't drift from the code.
///
/// Usage: `dart run tool/write_monsters_phrases_doc.dart`
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }
  File('docs/monsters_phrases.md').writeAsStringSync(buildMonstersPhrasesDoc());
  stdout.writeln('docs/monsters_phrases.md (${MonsterPhrases.allClips.length} фраз)');
}

String _capitalized(String text) => '${text[0].toUpperCase()}${text.substring(1)}';

String _table(Iterable<VoiceClip> clips) {
  final rows = StringBuffer('| Что сказать | Файл |\n|---|---|\n');
  for (final clip in clips) {
    rows.writeln('| ${clip.text} | `${clip.id}.wav` |');
  }
  return rows.toString();
}

String buildMonstersPhrasesDoc() {
  final total = MonsterPhrases.allClips.length;
  final out = StringBuffer()
    ..writeln('# Игра «Монстрики» — фразы для записи')
    ..writeln()
    ..writeln('<!-- Этот файл создан командой `dart run tool/write_monsters_phrases_doc.dart`. '
        'Не правь его руками — правки пропадут при следующем запуске. -->')
    ..writeln()
    ..writeln('Всего нужно записать **$total фраз**. Каждая фраза — отдельный файл в папке '
        '`assets/audio/monsters/`.')
    ..writeln()
    ..writeln('## Как записывать')
    ..writeln()
    ..writeln('В терминале, из папки проекта:')
    ..writeln()
    ..writeln('```bash')
    ..writeln('dart run tool/record_voiceover.dart monsters')
    ..writeln('```')
    ..writeln()
    ..writeln('Программа сама по очереди показывает, что сказать, и сама кладёт запись в нужный файл '
        'с нужным именем — названия файлов из таблиц ниже запоминать не нужно. Запись можно прервать '
        'в любой момент: при следующем запуске она продолжит с первой ещё не записанной фразы.')
    ..writeln()
    ..writeln('Пока фраза не записана, игра говорит её временным компьютерным голосом. '
        'Как только появляется твоя запись, игра сама начинает использовать её.')
    ..writeln()
    ..writeln('## Почему фраз $total, а не 182')
    ..writeln()
    ..writeln('Цвет и еда всегда записаны вместе, одной фразой: «Красная клубника», «Красный помидор», '
        '«Красное мороженое». Так окончание цвета всегда правильное — из отдельных слов «красная» и '
        '«клубника» игра фразу не склеивает.')
    ..writeln()
    ..writeln('А вот длинные реплики игра собирает из целых коротких фраз с паузой между ними:')
    ..writeln()
    ..writeln('- «Ням! Красная клубника» = «Ням!» + «Красная клубника»')
    ..writeln('- «Фу! Синяя черника — синему!» = «Фу!» + «Синяя черника» + «— синему!»')
    ..writeln('- «Привет! Я новенький! Я оранжевый!» = «Привет! Я новенький!» + «Я оранжевый!»')
    ..writeln()
    ..writeln('Поэтому «Красная клубника» записывается один раз, а звучит в трёх местах: когда ребёнок '
        'берёт еду, когда монстрик её съел и когда выплюнул.')
    ..writeln()
    ..writeln('## Советы')
    ..writeln()
    ..writeln('- Названия еды («Красная клубника») говори ровно и радостно, без вопроса и без '
        'восклицания в конце — эта запись должна подходить и после «Ням!», и после «Фу!».')
    ..writeln('- Фразы «— синему!», «— красному!» — это концовка от «Фу! Синяя черника — синему!». '
        'Тире читать не нужно: скажи одно слово «синему!» так, будто подсказываешь, кому отдать.')
    ..writeln('- «Ням!» и «Фу!» — коротко и с выражением, это голос монстрика.')
    ..writeln()
    ..writeln('## Общие фразы')
    ..writeln()
    ..write(_table(const [
      MonsterPhrases.intro,
      MonsterPhrases.yum,
      MonsterPhrases.yuck,
      MonsterPhrases.bye,
      MonsterPhrases.hello,
      MonsterPhrases.helloNew,
      MonsterPhrases.win,
    ]))
    ..writeln()
    ..writeln('## Монстрик называет свой цвет')
    ..writeln()
    ..writeln('Звучит, когда ребёнок тыкает в монстрика, и в конце приветствия новенького.')
    ..writeln()
    ..write(_table(MonsterColor.values.map(MonsterPhrases.iAm)))
    ..writeln()
    ..writeln('## Кому отдать еду')
    ..writeln()
    ..writeln('Концовка фразы «Фу! … — синему!».')
    ..writeln()
    ..write(_table(MonsterColor.values.map(MonsterPhrases.forColor)))
    ..writeln()
    ..writeln('## Еда')
    ..writeln();

  for (final color in MonsterColor.values) {
    out
      ..writeln('### ${_capitalized(color.masculine)}')
      ..writeln()
      ..write(_table(foodsFor(color).map(MonsterPhrases.food)))
      ..writeln();
  }
  return out.toString();
}
