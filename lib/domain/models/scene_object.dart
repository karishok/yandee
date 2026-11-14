import 'object_outline.dart';
import 'object_rect.dart';

/// A single tappable object in a scene. `audio` and (via [rect]) tap zone
/// are shared by every mode; future modes add their own optional fields
/// here without breaking scenes/app versions that don't read them.
class SceneObject {
  const SceneObject({
    required this.id,
    required this.label,
    required this.audio,
    required this.rect,
    this.outline,
  });

  final String id;
  final String label;
  final String audio;
  final ObjectRect rect;

  /// The object's silhouette on the picture, for the objects that have one
  /// marked up. Having one on the scene's default picture is what makes an
  /// object something to find in the flashlight game.
  final ObjectOutline? outline;

  factory SceneObject.fromJson(Map<String, dynamic> json) {
    return SceneObject(
      id: json['id'] as String,
      label: json['label'] as String,
      audio: json['audio'] as String,
      rect: ObjectRect.fromJson(json['rect'] as Map<String, dynamic>),
      outline: json['outline'] == null ? null : ObjectOutline.fromJson(json['outline'] as List<dynamic>),
    );
  }

  /// The same object as it sits on a different picture.
  SceneObject placedAt({required ObjectRect rect, required ObjectOutline? outline}) =>
      SceneObject(id: id, label: label, audio: audio, rect: rect, outline: outline);

  /// Objects are identified by id everywhere in the app (mode logic,
  /// widget-test finders), so equality/hashing only look at it.
  @override
  bool operator ==(Object other) => other is SceneObject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
