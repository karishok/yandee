import 'scene_object.dart';

class Scene {
  const Scene({
    required this.id,
    required this.version,
    required this.title,
    required this.minAgeMonths,
    required this.background,
    required this.objects,
  });

  final String id;
  final int version;
  final String title;
  final int minAgeMonths;
  final String background;
  final List<SceneObject> objects;

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
    );
  }
}
