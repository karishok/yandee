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

  /// Outlines are the same when they have the same corners in the same
  /// order. Several objects can share one — every piece of a path carries
  /// the whole path's outline.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ObjectOutline || other.points.length != points.length) return false;
    for (var i = 0; i < points.length; i++) {
      if (other.points[i] != points[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(points);
}
