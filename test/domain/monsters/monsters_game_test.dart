import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:yandee/domain/monsters/monster_color.dart';
import 'package:yandee/domain/monsters/monster_food.dart';
import 'package:yandee/domain/monsters/monsters_game.dart';

/// The tray slot holding a treat for [color]; fails the test if there is none.
int _slotFor(MonstersGame game, MonsterColor color) {
  final slot = game.tray.indexWhere((food) => food?.color == color);
  expect(slot, isNot(-1), reason: 'no treat for $color in ${game.tray}');
  return slot;
}

/// Feeds the monster in [seat] one matching treat and refills the tray.
FeedResult _feedOnce(MonstersGame game, int seat) {
  final slot = _slotFor(game, game.monsters[seat]);
  final result = game.feed(traySlot: slot, seat: seat);
  game.refill(slot);
  return result;
}

/// Feeds the monster in [seat] until it is full, then swaps it out.
NewcomerResult _feedUntilReplaced(MonstersGame game, int seat) {
  for (var i = 0; i < MonstersGame.hunger; i++) {
    _feedOnce(game, seat);
  }
  return game.replaceMonster(seat);
}

void main() {
  const starters = {MonsterColor.red, MonsterColor.blue, MonsterColor.yellow, MonsterColor.green};

  group('a new game', () {
    test('seats the four basic colours, in a shuffled order', () {
      final orders = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final game = MonstersGame(random: Random(seed));
        expect(game.monsters, hasLength(4));
        expect(game.monsters.toSet(), starters);
        orders.add(game.monsters.join());
      }
      expect(orders.length, greaterThan(1));
    });

    test('has met exactly the four colours on screen', () {
      expect(MonstersGame(random: Random(1)).metColors, starters);
    });

    test('nobody has eaten anything', () {
      final game = MonstersGame(random: Random(1));
      for (var seat = 0; seat < MonstersGame.seatCount; seat++) {
        expect(game.eatenBy(seat), 0);
      }
    });

    test('fills the tray with one treat for each monster', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = MonstersGame(random: Random(seed));
        expect(game.tray, hasLength(4));
        expect(game.tray.map((food) => food!.color).toSet(), starters);
      }
    });
  });

  group('feeding', () {
    test('a matching treat is eaten: the slot empties and the monster is fuller', () {
      final game = MonstersGame(random: Random(2));
      final slot = _slotFor(game, game.monsters[0]);
      final food = game.tray[slot]!;

      final result = game.feed(traySlot: slot, seat: 0);

      expect(result.accepted, isTrue);
      expect(result.food, food);
      expect(result.monster, game.monsters[0]);
      expect(result.monsterIsFull, isFalse);
      expect(game.tray[slot], isNull);
      expect(game.eatenBy(0), 1);
    });

    test('a wrong-colour treat changes nothing — no penalty', () {
      final game = MonstersGame(random: Random(2));
      final slot = _slotFor(game, game.monsters[1]);
      final trayBefore = game.tray;

      final result = game.feed(traySlot: slot, seat: 0);

      expect(result.accepted, isFalse);
      expect(result.monsterIsFull, isFalse);
      expect(result.food, trayBefore[slot]);
      expect(result.monster, game.monsters[0]);
      expect(game.tray, trayBefore);
      expect(game.eatenBy(0), 0);
      expect(game.eatenBy(1), 0);
    });

    test('the second treat makes the monster full', () {
      final game = MonstersGame(random: Random(3));
      expect(_feedOnce(game, 0).monsterIsFull, isFalse);
      expect(_feedOnce(game, 0).monsterIsFull, isTrue);
      expect(game.eatenBy(0), MonstersGame.hunger);
    });

    test('feeding from an empty slot is a programming error', () {
      final game = MonstersGame(random: Random(2));
      final slot = _slotFor(game, game.monsters[0]);
      game.feed(traySlot: slot, seat: 0);
      expect(() => game.feed(traySlot: slot, seat: 0), throwsStateError);
    });
  });

  group('refilling the tray', () {
    test('puts a treat for an on-screen monster into the empty slot', () {
      final game = MonstersGame(random: Random(4));
      final slot = _slotFor(game, game.monsters[0]);
      game.feed(traySlot: slot, seat: 0);

      final food = game.refill(slot);

      expect(game.tray[slot], food);
      expect(game.monsters, contains(food.color));
    });

    test('picks the colour with the fewest treats waiting', () {
      // The tray starts with one treat per colour; eating one leaves that
      // colour as the only one with nothing waiting.
      for (var seed = 0; seed < 30; seed++) {
        final game = MonstersGame(random: Random(seed));
        final color = game.monsters[2];
        final slot = _slotFor(game, color);
        game.feed(traySlot: slot, seat: 2);
        expect(game.refill(slot).color, color, reason: 'seed $seed');
      }
    });

    test('every monster always has something to eat, however long the game', () {
      final random = Random(5);
      final game = MonstersGame(random: random);
      for (var turn = 0; turn < 300; turn++) {
        final seat = random.nextInt(MonstersGame.seatCount);
        final result = _feedOnce(game, seat);
        if (result.monsterIsFull) game.replaceMonster(seat);
        expect(game.tray.map((food) => food!.color).toSet(), game.monsters.toSet(), reason: 'turn $turn');
      }
    });

    test('the treat that comes next is never the one just eaten', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        final game = MonstersGame(random: random);
        for (var turn = 0; turn < 60; turn++) {
          final seat = random.nextInt(MonstersGame.seatCount);
          final slot = _slotFor(game, game.monsters[seat]);
          final eaten = game.tray[slot]!;
          final result = game.feed(traySlot: slot, seat: seat);
          final next = game.refill(slot);
          expect(next, isNot(eaten), reason: 'seed $seed, turn $turn');
          if (result.monsterIsFull) game.replaceMonster(seat);
        }
      }
    });

    test('the tray never holds two identical treats', () {
      for (var seed = 0; seed < 40; seed++) {
        final random = Random(seed);
        final game = MonstersGame(random: random);
        for (var turn = 0; turn < 60; turn++) {
          final tray = game.tray.whereType<MonsterFood>().toList();
          expect(tray.toSet(), hasLength(tray.length), reason: 'seed $seed, turn $turn: $tray');
          final result = _feedOnce(game, random.nextInt(MonstersGame.seatCount));
          if (result.monsterIsFull) game.replaceMonster(game.monsters.indexOf(result.monster));
        }
      }
    });

    test('refilling a slot that still holds a treat is a programming error', () {
      expect(() => MonstersGame(random: Random(1)).refill(0), throwsStateError);
    });
  });

  group('a full monster leaves', () {
    test('a hungry monster cannot be replaced', () {
      final game = MonstersGame(random: Random(1));
      expect(() => game.replaceMonster(0), throwsStateError);
      _feedOnce(game, 0);
      expect(() => game.replaceMonster(0), throwsStateError);
    });

    test('the first newcomer is orange, hungry, and new to the child', () {
      final game = MonstersGame(random: Random(6));
      final departed = game.monsters[1];

      final result = _feedUntilReplaced(game, 1);

      expect(result.departed, departed);
      expect(result.newcomer, MonsterColor.orange);
      expect(result.firstMeeting, isTrue);
      expect(result.metEveryColor, isFalse);
      expect(game.monsters[1], MonsterColor.orange);
      expect(game.eatenBy(1), 0);
      expect(game.metColors, {...starters, MonsterColor.orange});
    });

    test('new colours arrive in teaching order, whichever seat frees up', () {
      final game = MonstersGame(random: Random(7));
      final arrivals = [
        for (final seat in [0, 3, 3, 1, 2, 0, 1]) _feedUntilReplaced(game, seat).newcomer,
      ];
      expect(arrivals, [
        MonsterColor.orange,
        MonsterColor.purple,
        MonsterColor.pink,
        MonsterColor.brown,
        MonsterColor.lightblue,
        MonsterColor.white,
        MonsterColor.black,
      ]);
    });

    test('treats only the departed monster could eat become treats for the newcomer', () {
      for (var seed = 0; seed < 30; seed++) {
        final game = MonstersGame(random: Random(seed));
        final departed = game.monsters[0];
        for (var i = 0; i < MonstersGame.hunger; i++) {
          _feedOnce(game, 0);
        }
        final leftovers = [
          for (var slot = 0; slot < MonstersGame.traySize; slot++)
            if (game.tray[slot]!.color == departed) slot,
        ];
        expect(leftovers, isNotEmpty, reason: 'the refill after the last bite is for the eater');
        final others = {
          for (var slot = 0; slot < MonstersGame.traySize; slot++)
            if (!leftovers.contains(slot)) slot: game.tray[slot],
        };

        final result = game.replaceMonster(0);

        expect(result.replacedTraySlots, leftovers, reason: 'seed $seed');
        for (final slot in leftovers) {
          expect(game.tray[slot]!.color, result.newcomer);
        }
        others.forEach((slot, food) => expect(game.tray[slot], food));
      }
    });

    test('only every other new colour says it is new; old friends never do', () {
      final game = MonstersGame(random: Random(11));
      final greetings = <String>[];
      for (var i = 0; i < 20; i++) {
        final result = _feedUntilReplaced(game, i % MonstersGame.seatCount);
        greetings.add('${result.newcomer.name}:${result.firstMeeting ? 'first' : 'again'}:${result.saysItIsNew ? 'new' : 'hi'}');
      }
      expect(greetings.take(7), [
        'orange:first:new',
        'purple:first:hi',
        'pink:first:new',
        'brown:first:hi',
        'lightblue:first:new',
        'white:first:hi',
        'black:first:new',
      ]);
      for (final greeting in greetings.skip(7)) {
        expect(greeting, endsWith(':again:hi'));
      }
    });

    test('the celebration fires once, when the last colour arrives', () {
      final game = MonstersGame(random: Random(8));
      final celebrations = <MonsterColor>[];
      for (var i = 0; i < 40; i++) {
        final result = _feedUntilReplaced(game, i % MonstersGame.seatCount);
        if (result.metEveryColor) celebrations.add(result.newcomer);
      }
      expect(celebrations, [MonsterColor.black]);
      expect(game.metColors, MonsterColor.values.toSet());
    });

    test('after every colour is met, newcomers are old friends in a mixed order', () {
      final game = MonstersGame(random: Random(9));
      for (var i = 0; i < 7; i++) {
        _feedUntilReplaced(game, i % MonstersGame.seatCount);
      }

      final later = <MonsterColor>[];
      for (var i = 0; i < 60; i++) {
        final seat = i % MonstersGame.seatCount;
        final before = game.monsters;
        final result = _feedUntilReplaced(game, seat);
        expect(result.firstMeeting, isFalse);
        expect(result.metEveryColor, isFalse);
        expect(before, isNot(contains(result.newcomer)), reason: 'never a colour that was just on screen');
        expect(game.monsters.toSet(), hasLength(4), reason: 'no two monsters of one colour');
        later.add(result.newcomer);
      }
      expect(later.toSet().length, greaterThan(4), reason: 'colours keep rotating');
    });
  });

  group('the menu', () {
    test('every colour has at least three treats, each of its own colour', () {
      for (final color in MonsterColor.values) {
        final foods = foodsFor(color);
        expect(foods.length, greaterThanOrEqualTo(3), reason: '$color');
        expect(foods.map((food) => food.color).toSet(), {color});
        expect(foods.toSet(), hasLength(foods.length), reason: 'no treat listed twice for $color');
      }
    });

    test('most treats are real food: sweets only fill in where a colour has little of its own', () {
      const sweets = {FoodKind.candy, FoodKind.lollipop, FoodKind.iceCream, FoodKind.cottonCandy};
      for (final color in MonsterColor.values) {
        if (color == MonsterColor.pink) continue;
        final sweetCount = foodsFor(color).where((food) => sweets.contains(food.kind)).length;
        expect(sweetCount, lessThanOrEqualTo(1), reason: '$color');
      }
    });

    test('every kind of food is used by some colour', () {
      final used = allFoods.map((food) => food.kind).toSet();
      expect(used, FoodKind.values.toSet());
    });

    test('there are 42 different treats in all', () {
      expect(allFoods, hasLength(42));
      expect(allFoods.toSet(), hasLength(42));
    });

    test('the colour word agrees with the food\'s gender', () {
      expect(const MonsterFood(FoodKind.strawberry, MonsterColor.red).name, 'красная клубника');
      expect(const MonsterFood(FoodKind.tomato, MonsterColor.red).name, 'красный помидор');
      expect(const MonsterFood(FoodKind.iceCream, MonsterColor.red).name, 'красное мороженое');
      expect(const MonsterFood(FoodKind.blueberry, MonsterColor.blue).name, 'синяя черника');
      expect(const MonsterFood(FoodKind.lollipop, MonsterColor.purple).name, 'фиолетовый леденец');
      expect(const MonsterFood(FoodKind.milk, MonsterColor.white).name, 'белое молоко');
      expect(const MonsterFood(FoodKind.cottonCandy, MonsterColor.pink).name, 'розовая сахарная вата');
      expect(const MonsterFood(FoodKind.broccoli, MonsterColor.green).name, 'зелёная брокколи');
      expect(const MonsterFood(FoodKind.bread, MonsterColor.black).name, 'чёрный хлеб');
      expect(const MonsterFood(FoodKind.bogBlueberry, MonsterColor.lightblue).name, 'голубая голубика');
      expect(const MonsterFood(FoodKind.fish, MonsterColor.lightblue).name, 'голубая рыбка');
      expect(const MonsterFood(FoodKind.iceCube, MonsterColor.lightblue).name, 'голубая льдинка');
      expect(const MonsterFood(FoodKind.water, MonsterColor.lightblue).name, 'голубая вода');
      expect(const MonsterFood(FoodKind.apple, MonsterColor.red).name, 'красное яблоко');
    });
  });
}
