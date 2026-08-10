/// Normalized (0..1) tap-zone rectangle, relative to the scene's
/// background image — never device pixels, so it's resolution-independent.
class ObjectRect {
  const ObjectRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory ObjectRect.fromJson(Map<String, dynamic> json) {
    return ObjectRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ObjectRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);
}
