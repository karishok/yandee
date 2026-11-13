import 'scene_object.dart';
import 'scene_variant.dart';

class Scene {
  const Scene({
    required this.id,
    required this.version,
    required this.title,
    required this.minAgeMonths,
    required this.background,
    required this.objects,
    this.realistic,
  });

  final String id;
  final int version;
  final String title;
  final int minAgeMonths;
  final String background;
  final List<SceneObject> objects;

  /// The scene's optional realistic picture, which the child can switch to
  /// to see that the same things can look different. Null for the many
  /// scenes that only have the default illustration.
  final SceneVariant? realistic;

  /// The scene's objects as they sit on the picture being shown: on the
  /// default illustration, or — with [realistic] set, when the scene has
  /// that variant — moved to the realistic picture's tap zones. Order is
  /// the same either way, since it is also the tap priority.
  List<SceneObject> objectsFor({required bool realistic}) {
    final variant = this.realistic;
    if (!realistic || variant == null) return objects;
    return [
      for (final object in objects)
        if (variant.rects[object.id] case final rect?) object.withRect(rect) else object,
    ];
  }

  factory Scene.fromJson(Map<String, dynamic> json) {
    return Scene(
      id: json['id'] as String,
      version: json['version'] as int,
      title: json['title'] as String,
      minAgeMonths: json['minAgeMonths'] as int,
      background: json['background'] as String,
      objects: (json['objects'] as List<dynamic>)
          .map((e) => SceneObject.fromJson(e as Map<String, dynamic>))
          .toList(),
      realistic: json['realistic'] == null
          ? null
          : SceneVariant.fromJson(json['realistic'] as Map<String, dynamic>),
    );
  }
}
