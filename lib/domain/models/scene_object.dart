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
  });

  final String id;
  final String label;
  final String audio;
  final ObjectRect rect;

  factory SceneObject.fromJson(Map<String, dynamic> json) {
    return SceneObject(
      id: json['id'] as String,
      label: json['label'] as String,
      audio: json['audio'] as String,
      rect: ObjectRect.fromJson(json['rect'] as Map<String, dynamic>),
    );
  }

  /// Objects are identified by id everywhere in the app (mode logic,
  /// widget-test finders), so equality/hashing only look at it.
  @override
  bool operator ==(Object other) => other is SceneObject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
