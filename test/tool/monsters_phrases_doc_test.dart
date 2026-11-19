import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';

import '../../tool/src/monsters_parts.dart';
import '../../tool/write_monsters_phrases_doc.dart';

void main() {
  test('docs/monsters_phrases.md matches the game\'s phrase list', () {
    expect(
      File('docs/monsters_phrases.md').readAsStringSync(),
      buildMonstersPhrasesDoc(),
      reason: 'run: dart run tool/write_monsters_phrases_doc.dart',
    );
  });

  test('the document lists every phrase with its file name', () {
    final doc = buildMonstersPhrasesDoc();
    for (final clip in MonsterPhrases.allClips) {
      expect(doc, contains('| ${clip.text} | `${clip.id}.wav` |'));
    }
  });

  test('the document gives the slicing command for every part', () {
    final doc = buildMonstersPhrasesDoc();
    for (final part in buildMonstersParts()) {
      expect(doc, contains('## Часть ${part.number}. ${part.title}'));
      expect(doc, contains('dart run tool/slice_voiceover.dart ${part.filter} запись.wav'));
    }
  });
}
