import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/domain/shapes/shapes_game.dart';

// A wall with a window on it under a roof; two wheels; a star and a ball.
const _house = ShapePicture(id: 'a', word: 'А', motion: PictureMotion.hop, slots: [
  ShapeSlot(ShapeKind.square, CardBox(50, 100, 200, 180)),
  ShapeSlot(ShapeKind.circle, CardBox(80, 140, 60, 60)),
  ShapeSlot(ShapeKind.triangle, CardBox(40, 10, 220, 90)),
]);
const _wheels = ShapePicture(id: 'b', word: 'Б', motion: PictureMotion.drive, slots: [
  ShapeSlot(ShapeKind.circle, CardBox(20, 200, 70, 70)),
  ShapeSlot(ShapeKind.circle, CardBox(200, 200, 70, 70)),
]);
const _sky = ShapePicture(id: 'c', word: 'В', motion: PictureMotion.pulse, slots: [
  ShapeSlot(ShapeKind.star, CardBox(100, 100, 80, 76)),
  ShapeSlot(ShapeKind.circle, CardBox(10, 10, 60, 60)),
]);

ShapesGame _game([int seed = 1]) => ShapesGame(random: Random(seed), pictures: const [_house, _wheels, _sky]);

/// A fresh game whose first piece is of [kind].
ShapesGame _gameWithPiece(ShapeKind kind) {
  for (var seed = 0; seed < 200; seed++) {
    final game = _game(seed);
    if (game.nextPiece().kind == kind) return game;
  }
  throw StateError('no seed gives a $kind first');
}

/// Places every piece of the current picture; returns the last drop.
DropResult _finish(ShapesGame game) {
  late DropResult last;
  while (!game.pictureComplete) {
    final slot = game.pieceSlot ?? game.nextPiece().slot;
    last = game.drop(slot);
  }
  return last;
}

void main() {
  test('starts on the first picture with nothing placed and no piece on the mat', () {
    final game = _game();
    expect(game.pictureIndex, 0);
    expect(game.filled, isEmpty);
    expect(game.pieceSlot, isNull);
    expect(game.metKinds, isEmpty);
  });

  test('pieces come one at a time, each slot once, in a shuffled order', () {
    final firsts = <int>{};
    for (var seed = 0; seed < 20; seed++) {
      final game = _game(seed);
      final seen = <int>[];
      while (!game.pictureComplete) {
        final piece = game.nextPiece();
        seen.add(piece.slot);
        game.drop(piece.slot);
      }
      expect(seen.toSet(), {0, 1, 2});
      firsts.add(seen.first);
    }
    expect(firsts.length, greaterThan(1));
  });

  test('a shape is new only the first time it comes up', () {
    final game = _game();
    while (!game.pictureComplete) {
      final piece = game.nextPiece();
      expect(piece.firstMeeting, isTrue);
      game.drop(piece.slot);
    }
    game.nextPicture();
    final wheel = game.nextPiece();
    expect(wheel.kind, ShapeKind.circle);
    expect(wheel.firstMeeting, isFalse);
    expect(game.metKinds, {ShapeKind.square, ShapeKind.circle, ShapeKind.triangle});
  });

  test('a wrong shape changes nothing and the piece stays on the mat', () {
    final game = _gameWithPiece(ShapeKind.circle);
    final result = game.drop(0); // the wall is a square
    expect(result.accepted, isFalse);
    expect(game.filled, isEmpty);
    expect(game.pieceKind, ShapeKind.circle);
  });

  test('a piece may fill any free slot of its shape; the other is offered later', () {
    final game = _game();
    _finish(game);
    game.nextPicture();
    final first = game.nextPiece().slot;
    final other = 1 - first;
    expect(game.drop(other).accepted, isTrue);
    expect(game.filled, {other});
    expect(game.nextPiece().slot, first);
  });

  test('misuse is refused loudly', () {
    final game = _game();
    expect(() => game.drop(0), throwsStateError);
    final piece = game.nextPiece();
    expect(game.nextPiece, throwsStateError);
    game.drop(piece.slot);
    game.nextPiece();
    expect(() => game.drop(piece.slot), throwsStateError);
    expect(game.nextPicture, throwsStateError);
  });

  test('the chain goes in order, ends once, then pictures come in any order but never twice running', () {
    final game = _game();
    expect(_finish(game).pictureComplete, isTrue);
    game.nextPicture();
    expect(game.pictureIndex, 1);
    expect(_finish(game).chainComplete, isFalse);
    game.nextPicture();
    expect(game.pictureIndex, 2);
    final last = _finish(game);
    expect(last.chainComplete, isTrue);
    expect(game.chainDone, isTrue);

    var previous = game.pictureIndex;
    for (var i = 0; i < 30; i++) {
      game.nextPicture();
      expect(game.pictureIndex, isNot(previous));
      previous = game.pictureIndex;
      expect(_finish(game).chainComplete, isFalse);
    }
  });

  group('slotAt', () {
    test('nothing is found without a piece on the mat, or far from every slot', () {
      final game = _game();
      expect(game.slotAt(150, 200), isNull);
      game.nextPiece();
      expect(game.slotAt(295, 295), isNull);
    });

    test('the smallest slot under the finger wins when none has the right shape', () {
      final game = _gameWithPiece(ShapeKind.triangle);
      expect(game.slotAt(100, 160), 1); // the window, on top of the wall
      expect(game.slotAt(200, 250), 0); // the wall away from the window
    });

    test('a slot of the right shape wins, even within the margin only', () {
      final circle = _gameWithPiece(ShapeKind.circle);
      expect(circle.slotAt(160, 160, margin: 24), 1); // 20 past the window's edge
      expect(circle.slotAt(160, 160), 0);
      final square = _gameWithPiece(ShapeKind.square);
      expect(square.slotAt(100, 160), 0); // over the window, but the wall is the square
    });

    test('filled slots are not found', () {
      final game = _gameWithPiece(ShapeKind.circle);
      game.drop(1);
      game.nextPiece();
      expect(game.slotAt(100, 160), 0);
    });
  });

  test('the real chain starts with the ice cream', () {
    final game = ShapesGame(random: Random(3));
    expect(game.picture.id, 'ice_cream');
    expect(game.nextPiece().firstMeeting, isTrue);
  });
}
