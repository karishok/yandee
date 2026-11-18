import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/audio/monster_voice.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';
import 'package:yandee/domain/monsters/monsters_game.dart';
import 'package:yandee/presentation/monsters/monster_figure.dart';
import 'package:yandee/presentation/screens/monsters_screen.dart';

import '../../support/fake_monster_voice.dart';

/// The game on screen, with handles on what a test needs to poke and check.
class _Harness {
  _Harness(this.tester, this.voice);

  final WidgetTester tester;
  final FakeMonsterVoice voice;
  late MonstersGame game;
  int gamesStarted = 0;

  Offset slotCenter(int slot) => tester.getCenter(find.byKey(ValueKey('monster_tray_slot_$slot')));
  Offset seatCenter(int seat) => tester.getCenter(find.byKey(ValueKey('monster_seat_$seat')));

  MonsterFigure figure(int seat) => tester.widget<MonsterFigure>(find.byType(MonsterFigure).at(seat));
  MonsterFigureState figureState(int seat) =>
      tester.state<MonsterFigureState>(find.byType(MonsterFigure).at(seat));

  /// The tray slot holding a treat the monster in [seat] eats.
  int slotFor(int seat) => game.tray.indexWhere((food) => food?.color == game.monsters[seat]);

  /// Advances the clock in small steps, as frames would.
  Future<void> run(Duration duration) async {
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += const Duration(milliseconds: 50)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Tap-tap feeding: pick the treat up, then tap the monster. Lets the
  /// whole feeding play out unless [letItPlay] is zero.
  Future<void> feed(int slot, int seat, {Duration letItPlay = const Duration(seconds: 3)}) async {
    await tester.tapAt(slotCenter(slot));
    await tester.pump();
    await tester.tapAt(seatCenter(seat));
    await tester.pump();
    await run(letItPlay);
  }

  /// Feeds the monster in [seat] until it leaves and the newcomer is in.
  Future<void> feedUntilReplaced(int seat) async {
    for (var i = 0; i < MonstersGame.hunger; i++) {
      await feed(slotFor(seat), seat, letItPlay: const Duration(seconds: 10));
    }
  }
}

Future<_Harness> _startGame(WidgetTester tester, {int seed = 1}) async {
  // A phone held upright, as the app is locked to.
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = _Harness(tester, FakeMonsterVoice());
  await tester.pumpWidget(MaterialApp(
    home: MonstersScreen(
      voiceFactory: () => harness.voice,
      gameFactory: () {
        harness.gamesStarted++;
        return harness.game = MonstersGame(random: Random(seed + harness.gamesStarted));
      },
    ),
  ));
  await harness.run(const Duration(milliseconds: 600));
  return harness;
}

void main() {
  testWidgets('shows four monsters and four treats, and tells the child what to do', (tester) async {
    final h = await _startGame(tester);

    expect(find.byType(MonsterFigure), findsNWidgets(4));
    for (var seat = 0; seat < 4; seat++) {
      expect(h.figure(seat).color, h.game.monsters[seat]);
      expect(h.figure(seat).mouth, MonsterMouth.idle);
    }
    for (var slot = 0; slot < 4; slot++) {
      final name = h.game.tray[slot]!.name;
      expect(find.bySemanticsLabel('${name[0].toUpperCase()}${name.substring(1)}'), findsWidgets);
    }
    expect(h.voice.said, [MonsterPhrases.introLine.text]);
  });

  testWidgets('monsters sit in a 2×2 grid above the tray', (tester) async {
    final h = await _startGame(tester);

    expect(h.seatCenter(0).dy, h.seatCenter(1).dy);
    expect(h.seatCenter(2).dy, h.seatCenter(3).dy);
    expect(h.seatCenter(0).dx, h.seatCenter(2).dx);
    expect(h.seatCenter(0).dx, lessThan(h.seatCenter(1).dx));
    expect(h.seatCenter(0).dy, lessThan(h.seatCenter(2).dy));
    for (var slot = 0; slot < 4; slot++) {
      expect(h.slotCenter(slot).dy, greaterThan(h.seatCenter(2).dy));
    }
  });

  testWidgets('poking a monster with no treat in hand: it giggles and says its colour', (tester) async {
    final h = await _startGame(tester);
    h.voice.said.clear();

    await tester.tapAt(h.seatCenter(2));
    await tester.pump();

    expect(h.voice.said, ['Я ${h.game.monsters[2].masculine}!']);
    expect(h.voice.sfx, [MonsterSfx.boing]);
    expect(h.figureState(2).currentMove, MonsterMove.giggle);

    await h.run(const Duration(seconds: 1));
    expect(h.figureState(2).currentMove, isNull);
  });

  testWidgets('picking a treat up names it and makes every monster open its mouth and look', (tester) async {
    final h = await _startGame(tester);
    h.voice.said.clear();

    await tester.tapAt(h.slotCenter(1));
    await tester.pump();

    expect(h.voice.said, [MonsterPhrases.foodName(h.game.tray[1]!).text]);
    expect(h.voice.sfx, [MonsterSfx.boing]);
    for (var seat = 0; seat < 4; seat++) {
      expect(h.figure(seat).mouth, MonsterMouth.open);
      // The tray is below every monster, so they all look down.
      expect(h.figure(seat).lookDirection!.dy, greaterThan(0));
      expect(h.figure(seat).lookDirection!.distance, closeTo(1, 1e-9));
    }

    // Tapping the same treat again puts it back.
    await tester.tapAt(h.slotCenter(1));
    await tester.pump();
    for (var seat = 0; seat < 4; seat++) {
      expect(h.figure(seat).mouth, MonsterMouth.idle);
      expect(h.figure(seat).lookDirection, isNull);
    }
    expect(h.voice.said, hasLength(1));
  });

  testWidgets('the right colour: munch, «Ням!», two claps, the monster grows and the tray refills', (tester) async {
    final h = await _startGame(tester);
    const seat = 0;
    final slot = h.slotFor(seat);
    final food = h.game.tray[slot]!;
    h.voice.said.clear();
    h.voice.sfx.clear();

    await h.feed(slot, seat, letItPlay: Duration.zero);
    // The treat is in the air; only the monster it is flying to holds its
    // mouth open.
    expect(h.figure(seat).mouth, MonsterMouth.open);
    expect(h.figure(1).mouth, MonsterMouth.idle);
    expect(h.game.eatenBy(seat), 0);

    await h.run(const Duration(milliseconds: 500));
    expect(h.game.eatenBy(seat), 1);
    expect(h.figure(seat).mouth, MonsterMouth.chomp);
    expect(h.voice.said.last, 'Ням! ${MonsterPhrases.foodName(food).text}');
    expect(h.voice.sfx.last, MonsterSfx.chomp);

    await h.run(const Duration(milliseconds: 600));
    expect(h.figure(seat).mouth, MonsterMouth.idle);
    expect(h.figure(seat).growth, closeTo(1.06, 1e-9));
    expect(h.figureState(seat).isClapping, isTrue);
    expect(h.voice.sfx.last, MonsterSfx.clap);
    expect(h.game.tray[slot], isNull, reason: 'the new treat appears after the applause');

    await h.run(const Duration(seconds: 2));
    expect(h.game.tray[slot], isNotNull);
    expect(h.game.monsters[seat], food.color, reason: 'one treat is not enough to leave');
    expect(h.voice.said, [MonsterPhrases.foodName(food).text, 'Ням! ${MonsterPhrases.foodName(food).text}']);
  });

  testWidgets('the wrong colour: a grimace, «Фу! … — …му!», the treat comes back, nothing is lost', (tester) async {
    final h = await _startGame(tester);
    final slot = h.slotFor(1);
    final food = h.game.tray[slot]!;
    final trayBefore = h.game.tray;
    h.voice.sfx.clear();

    await h.feed(slot, 0, letItPlay: const Duration(milliseconds: 500));
    expect(h.figure(0).mouth, MonsterMouth.yuck);
    expect(h.figureState(0).currentMove, MonsterMove.shake);
    expect(h.voice.said.last, 'Фу! ${MonsterPhrases.foodName(food).text} — ${food.color.dative}!');
    expect(h.voice.sfx.last, MonsterSfx.yuck);

    await h.run(const Duration(seconds: 2));
    expect(h.figure(0).mouth, MonsterMouth.idle);
    expect(h.game.tray, trayBefore);
    expect(h.game.eatenBy(0), 0);
    expect(h.game.eatenBy(1), 0);
    expect(h.figure(0).growth, 1);

    // The game goes on: the same treat can be given to its real owner.
    await h.feed(slot, 1);
    expect(h.game.eatenBy(1), 1);
  });

  testWidgets('a treat can be dragged to a monster with a finger', (tester) async {
    final h = await _startGame(tester);
    const seat = 3;
    final slot = h.slotFor(seat);
    final food = h.game.tray[slot]!;
    h.voice.said.clear();

    final finger = await tester.startGesture(h.slotCenter(slot));
    await finger.moveBy(const Offset(0, -30));
    await tester.pump();
    // In the air: every monster opens up and watches it.
    for (var i = 0; i < 4; i++) {
      expect(h.figure(i).mouth, MonsterMouth.open);
      expect(h.figure(i).lookDirection, isNotNull);
    }
    await finger.moveTo(h.seatCenter(seat));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await h.run(const Duration(seconds: 3));

    expect(h.game.eatenBy(seat), 1);
    // Dragging doesn't name the treat first; eating it does.
    expect(h.voice.said, ['Ням! ${MonsterPhrases.foodName(food).text}']);
  });

  testWidgets('a treat dropped anywhere but on a monster just goes back', (tester) async {
    final h = await _startGame(tester);
    final trayBefore = h.game.tray;
    h.voice.said.clear();

    final finger = await tester.startGesture(h.slotCenter(0));
    await finger.moveBy(const Offset(40, -10));
    await tester.pump();
    await finger.moveTo(h.slotCenter(2));
    await tester.pump();
    await finger.up();
    await h.run(const Duration(seconds: 1));

    expect(h.game.tray, trayBefore);
    expect(h.voice.said, isEmpty);
    for (var seat = 0; seat < 4; seat++) {
      expect(h.figure(seat).mouth, MonsterMouth.idle);
      expect(h.figure(seat).lookDirection, isNull);
      expect(h.game.eatenBy(seat), 0);
    }
  });

  testWidgets('touches wait while a feeding is playing out', (tester) async {
    final h = await _startGame(tester);
    await h.feed(h.slotFor(0), 0, letItPlay: const Duration(milliseconds: 200));
    final saidSoFar = h.voice.said.length;

    await tester.tapAt(h.seatCenter(2));
    await tester.tapAt(h.slotCenter(h.slotFor(2)));
    await tester.pump();

    expect(h.voice.said, hasLength(saidSoFar));
    await h.run(const Duration(seconds: 3));
    expect(h.game.eatenBy(0), 1);
    expect(h.game.eatenBy(2), 0);
  });

  testWidgets('after two treats the monster says goodbye and the next colour hops in', (tester) async {
    final h = await _startGame(tester);
    const seat = 1;
    final departed = h.game.monsters[seat];
    await h.feed(h.slotFor(seat), seat);
    h.voice.said.clear();
    h.voice.sfx.clear();

    await h.feed(h.slotFor(seat), seat, letItPlay: const Duration(milliseconds: 1700));
    expect(h.figure(seat).growth, closeTo(1.12, 1e-9));

    await h.run(const Duration(milliseconds: 600));
    expect(h.voice.said.last, 'Спасибо! Пока-пока!');
    expect(h.figureState(seat).isWaving, isTrue);
    expect(h.figure(seat).color, departed);

    await h.run(const Duration(milliseconds: 1200));
    expect(h.figureState(seat).currentMove, MonsterMove.leave);
    expect(h.voice.sfx, contains(MonsterSfx.leave));

    await h.run(const Duration(seconds: 3));
    expect(h.game.monsters[seat], MonsterColor.orange);
    expect(h.figure(seat).color, MonsterColor.orange);
    expect(h.figure(seat).growth, 1);
    expect(h.game.eatenBy(seat), 0);
    expect(h.voice.said.last, 'Привет! Я новенький! Я оранжевый!');
    expect(h.voice.sfx, containsAllInOrder([MonsterSfx.leave, MonsterSfx.pop, MonsterSfx.clap]));
    expect(h.game.tray.map((food) => food!.color), isNot(contains(departed)));

    // The orange dot in the row of met colours is lit and glowing.
    final dot = tester.widget<AnimatedScale>(
      find.descendant(of: find.byKey(const ValueKey('monsters_met_orange')), matching: find.byType(AnimatedScale)),
    );
    expect(dot.scale, greaterThan(1));
  });

  testWidgets('the second newcomer greets with a plain hello, without «Я новенький!»', (tester) async {
    final h = await _startGame(tester);
    await h.feedUntilReplaced(0);
    expect(h.voice.said.last, 'Привет! Я новенький! Я оранжевый!');
    await h.feedUntilReplaced(1);
    expect(h.voice.said.last, 'Привет! Я фиолетовый!');
    await h.feedUntilReplaced(2);
    expect(h.voice.said.last, 'Привет! Я новенький! Я розовый!');
  });

  testWidgets('a full monster wiggles until «Ням!» has been said, then waves goodbye as the voice says it', (tester) async {
    final h = await _startGame(tester);
    const seat = 0;
    final departed = h.game.monsters[seat];
    await h.feed(h.slotFor(seat), seat);

    final finger = await tester.startGesture(h.slotCenter(h.slotFor(seat)));
    await finger.moveTo(h.seatCenter(seat));
    await tester.pump();
    h.voice.holdSpeech(); // the «Ням! …» that follows keeps sounding
    await finger.up();
    await tester.pump();

    // Fed and clapped, but «Ням! …» is still sounding: no goodbye yet — and
    // no standing frozen either.
    await h.run(const Duration(milliseconds: 2300));
    expect(h.voice.said.last, startsWith('Ням!'));
    expect(h.figureState(seat).currentMove, MonsterMove.giggle);
    expect(h.figureState(seat).isWaving, isFalse);

    await h.run(const Duration(milliseconds: 1200));
    expect(h.voice.said.last, startsWith('Ням!'));
    expect(h.figureState(seat).currentMove, MonsterMove.giggle);
    expect(h.figure(seat).color, departed);

    // The moment it has been said: the goodbye, voice and wave together.
    h.voice.finishSpeaking();
    await h.run(const Duration(milliseconds: 150));
    expect(h.voice.said.last, 'Спасибо! Пока-пока!');
    expect(h.figureState(seat).isWaving, isTrue);

    await h.run(const Duration(milliseconds: 1200));
    expect(h.figureState(seat).currentMove, MonsterMove.leave);

    await h.run(const Duration(seconds: 3));
    expect(h.figure(seat).color, MonsterColor.orange);
  });

  testWidgets('the newcomer waits for the goodbye to be said, and says hello as it lands', (tester) async {
    final h = await _startGame(tester);
    const seat = 0;
    final departed = h.game.monsters[seat];
    await h.feed(h.slotFor(seat), seat);
    await h.feed(h.slotFor(seat), seat, letItPlay: const Duration(milliseconds: 1850));
    h.voice.holdSpeech(); // «Спасибо! Пока-пока!» keeps sounding
    await h.run(const Duration(milliseconds: 2400));

    // The old monster has waved and walked off, but its goodbye is not over.
    expect(h.voice.said.last, 'Спасибо! Пока-пока!');
    expect(h.figureState(seat).currentMove, MonsterMove.leave);
    expect(h.game.monsters[seat], departed, reason: 'nobody new until the goodbye has been said');

    h.voice.finishSpeaking();
    await h.run(const Duration(milliseconds: 150));
    expect(h.game.monsters[seat], MonsterColor.orange);
    expect(h.figureState(seat).currentMove, MonsterMove.enter);
    expect(h.voice.said.last, 'Привет! Я новенький! Я оранжевый!');
  });

  testWidgets('fed while its name is still being said, a treat is not named twice', (tester) async {
    final h = await _startGame(tester);
    const seat = 0;
    final slot = h.slotFor(seat);
    final name = MonsterPhrases.foodName(h.game.tray[slot]!).text;
    h.voice.said.clear();

    h.voice.holdSpeech(); // «Красная клубника» keeps sounding
    await tester.tapAt(h.slotCenter(slot));
    await tester.pump();
    await tester.tapAt(h.seatCenter(seat));
    await tester.pump();
    await h.run(const Duration(milliseconds: 600));

    expect(h.voice.said, [name, 'Ням!']);
    h.voice.finishSpeaking();
    await h.run(const Duration(seconds: 3));
    expect(h.game.eatenBy(seat), 1);
  });

  testWidgets('a refusal always names the treat, even right after it was named', (tester) async {
    final h = await _startGame(tester);
    final slot = h.slotFor(1);
    final food = h.game.tray[slot]!;
    final name = MonsterPhrases.foodName(food).text;
    h.voice.said.clear();

    h.voice.holdSpeech();
    await tester.tapAt(h.slotCenter(slot));
    await tester.pump();
    await tester.tapAt(h.seatCenter(0));
    await tester.pump();
    await h.run(const Duration(milliseconds: 600));

    // «Фу! — зелёному!» alone would not say *what* is for the green one.
    expect(h.voice.said, [name, 'Фу! $name — ${food.color.dative}!']);
    h.voice.finishSpeaking();
    await h.run(const Duration(seconds: 2));
  });

  testWidgets('meeting the last colour starts the celebration, once', (tester) async {
    final h = await _startGame(tester);

    // Seven colours are still to come; each arrives when a monster is fed twice.
    for (var i = 0; i < 6; i++) {
      await h.feedUntilReplaced(i % 4);
    }
    expect(h.game.metColors, hasLength(10));
    expect(h.voice.said, isNot(contains('Ура! Ты знаешь все цвета!')));

    const seat = 2;
    await h.feed(h.slotFor(seat), seat);
    await h.feed(h.slotFor(seat), seat, letItPlay: const Duration(milliseconds: 6700));
    expect(h.game.metColors, hasLength(11));
    expect(h.voice.said.last, 'Ура! Ты знаешь все цвета!');
    expect(h.voice.sfx.last, MonsterSfx.win);
    for (var i = 0; i < 4; i++) {
      expect(h.figureState(i).isDancing, isTrue);
    }

    await h.run(const Duration(seconds: 4));
    for (var i = 0; i < 4; i++) {
      expect(h.figureState(i).isDancing, isFalse);
    }

    // The game goes on with familiar colours and no second celebration.
    await h.feedUntilReplaced(0);
    expect(h.voice.said.where((line) => line == 'Ура! Ты знаешь все цвета!'), hasLength(1));
    expect(h.voice.said.last, startsWith('Привет! Я '));
    expect(h.voice.said.last, isNot(contains('новенький')));
  });

  testWidgets('the restart button starts a fresh game', (tester) async {
    final h = await _startGame(tester);
    await h.feedUntilReplaced(0);
    final firstGame = h.game;
    expect(firstGame.metColors, hasLength(5));

    await tester.tap(find.byKey(const ValueKey('monsters_restart_button')));
    await h.run(const Duration(milliseconds: 600));

    expect(h.gamesStarted, 2);
    expect(h.game, isNot(same(firstGame)));
    expect(h.game.metColors, hasLength(4));
    for (var seat = 0; seat < 4; seat++) {
      expect(h.figure(seat).color, h.game.monsters[seat]);
      expect(h.figure(seat).growth, 1);
    }
    expect(h.voice.said.last, MonsterPhrases.introLine.text);
  });

  testWidgets('restarting in the middle of a feeding drops it cleanly', (tester) async {
    final h = await _startGame(tester);
    await h.feed(h.slotFor(0), 0, letItPlay: const Duration(milliseconds: 200));

    await tester.tap(find.byKey(const ValueKey('monsters_restart_button')));
    await h.run(const Duration(seconds: 5));

    expect(h.gamesStarted, 2);
    for (var seat = 0; seat < 4; seat++) {
      expect(h.game.eatenBy(seat), 0);
      expect(h.figure(seat).mouth, MonsterMouth.idle);
    }
    // And the new game is playable straight away.
    await h.feed(h.slotFor(1), 1);
    expect(h.game.eatenBy(1), 1);
  });

  testWidgets('the back button leaves the game and releases the sound', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = FakeMonsterVoice();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MonstersScreen(
                  voiceFactory: () => voice,
                  gameFactory: () => MonstersGame(random: Random(1)),
                ),
              ),
            ),
            child: const Text('открыть'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();
    expect(find.byType(MonstersScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monsters_back_button')));
    await tester.pumpAndSettle();

    expect(find.byType(MonstersScreen), findsNothing);
    expect(voice.disposeCalled, isTrue);
  });

  testWidgets('a swipe from the screen edge does not close the game', (tester) async {
    await _startGame(tester);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
  });

  testWidgets('closing the screen mid-feeding leaves nothing running', (tester) async {
    final h = await _startGame(tester);
    await h.feed(h.slotFor(0), 0, letItPlay: const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox());

    expect(h.voice.disposeCalled, isTrue);
    // The test framework fails this test if a timer is still pending.
  });
}
