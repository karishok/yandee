import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_phrases.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';

/// One sitting's worth of "Фигурки" phrases (at most ten), read in this
/// order into one recording and cut apart by
/// `tool/slice_voiceover.dart shapes-<number>`.
class ShapesPart {
  const ShapesPart(this.number, this.title, this.clips);

  final int number;
  final String title;
  final List<VoiceClip> clips;

  String get filter => 'shapes-$number';
}

List<ShapesPart> buildShapesParts() => [
      ShapesPart(1, 'Формы', [for (final kind in ShapeKind.values) ShapePhrases.shape(kind)]),
      ShapesPart(2, 'Картинки 1–10', [for (final picture in shapePictures.take(10)) ShapePhrases.picture(picture)]),
      ShapesPart(3, 'Последние картинки и общие фразы', [
        for (final picture in shapePictures.skip(10)) ShapePhrases.picture(picture),
        ShapePhrases.intro,
        ShapePhrases.newShape,
        ShapePhrases.notHere,
        ShapePhrases.hooray,
        ShapePhrases.win,
      ]),
    ];
