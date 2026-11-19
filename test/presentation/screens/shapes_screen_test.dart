import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/shapes_voice.dart';
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

Future<_Harness> _start(WidgetTester tester, {int seed = 1}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final harness = _Harness(tester, FakeShapesVoice());
  await tester.pumpWidget(MaterialApp(
    home: ShapesScreen(
      voiceFactory: () => harness.voice,
      gameFactory: () => harness.game = ShapesGame(random: Random(seed)),
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

  testWidgets('tapping the piece or an empty place says the shape', (tester) async {
    final h = await _start(tester);
    await tester.tapAt(h.piece);
    await h.run(const Duration(milliseconds: 300));
    expect(h.voice.said.last, '${h.game.pieceKind!.word}!');
    final other = h.wrongSlot;
    await tester.tapAt(h.slotCenter(other));
    await h.run(const Duration(milliseconds: 300));
    expect(h.voice.said.last, '${h.game.picture.slots[other].kind.word}!');
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
}
