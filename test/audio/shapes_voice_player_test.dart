import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/shapes_voice.dart';
import 'package:yandee/audio/shapes_voice_player.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';

void main() {
  test('a line plays the live recordings of the game', () {
    expect(shapesVoiceAssets(ShapePhrases.meet(ShapeKind.star), {
      'assets/audio/shapes/new_shape.wav',
      'assets/audio/shapes/shape_star.wav',
    }), ['assets/audio/shapes/new_shape.wav', 'assets/audio/shapes/shape_star.wav']);
  });

  test('every sound effect the game plays is in assets/audio/system/', () {
    for (final sfx in ShapesSfx.values) {
      expect(File('assets/audio/system/${sfx.fileName}.wav').existsSync(), isTrue, reason: sfx.name);
    }
  });
}
