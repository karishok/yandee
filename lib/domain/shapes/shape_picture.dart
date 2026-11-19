import 'shape_kind.dart';

/// The side of a picture card, in the units its pieces are laid out in.
const double cardSize = 300;

/// A rectangle on the picture card, in card units (0…[cardSize]).
class CardBox {
  const CardBox(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  double get area => width * height;
  ({double x, double y}) get center => (x: x + width / 2, y: y + height / 2);

  /// True if the point lies inside the box grown by [margin] on every side.
  bool contains(double px, double py, {double margin = 0}) =>
      px >= x - margin && px <= right + margin && py >= y - margin && py <= bottom + margin;
}

/// One piece of a picture: its shape, the box it fills and how it is turned.
class ShapeSlot {
  const ShapeSlot(this.kind, this.box, {this.quarterTurns = 0, this.stays = false, this.pulses = false});

  final ShapeKind kind;

  /// The box the piece fills once turned.
  final CardBox box;

  /// Quarter turns clockwise from the upright shape: a triangle points up, a
  /// semicircle has its flat side down, a crescent opens to the right.
  final int quarterTurns;

  /// Stays put when the finished picture moves (the star beside the rocket).
  final bool stays;

  /// Pulses on its own when the finished picture comes alive (night stars).
  final bool pulses;

  /// The size of the upright shape, before it is turned into [box].
  ({double width, double height}) get upright =>
      quarterTurns.isOdd ? (width: box.height, height: box.width) : (width: box.width, height: box.height);
}

/// How a finished picture comes alive.
enum PictureMotion { wiggle, hop, chug, drive, launch, swim, rock, sway, pulse }

/// A picture the child builds out of shapes.
class ShapePicture {
  const ShapePicture({
    required this.id,
    required this.word,
    required this.motion,
    required this.slots,
    this.pivot = (x: 150.0, y: 150.0),
  });

  /// Used in file names: `picture_house.wav`, `backgrounds/house.jpg`.
  final String id;

  /// What the voice calls it: «Домик».
  final String word;

  final PictureMotion motion;

  /// Later slots lie on top of earlier ones (the window over the wall).
  final List<ShapeSlot> slots;

  /// The point of the card the picture turns around when it moves.
  final ({double x, double y}) pivot;
}

/// The chain of pictures, in the order a child meets them: each brings at
/// most one new shape (the first brings two). Boxes are carried over from
/// the prototype (`docs/prototypes/shapes.html`).
const List<ShapePicture> shapePictures = [
  ShapePicture(id: 'ice_cream', word: 'Мороженое', motion: PictureMotion.wiggle, pivot: (x: 150, y: 280), slots: [
    ShapeSlot(ShapeKind.triangle, CardBox(105, 140, 90, 136), quarterTurns: 2),
    ShapeSlot(ShapeKind.circle, CardBox(88, 50, 124, 124)),
  ]),
  ShapePicture(id: 'house', word: 'Домик', motion: PictureMotion.hop, pivot: (x: 150, y: 290), slots: [
    ShapeSlot(ShapeKind.square, CardBox(75, 135, 150, 150)),
    ShapeSlot(ShapeKind.triangle, CardBox(48, 38, 204, 108)),
    ShapeSlot(ShapeKind.circle, CardBox(94, 162, 64, 64)),
  ]),
  ShapePicture(id: 'car', word: 'Машинка', motion: PictureMotion.drive, slots: [
    ShapeSlot(ShapeKind.square, CardBox(82, 62, 140, 140)),
    ShapeSlot(ShapeKind.circle, CardBox(66, 176, 74, 74)),
    ShapeSlot(ShapeKind.circle, CardBox(166, 176, 74, 74)),
  ]),
  ShapePicture(id: 'tree', word: 'Ёлочка', motion: PictureMotion.wiggle, pivot: (x: 150, y: 280), slots: [
    ShapeSlot(ShapeKind.square, CardBox(122, 220, 56, 56)),
    ShapeSlot(ShapeKind.triangle, CardBox(52, 95, 196, 140)),
    ShapeSlot(ShapeKind.triangle, CardBox(84, 22, 132, 108)),
  ]),
  ShapePicture(id: 'train', word: 'Паровозик', motion: PictureMotion.chug, slots: [
    ShapeSlot(ShapeKind.rectangle, CardBox(26, 138, 156, 74)),
    ShapeSlot(ShapeKind.square, CardBox(170, 92, 118, 118)),
    ShapeSlot(ShapeKind.circle, CardBox(44, 182, 70, 70)),
    ShapeSlot(ShapeKind.circle, CardBox(194, 182, 70, 70)),
  ]),
  ShapePicture(id: 'fish', word: 'Рыбка', motion: PictureMotion.swim, slots: [
    ShapeSlot(ShapeKind.triangle, CardBox(22, 90, 84, 106), quarterTurns: 1),
    ShapeSlot(ShapeKind.oval, CardBox(70, 82, 168, 118)),
    ShapeSlot(ShapeKind.circle, CardBox(166, 98, 54, 54)),
  ]),
  ShapePicture(id: 'rocket', word: 'Ракета', motion: PictureMotion.launch, slots: [
    ShapeSlot(ShapeKind.rectangle, CardBox(105, 92, 90, 165)),
    ShapeSlot(ShapeKind.triangle, CardBox(105, 26, 90, 74)),
    ShapeSlot(ShapeKind.circle, CardBox(123, 124, 54, 54)),
    ShapeSlot(ShapeKind.star, CardBox(204, 34, 78, 74), stays: true),
  ]),
  ShapePicture(id: 'bear', word: 'Мишка', motion: PictureMotion.rock, pivot: (x: 150, y: 290), slots: [
    ShapeSlot(ShapeKind.oval, CardBox(88, 148, 124, 138)),
    ShapeSlot(ShapeKind.circle, CardBox(94, 46, 112, 112)),
    ShapeSlot(ShapeKind.heart, CardBox(120, 196, 60, 54)),
  ]),
  ShapePicture(id: 'boat', word: 'Кораблик', motion: PictureMotion.rock, pivot: (x: 150, y: 236), slots: [
    ShapeSlot(ShapeKind.triangle, CardBox(62, 52, 80, 120)),
    ShapeSlot(ShapeKind.triangle, CardBox(160, 72, 74, 100)),
    ShapeSlot(ShapeKind.semicircle, CardBox(48, 176, 204, 94), quarterTurns: 2),
  ]),
  ShapePicture(id: 'kite', word: 'Воздушный змей', motion: PictureMotion.sway, pivot: (x: 40, y: 275), slots: [
    ShapeSlot(ShapeKind.rhombus, CardBox(80, 22, 140, 182)),
    ShapeSlot(ShapeKind.triangle, CardBox(113, 199, 54, 54), quarterTurns: 1),
    ShapeSlot(ShapeKind.triangle, CardBox(60, 230, 54, 54), quarterTurns: 3),
  ]),
  ShapePicture(id: 'night_sky', word: 'Ночное небо', motion: PictureMotion.pulse, slots: [
    ShapeSlot(ShapeKind.crescent, CardBox(40, 32, 144, 144)),
    ShapeSlot(ShapeKind.star, CardBox(196, 40, 80, 76), pulses: true),
    ShapeSlot(ShapeKind.star, CardBox(170, 150, 66, 63), pulses: true),
  ]),
  ShapePicture(id: 'clown', word: 'Клоун', motion: PictureMotion.hop, pivot: (x: 150, y: 290), slots: [
    ShapeSlot(ShapeKind.circle, CardBox(72, 96, 156, 156)),
    ShapeSlot(ShapeKind.triangle, CardBox(98, 6, 104, 100)),
    ShapeSlot(ShapeKind.circle, CardBox(123, 156, 54, 54)),
    ShapeSlot(ShapeKind.heart, CardBox(72, 184, 54, 50)),
    ShapeSlot(ShapeKind.heart, CardBox(174, 184, 54, 50)),
  ]),
];
