import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';

void main() {
  test('twelve pictures in the order of the spec', () {
    expect(shapePictures.map((p) => p.id), [
      'ice_cream', 'house', 'car', 'tree', 'train', 'fish',
      'rocket', 'bear', 'boat', 'kite', 'night_sky', 'clown',
    ]);
    expect(shapePictures.first.word, 'Мороженое');
  });

  test('each picture brings at most one new shape (the first brings two), in teaching order', () {
    final met = <ShapeKind>{};
    for (final (index, picture) in shapePictures.indexed) {
      final before = met.length;
      met.addAll(picture.slots.map((slot) => slot.kind));
      expect(met.length - before, lessThanOrEqualTo(index == 0 ? 2 : 1), reason: picture.id);
      expect(met, ShapeKind.values.take(met.length).toSet(), reason: 'shapes are met in teaching order (${picture.id})');
    }
    expect(met, ShapeKind.values.toSet());
  });

  test('every piece is big enough for a small finger and lies on the card', () {
    for (final picture in shapePictures) {
      expect(picture.slots.length, inInclusiveRange(2, 5), reason: picture.id);
      for (final slot in picture.slots) {
        final box = slot.box;
        expect(box.width, greaterThanOrEqualTo(50), reason: '${picture.id} ${slot.kind}');
        expect(box.height, greaterThanOrEqualTo(50), reason: '${picture.id} ${slot.kind}');
        expect(box.x >= 0 && box.y >= 0 && box.right <= cardSize && box.bottom <= cardSize, isTrue,
            reason: '${picture.id} ${slot.kind}');
      }
    }
  });

  test('circles and squares are round and square; rectangles and ovals are not', () {
    for (final picture in shapePictures) {
      for (final slot in picture.slots) {
        final up = slot.upright;
        switch (slot.kind) {
          case ShapeKind.circle || ShapeKind.square:
            expect(up.width, up.height, reason: '${picture.id} ${slot.kind}');
          case ShapeKind.rectangle || ShapeKind.oval:
            expect(up.width, isNot(up.height), reason: '${picture.id} ${slot.kind}');
          default:
            break;
        }
      }
    }
  });

  test('a turned slot swaps width and height for its upright shape', () {
    const slot = ShapeSlot(ShapeKind.triangle, CardBox(22, 90, 84, 106), quarterTurns: 1);
    expect(slot.upright, (width: 106.0, height: 84.0));
  });

  test('a box contains points inside it and, with a margin, near it', () {
    const box = CardBox(10, 20, 30, 40);
    expect(box.contains(25, 30), isTrue);
    expect(box.contains(45, 30), isFalse);
    expect(box.contains(45, 30, margin: 6), isTrue);
    expect(box.area, 1200);
    expect(box.center, (x: 25.0, y: 40.0));
  });
}
