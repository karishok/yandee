import 'dart:math';

import 'shape_kind.dart';
import 'shape_picture.dart';

/// A piece has been put on the mat.
class PieceShown {
  const PieceShown({required this.slot, required this.kind, required this.firstMeeting});

  /// The slot of the current picture the piece was cut for.
  final int slot;
  final ShapeKind kind;

  /// The child meets this shape for the first time in this game:
  /// «Новая фигурка! …».
  final bool firstMeeting;
}

/// What happened when the piece was let go over a slot.
class DropResult {
  const DropResult({
    required this.accepted,
    required this.slot,
    required this.pictureComplete,
    required this.chainComplete,
  });

  /// The shapes matched and the slot is filled now. Otherwise nothing
  /// changed: the piece goes back to the mat.
  final bool accepted;

  /// The slot it was let go over.
  final int slot;

  /// That was the last piece of the picture.
  final bool pictureComplete;

  /// That finished the last picture of the chain for the first time.
  final bool chainComplete;
}

/// The rules of the "Фигурки" game, with no drawing, sound or timing in
/// them: which picture is being built, which slots are filled, which piece
/// lies on the mat and which shapes the child has met.
///
/// The screen drives it: [nextPiece], then [drop] until the picture is
/// complete, then [nextPicture]. Pictures follow the chain in order; once
/// the last one is done they come in random order, never the same twice in
/// a row. Nothing is remembered between games.
class ShapesGame {
  ShapesGame({Random? random, List<ShapePicture> pictures = shapePictures})
      : _random = random ?? Random(),
        pictures = List.unmodifiable(pictures) {
    if (pictures.length < 2) throw ArgumentError.value(pictures, 'pictures', 'needs at least two');
    _startPicture(0);
  }

  final Random _random;
  final List<ShapePicture> pictures;

  int _index = 0;
  final Set<int> _filled = {};
  List<int> _order = const [];
  int? _pieceSlot;
  final Set<ShapeKind> _met = {};
  bool _chainDone = false;

  int get pictureIndex => _index;
  ShapePicture get picture => pictures[_index];

  /// Slots of the current picture that hold their piece.
  Set<int> get filled => Set.unmodifiable(_filled);

  /// The slot the piece on the mat was cut for; null when the mat is empty.
  int? get pieceSlot => _pieceSlot;

  ShapeKind? get pieceKind {
    final slot = _pieceSlot;
    return slot == null ? null : picture.slots[slot].kind;
  }

  Set<ShapeKind> get metKinds => Set.unmodifiable(_met);

  /// The whole chain has been built once.
  bool get chainDone => _chainDone;

  bool get pictureComplete => _filled.length == picture.slots.length;

  void _startPicture(int index) {
    _index = index;
    _filled.clear();
    _pieceSlot = null;
    _order = [for (var slot = 0; slot < picture.slots.length; slot++) slot]..shuffle(_random);
  }

  /// Puts the next piece of the picture on the mat.
  PieceShown nextPiece() {
    if (_pieceSlot != null) throw StateError('A piece is already on the mat');
    if (pictureComplete) throw StateError('The picture is complete');
    final slot = _order.firstWhere((slot) => !_filled.contains(slot));
    _pieceSlot = slot;
    final kind = picture.slots[slot].kind;
    return PieceShown(slot: slot, kind: kind, firstMeeting: _met.add(kind));
  }

  /// Lets the piece go over [slot]. Any free slot of the piece's shape takes
  /// it; any other leaves everything as it was.
  DropResult drop(int slot) {
    final kind = pieceKind;
    if (kind == null) throw StateError('No piece on the mat');
    if (_filled.contains(slot)) throw StateError('Slot $slot is already filled');
    if (picture.slots[slot].kind != kind) {
      return DropResult(accepted: false, slot: slot, pictureComplete: false, chainComplete: false);
    }
    _filled.add(slot);
    _pieceSlot = null;
    final complete = pictureComplete;
    final chainComplete = complete && !_chainDone && _index == pictures.length - 1;
    if (chainComplete) _chainDone = true;
    return DropResult(accepted: true, slot: slot, pictureComplete: complete, chainComplete: chainComplete);
  }

  /// Moves on from a finished picture.
  void nextPicture() {
    if (!pictureComplete) throw StateError('The picture is not finished');
    if (!_chainDone) {
      _startPicture(_index + 1);
      return;
    }
    final others = [for (var i = 0; i < pictures.length; i++) if (i != _index) i];
    _startPicture(others[_random.nextInt(others.length)]);
  }

  /// The free slot a finger at ([x], [y]) (card units) points at, or null.
  ///
  /// Slots within [margin] of the point count; among them a slot of the
  /// piece's shape wins, then a slot the point is really inside, and of
  /// what is left the smallest (a window over a wall).
  int? slotAt(double x, double y, {double margin = 0}) {
    final kind = pieceKind;
    if (kind == null) return null;
    final slots = picture.slots;
    final near = [
      for (var i = 0; i < slots.length; i++)
        if (!_filled.contains(i) && slots[i].box.contains(x, y, margin: margin)) i,
    ];
    if (near.isEmpty) return null;
    final sameShape = near.where((i) => slots[i].kind == kind).toList();
    final inside = near.where((i) => slots[i].box.contains(x, y)).toList();
    final pool = sameShape.isNotEmpty ? sameShape : (inside.isNotEmpty ? inside : near);
    pool.sort((a, b) => slots[a].box.area.compareTo(slots[b].box.area));
    return pool.first;
  }
}
