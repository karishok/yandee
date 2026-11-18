import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../audio/monster_voice.dart';
import '../../audio/monster_voice_player.dart';
import '../../domain/monsters/monster_color.dart';
import '../../domain/monsters/monster_food.dart';
import '../../domain/monsters/monster_phrases.dart';
import '../../domain/monsters/monsters_game.dart';
import '../monsters/monster_art.dart';
import '../monsters/monster_figure.dart';

const _sky = Color(0xFFD9EFFF);
const _skyDeep = Color(0xFFB5DCFB);
const _ink = Color(0xFF23324A);
const _paper = Colors.white;

/// The "Монстрики" colour game: four monsters, a tray of four treats, and
/// each monster eats only treats of its own colour.
///
/// The rules live in [MonstersGame]; this screen is the puppet show around
/// them — it turns the child's drags and taps into [MonstersGame] calls and
/// plays out each result as flying food, mouths, claps and speech, the way
/// the HTML prototype (`docs/prototypes/monsters.html`) does.
class MonstersScreen extends StatefulWidget {
  const MonstersScreen({super.key, this.voiceFactory, this.gameFactory});

  /// Makes the sound output; tests pass a fake. Defaults to the real
  /// [MonsterVoicePlayer].
  final MonsterVoice Function()? voiceFactory;

  /// Makes a fresh game — at the start and on every restart. Tests pass a
  /// seeded one.
  final MonstersGame Function()? gameFactory;

  @override
  State<MonstersScreen> createState() => _MonstersScreenState();
}

/// The treat that is off the tray right now: under a finger, or flying.
class _Floating {
  const _Floating(this.food, this.center, {this.scale = 1, this.turns = 0});
  final MonsterFood food;
  final Offset center;
  final double scale;
  final double turns;
}

/// A finger that went down on a treat or a monster and hasn't lifted yet.
class _Touch {
  _Touch({required this.pointer, required this.start, this.slot, this.seat});
  final int pointer;
  final Offset start;

  /// The tray slot it went down on, if any.
  final int? slot;

  /// The monster it went down on, if any.
  final int? seat;

  /// It has moved far enough to be a drag rather than a tap.
  bool dragging = false;
}

/// Where everything sits for a given screen size. All of it is plain
/// arithmetic, so hit-testing a finger and aiming a flying treat need no
/// lookups in the widget tree.
class _Layout {
  _Layout(this.size) {
    const sidePadding = 16.0, edgePadding = 12.0, gap = 12.0, barHeight = 56.0;
    final width = math.max(0.0, size.width - sidePadding * 2);
    final trayHeight = (size.height * .16).clamp(84.0, 120.0);
    bar = Rect.fromLTWH(sidePadding, edgePadding, width, barHeight);
    tray = Rect.fromLTWH(sidePadding, size.height - edgePadding - trayHeight, width, trayHeight);
    final gridTop = bar.bottom + gap;
    grid = Rect.fromLTWH(sidePadding, gridTop, width, math.max(0.0, tray.top - gap - gridTop));
  }

  final Size size;
  late final Rect bar;
  late final Rect grid;
  late final Rect tray;

  /// The quarter of the grid that belongs to the monster in [seat]; a treat
  /// dropped anywhere in it is offered to that monster.
  Rect cell(int seat) => Rect.fromLTWH(
        grid.left + (seat % 2) * grid.width / 2,
        grid.top + (seat ~/ 2) * grid.height / 2,
        grid.width / 2,
        grid.height / 2,
      );

  /// The square the monster in [seat] is drawn into.
  Rect figure(int seat) {
    final inner = cell(seat).deflate(4);
    final side = math.max(0.0, inner.shortestSide);
    return Rect.fromCenter(center: inner.center, width: side, height: side);
  }

  Offset mouth(int seat) {
    final rect = figure(seat);
    return rect.topLeft + Offset(rect.width * monsterMouthAt.x, rect.height * monsterMouthAt.y);
  }

  /// The column of the tray a finger has to land in to pick up [slot].
  Rect slotColumn(int slot) {
    final inner = tray.deflate(8);
    final width = inner.width / MonstersGame.traySize;
    return Rect.fromLTWH(inner.left + slot * width, tray.top, width, tray.height);
  }

  /// The square the treat in [slot] is drawn into.
  Rect slot(int slot) {
    final side = math.max(0.0, math.min(math.min(tray.width * .22, 92.0), tray.height - 12));
    return Rect.fromCenter(center: slotColumn(slot).center, width: side, height: side);
  }

  int? seatAt(Offset point) {
    for (var seat = 0; seat < MonstersGame.seatCount; seat++) {
      if (cell(seat).contains(point)) return seat;
    }
    return null;
  }

  int? slotAt(Offset point) {
    for (var slot = 0; slot < MonstersGame.traySize; slot++) {
      if (slotColumn(slot).contains(point)) return slot;
    }
    return null;
  }
}

class _MonstersScreenState extends State<MonstersScreen> with SingleTickerProviderStateMixin {
  // A finger must travel this far before a touch on a treat is a drag.
  static const _dragSlop = 10.0;
  // A touch on a monster that travels further than this is not a tap.
  static const _tapSlop = 24.0;
  static const _floatingSide = 80.0;

  late final MonsterVoice _voice = widget.voiceFactory?.call() ?? MonsterVoicePlayer();
  late final AnimationController _flight = AnimationController(vsync: this);
  final ValueNotifier<_Floating?> _floating = ValueNotifier(null);
  final Set<Timer> _timers = {};

  late MonstersGame _game;
  late List<GlobalKey<MonsterFigureState>> _figures;
  _Layout _layout = _Layout(Size.zero);

  // Bumped on every restart: a sequence that was mid-animation notices on
  // its next step that the game it belongs to is gone, and stops.
  int _session = 0;

  // A feeding is playing out; touches wait until it has finished.
  bool _busy = false;
  _Touch? _touch;
  int? _selectedSlot;
  final Set<int> _hiddenSlots = {};
  final List<int> _slotVersions = List.filled(MonstersGame.traySize, 0);

  bool _allMouthsOpen = false;
  final Map<int, MonsterMouth> _mouths = {};
  final List<double> _growth = List.filled(MonstersGame.seatCount, 1);
  Offset? _lookAt;

  // The treat whose name is being said because it was just picked up, with
  // the future that ends when the name has been said.
  ({MonsterFood food, Future<void> speech})? _naming;

  // The colour that has just been met for the first time — its dot glows.
  MonsterColor? _justMet;
  int _confettiRun = 0;
  _Floating Function(double t)? _flightPath;

  @override
  void initState() {
    super.initState();
    _flight.addListener(() {
      final path = _flightPath;
      if (path != null) _floating.value = path(_flight.value);
    });
    _startGame();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _flight.dispose();
    _floating.dispose();
    _voice.dispose();
    super.dispose();
  }

  void _startGame() {
    _session++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _flight.stop();
    _flightPath = null;
    _floating.value = null;
    _voice.stop();

    _game = widget.gameFactory?.call() ?? MonstersGame();
    _figures = [for (var i = 0; i < MonstersGame.seatCount; i++) GlobalKey<MonsterFigureState>()];
    _busy = false;
    _touch = null;
    _selectedSlot = null;
    _hiddenSlots.clear();
    _allMouthsOpen = false;
    _mouths.clear();
    _growth.fillRange(0, _growth.length, 1);
    _lookAt = null;
    _justMet = null;
    _naming = null;
    for (var slot = 0; slot < _slotVersions.length; slot++) {
      _slotVersions[slot]++;
    }

    final session = _session;
    _pause(400).then((_) {
      if (!_stale(session)) unawaited(_voice.say(MonsterPhrases.introLine));
    });
  }

  bool _stale(int session) => !mounted || session != _session;

  /// Waits [milliseconds]. Unlike `Future.delayed`, the wait is dropped —
  /// never completes — if the screen closes or the game restarts first.
  Future<void> _pause(int milliseconds) {
    final done = Completer<void>();
    late final Timer timer;
    timer = Timer(Duration(milliseconds: milliseconds), () {
      _timers.remove(timer);
      done.complete();
    });
    _timers.add(timer);
    return done.future;
  }

  /// Waits for [speech] to be said to its end, but no longer than
  /// [milliseconds] — the game must never hang on a sound.
  Future<void> _heardOut(Future<void> speech, {int milliseconds = 4000}) =>
      Future.any([speech.catchError((Object _) {}), _pause(milliseconds)]);

  MonsterFigureState? _figure(int seat) => _figures[seat].currentState;

  // ------------------------------------------------------------- touches

  void _onPointerDown(PointerDownEvent event) {
    if (_touch != null || _busy) return;
    final point = event.localPosition;
    final slot = _layout.slotAt(point);
    if (slot != null) {
      if (_game.tray[slot] == null || _hiddenSlots.contains(slot)) return;
      _touch = _Touch(pointer: event.pointer, start: point, slot: slot);
      return;
    }
    final seat = _layout.seatAt(point);
    if (seat != null) {
      _touch = _Touch(pointer: event.pointer, start: point, seat: seat);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = _touch;
    if (touch == null || touch.pointer != event.pointer) return;
    final slot = touch.slot;
    if (slot == null || _busy) return;
    final point = event.localPosition;
    if (!touch.dragging && (point - touch.start).distance > _dragSlop) {
      touch.dragging = true;
      setState(() {
        _hiddenSlots.add(slot);
        _selectedSlot = null;
        _allMouthsOpen = true;
      });
    }
    if (touch.dragging) {
      _floating.value = _Floating(_game.tray[slot]!, point, scale: 1.15);
      setState(() => _lookAt = point);
    }
  }

  void _onPointerUp(PointerUpEvent event) => _endTouch(event.pointer, event.localPosition, cancelled: false);

  void _onPointerCancel(PointerCancelEvent event) =>
      _endTouch(event.pointer, event.localPosition, cancelled: true);

  void _endTouch(int pointer, Offset point, {required bool cancelled}) {
    final touch = _touch;
    if (touch == null || touch.pointer != pointer) return;
    _touch = null;
    if (_busy) return;

    final slot = touch.slot;
    if (slot != null) {
      if (!touch.dragging) {
        if (!cancelled) _select(_selectedSlot == slot ? null : slot);
        return;
      }
      // The treat was dragged: dropped on a monster it is offered to it,
      // dropped anywhere else it simply goes back.
      _floating.value = null;
      final seat = cancelled ? null : _layout.seatAt(point);
      setState(() {
        _hiddenSlots.remove(slot);
        _allMouthsOpen = false;
        if (seat == null) _lookAt = null;
      });
      if (seat != null) unawaited(_feed(slot, seat, from: point));
      return;
    }

    final seat = touch.seat;
    if (seat == null || cancelled) return;
    if (_layout.seatAt(point) != seat || (point - touch.start).distance > _tapSlop) return;
    final selected = _selectedSlot;
    if (selected != null) {
      unawaited(_feed(selected, seat));
    } else {
      // Poked with no treat in hand: it giggles and says its colour.
      _figure(seat)?.play(MonsterMove.giggle);
      _voice.playSfx(MonsterSfx.boing);
      unawaited(_voice.say(MonsterPhrases.introduce(_game.monsters[seat])));
    }
  }

  /// Picks up the treat in [slot] (or puts it back with null): every
  /// monster opens its mouth and looks at it, and the voice names it.
  void _select(int? slot) {
    setState(() {
      _selectedSlot = slot;
      _allMouthsOpen = slot != null;
      _lookAt = slot == null ? null : _layout.slot(slot).topCenter;
    });
    if (slot == null) return;
    _voice.playSfx(MonsterSfx.boing);
    final food = _game.tray[slot]!;
    final naming = _voice.say(MonsterPhrases.foodName(food));
    _naming = (food: food, speech: naming);
    naming.whenComplete(() {
      if (identical(_naming?.speech, naming)) _naming = null;
    });
  }

  /// The voice is still busy naming [food] from when it was picked up. What
  /// the monster says next can then skip the name: «Красная клубника» …
  /// «Ням!» says it all, where «Красная клубника» … «Ням! Красная клубника»
  /// says it twice and keeps everyone waiting.
  bool _stillNaming(MonsterFood food) => _naming?.food == food;

  // ----------------------------------------------------------- sequences

  /// Flies the off-tray treat along three points — start, the top of an
  /// arc, the end — easing in and out over the whole flight.
  Future<void> _fly(MonsterFood food, List<_Floating> points, int milliseconds) async {
    _flightPath = (t) {
      final eased = Curves.easeInOut.transform(t);
      final from = eased < .5 ? points[0] : points[1];
      final to = eased < .5 ? points[1] : points[2];
      final local = eased < .5 ? eased * 2 : (eased - .5) * 2;
      return _Floating(
        food,
        Offset.lerp(from.center, to.center, local)!,
        scale: from.scale + (to.scale - from.scale) * local,
        turns: from.turns + (to.turns - from.turns) * local,
      );
    };
    _flight.duration = Duration(milliseconds: milliseconds);
    try {
      await _flight.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The game restarted or the screen closed mid-flight.
    }
  }

  /// Offers the treat in [slot] to the monster in [seat] and plays out what
  /// happens. [from] is where the treat was let go; without it the treat
  /// flies from its place in the tray.
  Future<void> _feed(int slot, int seat, {Offset? from}) async {
    final food = _game.tray[slot];
    if (_busy || food == null) return;
    _busy = true;
    final session = _session;
    final figure = _figure(seat);
    final start = from ?? _layout.slot(slot).center;
    final mouth = _layout.mouth(seat);

    setState(() {
      _selectedSlot = null;
      _hiddenSlots.add(slot);
      _allMouthsOpen = false;
      _mouths[seat] = MonsterMouth.open;
    });
    await _fly(
      food,
      [
        _Floating(food, start),
        _Floating(food, Offset((start.dx + mouth.dx) / 2, math.min(start.dy, mouth.dy) - 60), scale: 1.1),
        _Floating(food, mouth, scale: .5),
      ],
      420,
    );
    if (_stale(session)) return;

    final result = _game.feed(traySlot: slot, seat: seat);
    setState(() {
      _mouths.remove(seat);
      _lookAt = null;
    });

    if (result.accepted) {
      _floating.value = null;
      setState(() => _mouths[seat] = MonsterMouth.chomp);
      figure?.play(MonsterMove.chomp);
      _voice.playSfx(MonsterSfx.chomp);
      final yum = _voice.say(_stillNaming(food) ? MonsterPhrases.ateJustNamed : MonsterPhrases.ate(food));
      await _pause(500);
      if (_stale(session)) return;

      // Fed and happy: a little bigger, and two claps.
      setState(() {
        _mouths.remove(seat);
        _growth[seat] = 1 + _game.eatenBy(seat) * .06;
      });
      figure?.clap();
      _voice.playSfx(MonsterSfx.clap);
      await _pause(1000);
      if (_stale(session)) return;

      _game.refill(slot);
      setState(() {
        _hiddenSlots.remove(slot);
        _slotVersions[slot]++;
      });

      if (result.monsterIsFull) {
        await _swap(seat, session, after: yum);
        if (_stale(session)) return;
      }
    } else {
      // Wrong colour: a grimace, and the treat is spat back into the tray.
      setState(() => _mouths[seat] = MonsterMouth.yuck);
      figure?.play(MonsterMove.shake);
      _voice.playSfx(MonsterSfx.yuck);
      unawaited(
        _voice.say(_stillNaming(food) ? MonsterPhrases.refusedJustNamed(food) : MonsterPhrases.refused(food)),
      );
      final home = _layout.slot(slot).center;
      await _fly(
        food,
        [
          _Floating(food, mouth, scale: .5),
          _Floating(
            food,
            Offset((mouth.dx + home.dx) / 2 + 30, math.min(mouth.dy, home.dy) - 80),
            scale: 1.1,
            turns: 200 / 360,
          ),
          _Floating(food, home, turns: 1),
        ],
        650,
      );
      if (_stale(session)) return;
      _floating.value = null;
      setState(() => _hiddenSlots.remove(slot));
      await _pause(250);
      if (_stale(session)) return;
      setState(() => _mouths.remove(seat));
    }
    _busy = false;
  }

  /// Keeps the monster visibly happy — a little wiggle, again and again —
  /// until [speech] has been said to its end (or, at most, a few seconds).
  /// Speech is never cut short, so sometimes the picture has to wait for
  /// the voice; it must not look frozen while it does.
  Future<void> _wiggleUntilHeard(Future<void> speech, MonsterFigureState? figure, int session) async {
    var heard = false;
    final heardOut = _heardOut(speech).then((_) => heard = true);
    // Give a line that has already ended the chance to say so first.
    await Future.any([heardOut, _pause(0)]);
    while (!heard && !_stale(session)) {
      figure?.play(MonsterMove.giggle);
      await Future.any([heardOut, _pause(600)]);
    }
  }

  /// The full monster in [seat] says goodbye and leaves; the next colour
  /// hops into its place and says hello. [after] is the line still being
  /// said when this begins («Ням! …»).
  ///
  /// Each step is one thing to see *and* hear at the same time, so a child
  /// can follow what is going on: first the monster finishes «Ням! …», then
  /// it waves while the voice says «Спасибо! Пока-пока!» and walks off, and
  /// only when that has been said does the newcomer pop out, saying hello
  /// as it lands.
  Future<void> _swap(int seat, int session, {required Future<void> after}) async {
    final figure = _figure(seat);
    await _wiggleUntilHeard(after, figure, session);
    if (_stale(session)) return;

    setState(() => _growth[seat] = 1);
    final bye = _voice.say(MonsterPhrases.byeLine);
    figure?.wave();
    await _pause(1100);
    if (_stale(session)) return;

    figure?.play(MonsterMove.leave);
    _voice.playSfx(MonsterSfx.leave);
    await Future.wait([_pause(700), _heardOut(bye, milliseconds: 2500)]);
    if (_stale(session)) return;

    final result = _game.replaceMonster(seat);
    setState(() {
      _justMet = result.firstMeeting ? result.newcomer : null;
      for (final slot in result.replacedTraySlots) {
        _slotVersions[slot]++;
      }
    });
    figure?.play(MonsterMove.enter);
    _voice.playSfx(MonsterSfx.pop);
    final hello = _voice.say(MonsterPhrases.greet(result.newcomer, firstMeeting: result.firstMeeting));
    await _pause(450);
    if (_stale(session)) return;

    figure?.clap();
    _voice.playSfx(MonsterSfx.clap);

    if (result.metEveryColor) {
      // The last colour has arrived: everybody dances.
      await Future.wait([_pause(1800), _heardOut(hello)]);
      if (_stale(session)) return;
      for (var i = 0; i < MonstersGame.seatCount; i++) {
        _figure(i)?.setDancing(true, delay: Duration(milliseconds: i.isOdd ? 200 : 0));
      }
      _voice.playSfx(MonsterSfx.win);
      setState(() => _confettiRun++);
      unawaited(_voice.say(MonsterPhrases.winLine));
      await _pause(3000);
      if (_stale(session)) return;
      for (var i = 0; i < MonstersGame.seatCount; i++) {
        _figure(i)?.setDancing(false);
      }
    }
  }

  // --------------------------------------------------------------- build

  MonsterMouth _mouthOf(int seat) =>
      _mouths[seat] ?? (_allMouthsOpen ? MonsterMouth.open : MonsterMouth.idle);

  Offset? _lookDirection(int seat) {
    final target = _lookAt;
    if (target == null) return null;
    final delta = target - _layout.figure(seat).center;
    final distance = delta.distance;
    return distance == 0 ? null : delta / distance;
  }

  static String _capitalized(String text) => '${text[0].toUpperCase()}${text.substring(1)}';

  @override
  Widget build(BuildContext context) {
    // A toddler swipes all over the screen, and a swipe from its edge would
    // otherwise throw them back to the list. The round back button still
    // works: it pops the route directly.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _sky,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layout = _layout = _Layout(constraints.biggest);
              final monsters = _game.monsters;
              final tray = _game.tray;
              return Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                // Everything in the stack is placed by hand, so it has to
                // be told to fill the screen rather than shrink to nothing.
                child: Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fromRect(rect: layout.bar, child: _buildBar()),
                    for (var seat = 0; seat < MonstersGame.seatCount; seat++)
                      Positioned.fromRect(
                        key: ValueKey('monster_seat_$seat'),
                        rect: layout.figure(seat),
                        child: Semantics(
                          label: '${_capitalized(monsters[seat].masculine)} монстрик',
                          child: MonsterFigure(
                            key: _figures[seat],
                            color: monsters[seat],
                            mouth: _mouthOf(seat),
                            lookDirection: _lookDirection(seat),
                            growth: _growth[seat],
                          ),
                        ),
                      ),
                    Positioned.fromRect(
                      rect: layout.tray,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: _skyDeep,
                          borderRadius: BorderRadius.all(Radius.circular(28)),
                        ),
                        // The darker rim along the bottom edge of the tray.
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _paper,
                              borderRadius: BorderRadius.all(Radius.circular(28)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (var slot = 0; slot < MonstersGame.traySize; slot++)
                      Positioned.fromRect(
                        key: ValueKey('monster_tray_slot_$slot'),
                        rect: layout.slot(slot),
                        child: tray[slot] == null
                            ? const SizedBox.shrink()
                            : _TrayFood(
                                food: tray[slot]!,
                                version: _slotVersions[slot],
                                selected: _selectedSlot == slot,
                                hidden: _hiddenSlots.contains(slot),
                              ),
                      ),
                    ValueListenableBuilder<_Floating?>(
                      valueListenable: _floating,
                      builder: (context, floating, _) {
                        if (floating == null) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
                        return Positioned.fromRect(
                          rect: Rect.fromCenter(
                            center: floating.center,
                            width: _floatingSide,
                            height: _floatingSide,
                          ),
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: floating.turns * 2 * math.pi,
                              child: Transform.scale(
                                scale: floating.scale,
                                child: SvgPicture.string(foodSvg(floating.food)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_confettiRun > 0)
                      Positioned.fill(
                        child: IgnorePointer(child: _Confetti(key: ValueKey(_confettiRun))),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBar() {
    final met = _game.metColors;
    return Row(
      children: [
        _RoundButton(
          key: const ValueKey('monsters_back_button'),
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          // One dot per colour: the ones already met are filled in, and
          // the one met a moment ago glows.
          child: Semantics(
            label: 'Знакомых цветов: ${met.length} из ${MonsterColor.values.length}',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final color in MonsterColor.values)
                    _MetDot(
                      key: ValueKey('monsters_met_${color.name}'),
                      color: color,
                      met: met.contains(color),
                      justMet: color == _justMet,
                    ),
                ],
              ),
            ),
          ),
        ),
        _RoundButton(
          key: const ValueKey('monsters_restart_button'),
          icon: Icons.refresh_rounded,
          tooltip: 'Сначала',
          onPressed: () => setState(_startGame),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: _paper,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _skyDeep, offset: Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, color: _ink, size: 28),
          ),
        ),
      ),
    );
  }
}

class _MetDot extends StatelessWidget {
  const _MetDot({super.key, required this.color, required this.met, required this.justMet});

  final MonsterColor color;
  final bool met;
  final bool justMet;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration decoration;
    if (justMet) {
      decoration = BoxDecoration(
        color: monsterFill(color),
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: _paper, spreadRadius: 3)],
      );
    } else if (met) {
      decoration = BoxDecoration(
        color: monsterFill(color),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x2E000000), width: 1.5),
      );
    } else {
      decoration = BoxDecoration(
        color: _paper,
        shape: BoxShape.circle,
        border: Border.all(color: _skyDeep, width: 3),
      );
    }
    return AnimatedScale(
      scale: justMet ? 1.35 : 1,
      duration: const Duration(milliseconds: 300),
      child: Container(width: 12, height: 12, decoration: decoration),
    );
  }
}

/// One treat lying in the tray. It pops in when it is new ([version]
/// changes), bobs while [selected], and fades out while [hidden] — that is,
/// while it is under a finger or flying.
class _TrayFood extends StatefulWidget {
  const _TrayFood({required this.food, required this.version, required this.selected, required this.hidden});

  final MonsterFood food;
  final int version;
  final bool selected;
  final bool hidden;

  @override
  State<_TrayFood> createState() => _TrayFoodState();
}

class _TrayFoodState extends State<_TrayFood> with SingleTickerProviderStateMixin {
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    if (widget.selected) _bob.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_TrayFood old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    if (widget.selected) {
      _bob.repeat(reverse: true);
    } else {
      _bob
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.food.name;
    return Semantics(
      label: '${name[0].toUpperCase()}${name.substring(1)}',
      child: AnimatedOpacity(
        opacity: widget.hidden ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: AnimatedScale(
          scale: widget.selected ? 1.15 : 1,
          duration: const Duration(milliseconds: 200),
          child: AnimatedBuilder(
            animation: _bob,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, widget.selected ? -6 - 8 * Curves.easeInOut.transform(_bob.value) : 0),
              child: child,
            ),
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.version),
              tween: Tween(begin: .3, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.ease,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: SvgPicture.string(foodSvg(widget.food)),
            ),
          ),
        ),
      ),
    );
  }
}

/// A burst of confetti in every monster colour, falling once from the top
/// of the screen to the bottom.
class _Confetti extends StatefulWidget {
  const _Confetti({super.key});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiPiece {
  _ConfettiPiece(math.Random random, int index)
      : left = random.nextDouble(),
        color = monsterFill(MonsterColor.values[index % MonsterColor.values.length]),
        seconds = 1.6 + random.nextDouble() * 1.4,
        delay = random.nextDouble() * .5;

  final double left;
  final Color color;
  final double seconds;
  final double delay;
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  static const _totalSeconds = 3.6;

  late final AnimationController _fall = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_totalSeconds * 1000).round()),
  )..forward();

  late final List<_ConfettiPiece> _pieces = () {
    final random = math.Random();
    return [for (var i = 0; i < 40; i++) _ConfettiPiece(random, i)];
  }();

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: _fall,
          builder: (context, _) {
            final seconds = _fall.value * _totalSeconds;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final piece in _pieces)
                  if (seconds > piece.delay && seconds < piece.delay + piece.seconds)
                    () {
                      final progress = (seconds - piece.delay) / piece.seconds;
                      return Positioned(
                        left: piece.left * size.width,
                        top: -20 + progress * size.height * 1.1,
                        child: Transform.rotate(
                          angle: progress * 4 * math.pi,
                          child: Container(
                            width: 12,
                            height: 18,
                            decoration: BoxDecoration(
                              color: piece.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      );
                    }(),
              ],
            );
          },
        );
      },
    );
  }
}
