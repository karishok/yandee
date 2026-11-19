import 'dart:io';

import 'src/shapes_parts.dart';

/// Writes `docs/shapes_phrases.md` — every phrase of the "Фигурки" game to
/// record, part by part, with its file name — from the game's own phrase
/// list, so the document can't drift from the code.
///
/// Usage: `dart run tool/write_shapes_phrases_doc.dart`
void main() {
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Запусти из корня репозитория.');
    exitCode = 1;
    return;
  }
  File('docs/shapes_phrases.md').writeAsStringSync(buildShapesPhrasesDoc());
  stdout.writeln('docs/shapes_phrases.md');
}

String buildShapesPhrasesDoc() {
  final parts = buildShapesParts();
  final total = parts.fold<int>(0, (sum, part) => sum + part.clips.length);
  final out = StringBuffer()
    ..writeln('# Игра «Фигурки» — фразы для записи')
    ..writeln()
    ..writeln('<!-- Этот файл создан командой `dart run tool/write_shapes_phrases_doc.dart`. '
        'Не правь его руками — правки пропадут при следующем запуске. -->')
    ..writeln()
    ..writeln('Всего **$total фраз** в **${parts.length} частях**. Одна часть — одна запись в Logic '
        'и одна команда. Записывают так же, как фразы «Монстриков» (`docs/monsters_phrases.md`): '
        'фразы подряд сверху вниз, между ними молчать около 2 секунд, Bounce в WAV, файл — в папку '
        '`tool`, затем команда части.')
    ..writeln()
    ..writeln('Длинные реплики игра собирает из целых фраз: «Новая фигурка!» + «Звезда!», '
        '«Домик!» + «Ура!». Поэтому каждое слово записывается один раз.')
    ..writeln()
    ..writeln('## Советы по интонации')
    ..writeln()
    ..writeln('- Названия форм — радостно и ясно, как будто показываешь игрушку: запись звучит и '
        'сама по себе, и после «Новая фигурка!».')
    ..writeln('- Названия картинок — с удивлением и восторгом: «смотри, что получилось!»; после '
        'них игра скажет «Ура!».')
    ..writeln('- «Не сюда!» — мягко, без упрёка: это подсказка, а не ошибка.')
    ..writeln();
  for (final part in parts) {
    out
      ..writeln('## Часть ${part.number}. ${part.title}')
      ..writeln()
      ..writeln('${part.clips.length} фраз. Команда после записи:')
      ..writeln()
      ..writeln('```bash')
      ..writeln('dart run tool/slice_voiceover.dart ${part.filter} запись.wav')
      ..writeln('```')
      ..writeln()
      ..writeln('| № | Что сказать | Файл |')
      ..writeln('|---|---|---|');
    for (var i = 0; i < part.clips.length; i++) {
      final clip = part.clips[i];
      out.writeln('| ${i + 1} | ${clip.text} | `${clip.id}.wav` |');
    }
    out.writeln();
  }
  return out.toString();
}
