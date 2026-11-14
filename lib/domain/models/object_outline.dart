/// One corner of an [ObjectOutline], normalized (0..1) to the picture.
typedef OutlinePoint = ({double x, double y});

/// An object's silhouette as a closed polygon, relative to the scene's
/// picture — like `ObjectRect`, never device pixels. The flashlight game
/// shows a found object through the dark in this shape.
class ObjectOutline {
  const ObjectOutline(this.points);

  /// The polygon's corners in order; the last one joins back to the first.
  final List<OutlinePoint> points;

  /// Parses `[[x, y], [x, y], ...]`.
  factory ObjectOutline.fromJson(List<dynamic> json) => ObjectOutline([
        for (final point in json.cast<List<dynamic>>())
          (x: (point[0] as num).toDouble(), y: (point[1] as num).toDouble()),
      ]);
}
