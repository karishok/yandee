import 'dart:math';

import 'monster_color.dart';
import 'monster_food.dart';

/// What happened when a treat was offered to a monster.
class FeedResult {
  const FeedResult({
    required this.food,
    required this.monster,
    required this.accepted,
    required this.monsterIsFull,
  });

  final MonsterFood food;
  final MonsterColor monster;

  /// The treat's colour matched: the monster ate it. Otherwise the treat is
  /// back in the tray and nothing changed.
  final bool accepted;

  /// The monster has now eaten all it wanted and is ready to leave — see
  /// [MonstersGame.replaceMonster].
  final bool monsterIsFull;
}

/// What happened when a fed monster left and another took its place.
class NewcomerResult {
  const NewcomerResult({
    required this.departed,
    required this.newcomer,
    required this.firstMeeting,
    required this.metEveryColor,
    required this.replacedTraySlots,
  });

  final MonsterColor departed;
  final MonsterColor newcomer;

  /// The child has never seen a monster of this colour before.
  final bool firstMeeting;

  /// This newcomer was the last colour left to meet — time to celebrate.
  /// True exactly once per game.
  final bool metEveryColor;

  /// Tray slots whose treat was only for the monster that left; each now
  /// holds a treat for the newcomer.
  final List<int> replacedTraySlots;
}

/// The rules of the "Монстрики" colour game, with no drawing, sound or
/// timing in them: who is on screen, how much each has eaten, which colour
/// comes next and what lies in the tray.
///
/// Four monsters sit in four seats; four treats lie in the tray. A monster
/// eats only treats of its own colour. After [hunger] treats it leaves and
/// the next colour in [MonsterColor.values] takes its seat; once every
/// colour has been met, newcomers come in random order.
///
/// The screen drives it in three steps so it can animate between them:
/// [feed], then [refill] for the emptied tray slot, then [replaceMonster]
/// if the monster is full.
class MonstersGame {
  MonstersGame({Random? random}) : _random = random ?? Random() {
    final starters = MonsterColor.values.take(MonsterColor.startingCount).toList()..shuffle(_random);
    _seats = [for (final color in starters) _Seat(color)];
    _met.addAll(starters);
    for (var slot = 0; slot < traySize; slot++) {
      _tray[slot] = _pickFood();
    }
  }

  /// How many monsters are on screen.
  static const seatCount = MonsterColor.startingCount;

  /// How many treats lie in the tray.
  static const traySize = 4;

  /// How many treats a monster eats before it leaves.
  static const hunger = 2;

  final Random _random;
  late final List<_Seat> _seats;
  final List<MonsterFood?> _tray = List.filled(traySize, null);
  final Set<MonsterColor> _met = {};

  // Index in MonsterColor.values of the next colour to introduce.
  int _nextNewColor = MonsterColor.startingCount;

  /// The colour of the monster in each seat.
  List<MonsterColor> get monsters => [for (final seat in _seats) seat.color];

  /// How many treats the monster in [seat] has eaten.
  int eatenBy(int seat) => _seats[seat].eaten;

  /// The treat in each tray slot; null while a slot waits for [refill].
  List<MonsterFood?> get tray => List.unmodifiable(_tray);

  /// Colours the child has already met, including the ones on screen.
  Set<MonsterColor> get metColors => Set.unmodifiable(_met);

  /// Offers the treat in [traySlot] to the monster in [seat].
  ///
  /// A matching colour is eaten: the slot becomes empty and the monster is
  /// one treat closer to full. A wrong colour changes nothing — there is no
  /// penalty, the treat simply stays in the tray.
  FeedResult feed({required int traySlot, required int seat}) {
    final food = _tray[traySlot];
    if (food == null) {
      throw StateError('Tray slot $traySlot is empty');
    }
    final monster = _seats[seat];
    if (food.color != monster.color) {
      return FeedResult(food: food, monster: monster.color, accepted: false, monsterIsFull: false);
    }
    _tray[traySlot] = null;
    monster.eaten++;
    return FeedResult(
      food: food,
      monster: monster.color,
      accepted: true,
      monsterIsFull: monster.eaten >= hunger,
    );
  }

  /// Puts a new treat into the empty [traySlot] and returns it.
  MonsterFood refill(int traySlot) {
    if (_tray[traySlot] != null) {
      throw StateError('Tray slot $traySlot is not empty');
    }
    return _tray[traySlot] = _pickFood();
  }

  /// The full monster in [seat] leaves and a newcomer takes the seat.
  ///
  /// Treats in the tray that only the departed monster could eat are
  /// swapped for treats for the newcomer, so the tray never holds food
  /// nobody on screen wants.
  NewcomerResult replaceMonster(int seat) {
    final leaving = _seats[seat];
    if (leaving.eaten < hunger) {
      throw StateError('The monster in seat $seat is still hungry');
    }
    final departed = leaving.color;
    final newcomer = _nextColor();
    final firstMeeting = _met.add(newcomer);
    _seats[seat] = _Seat(newcomer);

    final replaced = <int>[];
    for (var slot = 0; slot < traySize; slot++) {
      if (_tray[slot]?.color == departed) {
        _tray[slot] = _randomFoodFor(newcomer);
        replaced.add(slot);
      }
    }

    return NewcomerResult(
      departed: departed,
      newcomer: newcomer,
      firstMeeting: firstMeeting,
      metEveryColor: firstMeeting && _met.length == MonsterColor.values.length,
      replacedTraySlots: replaced,
    );
  }

  // New colours come in teaching order; after the last one, any colour that
  // isn't on screen right now (which also rules out the one just leaving).
  MonsterColor _nextColor() {
    if (_nextNewColor < MonsterColor.values.length) {
      return MonsterColor.values[_nextNewColor++];
    }
    final onScreen = monsters.toSet();
    final free = MonsterColor.values.where((color) => !onScreen.contains(color)).toList();
    return free[_random.nextInt(free.length)];
  }

  // A treat for the on-screen colour that has the fewest treats waiting in
  // the tray, so no monster is left with nothing to eat for long. Ties are
  // broken at random.
  MonsterFood _pickFood() {
    int waiting(MonsterColor color) => _tray.where((food) => food?.color == color).length;
    final colors = monsters..shuffle(_random);
    var hungriest = colors.first;
    for (final color in colors.skip(1)) {
      if (waiting(color) < waiting(hungriest)) hungriest = color;
    }
    return _randomFoodFor(hungriest);
  }

  MonsterFood _randomFoodFor(MonsterColor color) {
    final menu = menuFor(color);
    return menu[_random.nextInt(menu.length)];
  }
}

class _Seat {
  _Seat(this.color);
  final MonsterColor color;
  int eaten = 0;
}
