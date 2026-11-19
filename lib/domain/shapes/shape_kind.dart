/// The shapes of the "Фигурки" game, in the order a child meets them.
/// `name` doubles as the file id: `shape_circle.wav`.
enum ShapeKind {
  circle('Круг'),
  triangle('Треугольник'),
  square('Квадрат'),
  rectangle('Прямоугольник'),
  oval('Овал'),
  star('Звезда'),
  heart('Сердечко'),
  semicircle('Полукруг'),
  rhombus('Ромб'),
  crescent('Месяц');

  const ShapeKind(this.word);

  /// The shape's name as the voice says it: «Круг».
  final String word;
}
