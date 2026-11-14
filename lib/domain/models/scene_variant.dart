import 'object_outline.dart';
import 'object_rect.dart';

/// An alternative picture of the same scene — e.g. a realistic rendering
/// of what the default illustration draws as a cartoon. It shows the same
/// objects (same words, same audio), but they sit in different places on
/// the picture, so the variant carries its own tap zones and outlines.
class SceneVariant {
  const SceneVariant({required this.background, required this.rects, this.outlines = const {}});

  /// File name of this variant's picture, next to the scene's other files.
  final String background;

  /// This variant's tap zones, keyed by `SceneObject.id`. An object with no
  /// entry here keeps the tap zone it has on the default picture.
  final Map<String, ObjectRect> rects;

  /// This variant's silhouettes, keyed by `SceneObject.id`, for the objects
  /// that have one marked up on this picture.
  final Map<String, ObjectOutline> outlines;

  factory SceneVariant.fromJson(Map<String, dynamic> json) {
    return SceneVariant(
      background: json['background'] as String,
      rects: (json['rects'] as Map<String, dynamic>? ?? const {}).map(
        (objectId, rect) => MapEntry(objectId, ObjectRect.fromJson(rect as Map<String, dynamic>)),
      ),
      outlines: (json['outlines'] as Map<String, dynamic>? ?? const {}).map(
        (objectId, outline) => MapEntry(objectId, ObjectOutline.fromJson(outline as List<dynamic>)),
      ),
    );
  }
}
