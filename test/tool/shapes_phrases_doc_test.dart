import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';

import '../../tool/write_shapes_phrases_doc.dart';

void main() {
  test('docs/shapes_phrases.md matches the game\'s phrase list', () {
    expect(File('docs/shapes_phrases.md').readAsStringSync(), buildShapesPhrasesDoc(),
        reason: 'run: dart run tool/write_shapes_phrases_doc.dart');
  });

  test('the document lists every phrase with its file name and the slicing commands', () {
    final doc = buildShapesPhrasesDoc();
    for (final clip in ShapePhrases.allClips) {
      expect(doc, contains('| ${clip.text} | `${clip.id}.wav` |'));
    }
    for (var part = 1; part <= 3; part++) {
      expect(doc, contains('dart run tool/slice_voiceover.dart shapes-$part запись.wav'));
    }
  });
}
