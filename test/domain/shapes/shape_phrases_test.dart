import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';

void main() {
  test('27 clips with unique, file-safe ids', () {
    final clips = ShapePhrases.allClips;
    expect(clips, hasLength(27));
    expect(clips.map((c) => c.id).toSet(), hasLength(27));
    for (final clip in clips) {
      expect(clip.id, matches(RegExp(r'^[a-z_]+$')), reason: clip.text);
    }
  });

  test('shapes and pictures say their names', () {
    expect(ShapePhrases.shape(ShapeKind.circle).id, 'shape_circle');
    expect(ShapePhrases.shape(ShapeKind.circle).text, 'Круг!');
    expect(ShapePhrases.picture(shapePictures.first).id, 'picture_ice_cream');
    expect(ShapePhrases.picture(shapePictures.first).text, 'Мороженое!');
  });

  test('longer lines are put together from whole phrases', () {
    expect(ShapePhrases.introLine.text, 'Собери картинку из фигурок!');
    expect(ShapePhrases.name(ShapeKind.star).text, 'Звезда!');
    expect(ShapePhrases.meet(ShapeKind.star).text, 'Новая фигурка! Звезда!');
    expect(ShapePhrases.notHereLine.text, 'Не сюда!');
    expect(ShapePhrases.done(shapePictures[1]).text, 'Домик! Ура!');
    expect(ShapePhrases.winLine.text, 'Ура! Ты знаешь все фигурки!');
  });

  test('the clip list runs shapes, pictures, then the general phrases — the recording order', () {
    final texts = ShapePhrases.allClips.map((c) => c.text).toList();
    expect(texts.take(10), [for (final kind in ShapeKind.values) '${kind.word}!']);
    expect(texts.skip(10).take(12), [for (final p in shapePictures) '${p.word}!']);
    expect(texts.skip(22), [
      'Собери картинку из фигурок!',
      'Новая фигурка!',
      'Не сюда!',
      'Ура!',
      'Ура! Ты знаешь все фигурки!',
    ]);
  });
}
