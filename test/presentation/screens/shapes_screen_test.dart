import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/shapes_voice.dart';
import 'package:yandee/domain/shapes/shape_kind.dart';
import 'package:yandee/presentation/shapes/shape_picture_view.dart';
import 'package:yandee/domain/shapes/shape_picture.dart';
import 'package:yandee/domain/shapes/shapes_game.dart';
import 'package:yandee/presentation/screens/shapes_screen.dart';

import '../../support/fake_shapes_voice.dart';

class _Harness {
  _Harness(this.tester, this.voice);

  final WidgetTester tester;
  final FakeShapesVoice voice;
  late ShapesGame game;

  Rect get card => tester.getRect(find.byKey(const ValueKey('shapes_card')));

  Offset slotCenter(int slot) {
    final c = card;
    final k = c.width / cardSize;
    final box = game.picture.slots[slot].box;
    return Offset(c.left + box.center.x * k, c.top + box.center.y * k);
  }

  Offset get piece => tester.getCenter(find.byKey(const ValueKey('shapes_piece')));

  /// A free slot of another shape than the piece on the mat.
  int get wrongSlot => [
        for (var i = 0; i < game.picture.slots.length; i++)
          if (!game.filled.contains(i) && game.picture.slots[i].kind != game.pieceKind) i,
      ].first;

  Future<void> run(Duration duration) async {
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> dragPieceTo(Offset target) async {
    final gesture = await tester.startGesture(piece);
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveTo(target);
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  /// Puts every piece of the current picture in place.
  Future<void> buildPicture() async {
    while (!game.pictureComplete) {
      await dragPieceTo(slotCenter(game.pieceSlot!));
      await run(const Duration(milliseconds: 800));
    }
  }
}

Future<_Harness> _start(WidgetTester tester, {int seed = 1, List<ShapePicture>? pictures}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(tester, FakeShapesVoice());
  await tester.pumpWidget(MaterialApp(
    home: ShapesScreen(
      voiceFactory: () => harness.voice,
      gameFactory: () => harness.game = ShapesGame(random: Random(seed), pictures: pictures ?? shapePictures),
      bundledAssets: () async => const {},
    ),
  ));
  await harness.run(const Duration(milliseconds: 600));
  return harness;
}

void main() {
  testWidgets('greets the child and names the first piece as a new shape', (tester) async {
    final h = await _start(tester);
    expect(h.voice.said, ['Собери картинку из фигурок!', 'Новая фигурка! ${h.game.pieceKind!.word}!']);
    expect(find.byKey(const ValueKey('shapes_piece')), findsOneWidget);
  });

  testWidgets('a piece dragged onto its place stays there and the next one comes', (tester) async {
    final h = await _start(tester);
    final slot = h.game.pieceSlot!;
    await h.dragPieceTo(h.slotCenter(slot));
    await h.run(const Duration(milliseconds: 800));
    expect(h.game.filled, {slot});
    expect(h.voice.sfx, contains(ShapesSfx.placed));
    expect(h.voice.said.last, 'Новая фигурка! ${h.game.pieceKind!.word}!');
  });

  testWidgets('a piece let go over the wrong place says «Не сюда!» and comes back', (tester) async {
    final h = await _start(tester);
    final kind = h.game.pieceKind;
    await h.dragPieceTo(h.slotCenter(h.wrongSlot));
    await h.run(const Duration(milliseconds: 1500));
    expect(h.voice.said.last, 'Не сюда!');
    expect(h.voice.sfx, contains(ShapesSfx.wrong));
    expect(h.game.filled, isEmpty);
    expect(h.game.pieceKind, kind);
    expect(find.byKey(const ValueKey('shapes_piece')), findsOneWidget);
  });

  testWidgets('a piece let go far from every place just goes back, silently', (tester) async {
    final h = await _start(tester);
    final said = h.voice.said.length;
    await h.dragPieceTo(h.card.topLeft + const Offset(2, 2));
    await h.run(const Duration(milliseconds: 600));
    expect(h.voice.said.length, said);
    expect(h.game.filled, isEmpty);
  });

  testWidgets('tapping the piece says its shape', (tester) async {
    final h = await _start(tester);
    await tester.tapAt(h.piece);
    await h.run(const Duration(milliseconds: 300));
    expect(h.voice.said.last, '${h.game.pieceKind!.word}!');
    expect(h.game.filled, isEmpty);
  });

  testWidgets('tapping the right place sends the piece there — no dragging needed', (tester) async {
    final h = await _start(tester);
    final slot = h.game.pieceSlot!;
    await tester.tapAt(h.slotCenter(slot));
    await h.run(const Duration(milliseconds: 800));
    expect(h.game.filled, {slot});
    expect(h.voice.sfx, contains(ShapesSfx.placed));
  });

  testWidgets('tapping a wrong place sends the piece there, «Не сюда!», and it comes back', (tester) async {
    final h = await _start(tester);
    final kind = h.game.pieceKind;
    await tester.tapAt(h.slotCenter(h.wrongSlot));
    await h.run(const Duration(milliseconds: 3300));
    expect(h.voice.said.last, 'Не сюда!');
    expect(h.voice.sfx, contains(ShapesSfx.wrong));
    expect(h.game.filled, isEmpty);
    expect(h.game.pieceKind, kind);
  });

  testWidgets('tapping the card far from every place does nothing', (tester) async {
    final h = await _start(tester);
    final said = h.voice.said.length;
    await tester.tapAt(h.card.topLeft + const Offset(2, 2));
    await h.run(const Duration(milliseconds: 800));
    expect(h.voice.said.length, said);
    expect(h.game.filled, isEmpty);
  });

  testWidgets('a tap on the window, which lies on the wall, still puts the wall piece in place', (tester) async {
    final house = shapePictures.firstWhere((p) => p.id == 'house');
    var seed = 0;
    while (ShapesGame(random: Random(seed), pictures: [house, shapePictures.first]).nextPiece().kind != ShapeKind.square) {
      seed++;
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _Harness(tester, FakeShapesVoice());
    await tester.pumpWidget(MaterialApp(
      home: ShapesScreen(
        voiceFactory: () => h.voice,
        gameFactory: () => h.game = ShapesGame(random: Random(seed), pictures: [house, shapePictures.first]),
        bundledAssets: () async => const {},
      ),
    ));
    await h.run(const Duration(milliseconds: 600));
    expect(h.game.pieceKind, ShapeKind.square);
    await tester.tapAt(h.slotCenter(2));
    await h.run(const Duration(milliseconds: 800));
    expect(h.game.filled, {0});
  });

  testWidgets('a wrong drop pulses the right places, then they go dim again', (tester) async {
    final h = await _start(tester);
    ShapePictureView view() => tester.widget(find.byType(ShapePictureView));
    await h.dragPieceTo(h.slotCenter(h.wrongSlot));
    await h.run(const Duration(milliseconds: 1000));
    expect(view().hinting, isNotEmpty);
    await h.run(const Duration(milliseconds: 2500));
    expect(view().hinting, isEmpty);
  });

  testWidgets('the piece shakes at the wrong place, but not when picked up again', (tester) async {
    final h = await _start(tester);
    double sway() =>
        tester.widget<FractionalTranslation>(find.byKey(const ValueKey('shapes_shake'))).translation.dx;
    final gesture = await tester.startGesture(h.piece);
    await gesture.moveBy(const Offset(0, -30));
    await tester.pump();
    await gesture.moveTo(h.slotCenter(h.wrongSlot));
    await tester.pump();
    await gesture.up();
    var swayed = false;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byKey(const ValueKey('shapes_shake')).evaluate().isNotEmpty && sway().abs() > 0.01) swayed = true;
    }
    expect(swayed, isTrue);
    await h.run(const Duration(milliseconds: 3500));
    final again = await tester.startGesture(h.piece);
    await again.moveBy(const Offset(0, -30));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(sway(), 0);
    }
    await again.up();
    await h.run(const Duration(milliseconds: 600));
  });

  testWidgets('a finished picture says its name with «Ура!», then the next picture comes', (tester) async {
    final h = await _start(tester);
    await h.buildPicture();
    expect(h.voice.said, contains('Мороженое! Ура!'));
    expect(h.voice.sfx, contains(ShapesSfx.pictureDone));
    await h.run(const Duration(seconds: 5));
    expect(h.game.picture.id, 'house');
    expect(h.voice.said.last, anyOf('Новая фигурка! Квадрат!', 'Круг!', 'Треугольник!'));
  });

  testWidgets('the back button leaves the game and the voice is released', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = FakeShapesVoice();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ShapesScreen(voiceFactory: () => voice, bundledAssets: () async => const {}),
          )),
          child: const Text('открыть'),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('shapes_back_button')));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('открыть'), findsOneWidget);
    expect(voice.disposeCalled, isTrue);
  });

  testWidgets('the end of the chain is celebrated once, then the chain starts over', (tester) async {
    final chain = [shapePictures[10], shapePictures[11], shapePictures[2]];
    final h = await _start(tester, seed: 2, pictures: chain);
    final seen = <String>[];
    for (var i = 0; i < 3; i++) {
      seen.add(h.game.picture.id);
      await h.buildPicture();
      await h.run(const Duration(seconds: 8));
    }
    expect(seen.toSet().length, 3);
    expect(h.voice.said.where((t) => t == 'Ура! Ты знаешь все фигурки!'), hasLength(1));
    expect(h.voice.sfx.where((e) => e == ShapesSfx.allDone), hasLength(1));
    final finished = seen.last;
    expect(h.game.picture.id, isNot(finished));
    for (var i = 0; i < 2; i++) {
      await h.buildPicture();
      await h.run(const Duration(seconds: 8));
    }
    expect(h.voice.said.where((t) => t == 'Ура! Ты знаешь все фигурки!'), hasLength(1));
    expect(h.voice.sfx.where((e) => e == ShapesSfx.allDone), hasLength(1));
  });

  testWidgets('a voice that never finishes does not hold the game: the wrong piece still comes back', (tester) async {
    final h = await _start(tester);
    h.voice.holdSpeech();
    await h.dragPieceTo(h.slotCenter(h.wrongSlot));
    await h.run(const Duration(milliseconds: 3300));
    expect(h.voice.said.last, 'Не сюда!');
    final slot = h.game.pieceSlot!;
    await h.dragPieceTo(h.slotCenter(slot));
    await h.run(const Duration(milliseconds: 800));
    expect(h.game.filled, {slot});
    h.voice.finishSpeaking();
    await h.run(const Duration(seconds: 1));
  });

  testWidgets('a voice that never finishes does not hold the game: the next picture still comes', (tester) async {
    final h = await _start(tester);
    final first = h.game.picture.id;
    while (h.game.filled.length < h.game.picture.slots.length - 1) {
      await h.dragPieceTo(h.slotCenter(h.game.pieceSlot!));
      await h.run(const Duration(milliseconds: 800));
    }
    h.voice.holdSpeech();
    await h.dragPieceTo(h.slotCenter(h.game.pieceSlot!));
    await h.run(const Duration(seconds: 6));
    expect(h.game.picture.id, isNot(first));
    expect(find.byKey(const ValueKey('shapes_piece')), findsOneWidget);
    h.voice.finishSpeaking();
    await h.run(const Duration(seconds: 1));
  });

  Future<void> leaveAfter(WidgetTester tester, Future<void> Function(_Harness h) beforeLeaving) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _Harness(tester, FakeShapesVoice());
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ShapesScreen(
              voiceFactory: () => h.voice,
              gameFactory: () => h.game = ShapesGame(random: Random(1)),
              bundledAssets: () async => const {},
            ),
          )),
          child: const Text('открыть'),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await h.run(const Duration(milliseconds: 600));
    await beforeLeaving(h);
    await tester.tap(find.byKey(const ValueKey('shapes_back_button')));
    await h.run(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
    expect(find.text('открыть'), findsOneWidget);
    expect(h.voice.disposeCalled, isTrue);
  }

  testWidgets('leaving right after a drop, while the piece is still in flight, is clean', (tester) async {
    await leaveAfter(tester, (h) async {
      await h.dragPieceTo(h.slotCenter(h.wrongSlot));
    });
  });

  testWidgets('leaving mid-celebration, before the next picture, is clean', (tester) async {
    await leaveAfter(tester, (h) async {
      while (!h.game.pictureComplete) {
        await h.dragPieceTo(h.slotCenter(h.game.pieceSlot!));
        await h.run(const Duration(milliseconds: 800));
      }
      await h.run(const Duration(milliseconds: 500));
    });
  });
}
