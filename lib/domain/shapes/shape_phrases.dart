import '../voice/voice_line.dart';
import 'shape_kind.dart';
import 'shape_picture.dart';

export '../voice/voice_line.dart';

/// Every phrase of the "Фигурки" game. Longer lines are whole phrases said
/// one after another: «Новая фигурка!» + «Звезда!», «Домик!» + «Ура!» — so
/// each word is recorded once.
abstract final class ShapePhrases {
  static const intro = VoiceClip('intro', 'Собери картинку из фигурок!');
  static const newShape = VoiceClip('new_shape', 'Новая фигурка!');
  static const notHere = VoiceClip('not_here', 'Не сюда!');
  static const hooray = VoiceClip('hooray', 'Ура!');
  static const win = VoiceClip('win', 'Ура! Ты знаешь все фигурки!');

  /// «Круг!»
  static VoiceClip shape(ShapeKind kind) => VoiceClip('shape_${kind.name}', '${kind.word}!');

  /// «Домик!»
  static VoiceClip picture(ShapePicture picture) => VoiceClip('picture_${picture.id}', '${picture.word}!');

  static const introLine = VoiceLine([intro]);
  static const notHereLine = VoiceLine([notHere]);
  static const winLine = VoiceLine([win]);

  /// A piece names its shape: «Звезда!».
  static VoiceLine name(ShapeKind kind) => VoiceLine([shape(kind)]);

  /// A shape met for the first time: «Новая фигурка! Звезда!».
  static VoiceLine meet(ShapeKind kind) => VoiceLine([newShape, shape(kind)]);

  /// A finished picture: «Домик! Ура!».
  static VoiceLine done(ShapePicture picture) => VoiceLine([ShapePhrases.picture(picture), hooray]);

  /// Every clip, in the order they are recorded: the shapes, the pictures,
  /// then the general phrases.
  static List<VoiceClip> get allClips => [
        for (final kind in ShapeKind.values) shape(kind),
        for (final picture in shapePictures) ShapePhrases.picture(picture),
        intro,
        newShape,
        notHere,
        hooray,
        win,
      ];
}
