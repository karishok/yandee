import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../audio/clip_line_player.dart';
import '../../audio/shapes_voice.dart';
import '../../audio/shapes_voice_player.dart';
import '../../domain/shapes/shape_kind.dart';
import '../../domain/shapes/shape_phrases.dart';
import '../../domain/shapes/shape_picture.dart';
import '../../domain/shapes/shapes_game.dart';
import '../shapes/shape_art.dart';
import '../shapes/shape_picture_view.dart';

const _paper = Color(0xFFFFF8F0);
const _cardColor = Color(0xFFFFF0E1);
const _mat = Color(0xFFFFE6CD);
const _stitch = Color(0xFFE3C39C);
const _ink = Color(0xFF2B211A);
const _shadow = Color(0x24543410);

/// The "Фигурки" game: a picture card made of dashed places, a mat with one
/// wooden piece on it, and the child drags the piece to its place.
///
/// The rules live in [ShapesGame]; this screen turns drags and taps into
/// its calls and plays out each result as flight, sound and speech, the way
/// the prototype (`docs/prototypes/shapes.html`) does.
class ShapesScreen extends StatefulWidget {
  const ShapesScreen({super.key, this.voiceFactory, this.gameFactory, this.bundledAssets});

  /// Makes the sound output; tests pass a fake.
  final ShapesVoice Function()? voiceFactory;

  /// Makes the game; tests pass a seeded one.
  final ShapesGame Function()? gameFactory;

  /// Lists the app's assets, to find painted backgrounds. Tests pass none.
  final Future<Set<String>> Function()? bundledAssets;

  @override
  State<ShapesScreen> createState() => _ShapesScreenState();
}

/// Where everything sits for a given screen size — plain arithmetic, so a
/// finger can be hit-tested without looking into the widget tree.
class _Layout {
  _Layout(this.size);

  final Size size;
  static const _side = 16.0;
  static const _gap = 12.0;

  Rect get bar => Rect.fromLTWH(_side, 8, size.width - 2 * _side, 60);

  Rect get mat {
    final height = (size.height * .26).clamp(120.0, 220.0);
    return Rect.fromLTWH(_side, size.height - 12 - height, size.width - 2 * _side, height);
  }

  Rect get card {
    final top = bar.bottom + _gap, bottom = mat.top - _gap;
    final side = math.min(size.width - 2 * _side, bottom - top);
    return Rect.fromCenter(center: Offset(size.width / 2, (top + bottom) / 2), width: side, height: side);
  }

  double get scale => card.width / cardSize;

  Rect onCard(CardBox box) =>
      Rect.fromLTWH(card.left + box.x * scale, card.top + box.y * scale, box.width * scale, box.height * scale);

  ({double x, double y}) toCard(Offset point) =>
      (x: (point.dx - card.left) / scale, y: (point.dy - card.top) / scale);

  /// The piece for [slot] lying on the mat, as big as the mat allows.
  Rect pieceOnMat(ShapeSlot slot) {
    final frame = pieceFrame(slot);
    final k = math.min(mat.width * .62 / frame.width, mat.height * .8 / frame.height);
    return Rect.fromCenter(center: mat.center, width: frame.width * k, height: frame.height * k);
  }
}

class _Touch {
  _Touch({required this.pointer, required this.start, required this.onPiece});

  final int pointer;
  final Offset start;
  final bool onPiece;

  /// Where the finger holds the piece, from its top left corner.
  Offset grip = Offset.zero;
  bool dragging = false;
}

class _ShapesScreenState extends State<ShapesScreen> with SingleTickerProviderStateMixin {
  static const _dragSlop = 10.0;
  static const _tapSlop = 24.0;
  static const _dropMargin = 24.0;

  late final ShapesVoice _voice = widget.voiceFactory?.call() ?? ShapesVoicePlayer();
  late final AnimationController _flight = AnimationController(vsync: this);
  late ShapesGame _game;
  final ValueNotifier<Rect?> _floating = ValueNotifier(null);
  final Set<Timer> _timers = {};
  _Layout _layout = _Layout(Size.zero);
  Set<String> _bundled = const {};

  int _session = 0;
  bool _busy = false;
  _Touch? _touch;
  int? _over;
  Set<int> _hinting = const {};
  int _hintRun = 0;
  bool _alive = false;
  ShapeKind? _justMet;
  int _pieceRun = 0;
  int _wiggleRun = 0;
  int _confettiRun = 0;
  Rect Function(double t)? _flightPath;

  @override
  void initState() {
    super.initState();
    _flight.addListener(() {
      final path = _flightPath;
      if (path != null) _floating.value = path(_flight.value);
    });
    final assets = widget.bundledAssets?.call() ?? listBundledAssets(rootBundle);
    assets.then((value) {
      if (mounted) setState(() => _bundled = value);
    });
    _game = widget.gameFactory?.call() ?? ShapesGame();
    final session = _session;
    _pause(400).then((_) {
      if (_stale(session)) return;
      unawaited(_voice.say(ShapePhrases.introLine));
      _showNextPiece();
    });
  }

  @override
  void dispose() {
    _session++;
    for (final timer in _timers) {
      timer.cancel();
    }
    _flight.dispose();
    _floating.dispose();
    _voice.dispose();
    super.dispose();
  }

  bool _stale(int session) => !mounted || session != _session;

  /// Waits [milliseconds]; the wait is dropped if the screen closes first.
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

  /// Waits for [speech] to end, but no longer than [milliseconds].
  Future<void> _heardOut(Future<void> speech, {int milliseconds = 4000}) =>
      Future.any([speech.catchError((Object _) {}), _pause(milliseconds)]);

  void _showNextPiece() {
    final piece = _game.nextPiece();
    setState(() {
      _pieceRun++;
      if (piece.firstMeeting) _justMet = piece.kind;
    });
    unawaited(_voice.say(piece.firstMeeting ? ShapePhrases.meet(piece.kind) : ShapePhrases.name(piece.kind)));
  }

  Rect? get _pieceRect {
    final slot = _game.pieceSlot;
    return slot == null ? null : _layout.pieceOnMat(_game.picture.slots[slot]);
  }

  // ------------------------------------------------------------- touches

  void _onPointerDown(PointerDownEvent event) {
    if (_touch != null || _busy) return;
    final point = event.localPosition;
    final piece = _pieceRect;
    if (piece != null && piece.contains(point)) {
      _touch = _Touch(pointer: event.pointer, start: point, onPiece: true)..grip = point - piece.topLeft;
    } else if (_layout.card.contains(point)) {
      _touch = _Touch(pointer: event.pointer, start: point, onPiece: false);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    final touch = _touch;
    if (touch == null || touch.pointer != event.pointer || !touch.onPiece || _busy) return;
    final point = event.localPosition;
    if (!touch.dragging && (point - touch.start).distance > _dragSlop) touch.dragging = true;
    if (!touch.dragging) return;
    final piece = _pieceRect!;
    _floating.value = (point - touch.grip) & piece.size;
    final over = _slotAt(point);
    if (over != _over) setState(() => _over = over);
  }

  void _onPointerUp(PointerUpEvent event) => _endTouch(event.pointer, event.localPosition, cancelled: false);

  void _onPointerCancel(PointerCancelEvent event) => _endTouch(event.pointer, event.localPosition, cancelled: true);

  int? _slotAt(Offset point) {
    final p = _layout.toCard(point);
    return _game.slotAt(p.x, p.y, margin: _dropMargin / _layout.scale);
  }

  void _endTouch(int pointer, Offset point, {required bool cancelled}) {
    final touch = _touch;
    if (touch == null || touch.pointer != pointer) return;
    _touch = null;
    if (_busy) return;
    if (_over != null) setState(() => _over = null);

    if (!touch.onPiece) {
      // A tap on an empty place: it lights up and says its shape.
      if (cancelled || (point - touch.start).distance > _tapSlop) return;
      final p = _layout.toCard(point);
      final slot = _game.slotAt(p.x, p.y);
      if (slot == null) return;
      setState(() {
        _hinting = {slot};
        _hintRun++;
      });
      unawaited(_voice.say(ShapePhrases.name(_game.picture.slots[slot].kind)));
      return;
    }
    if (!touch.dragging) {
      if (cancelled) return;
      setState(() => _wiggleRun++);
      unawaited(_voice.say(ShapePhrases.name(_game.pieceKind!)));
      return;
    }
    final slot = cancelled ? null : _slotAt(point);
    if (slot == null) {
      unawaited(_flyBack());
    } else {
      unawaited(_drop(slot));
    }
  }

  // ----------------------------------------------------------- sequences

  Future<void> _fly(Rect to, int milliseconds) async {
    final from = _floating.value ?? _pieceRect!;
    _flightPath = (t) => Rect.lerp(from, to, Curves.easeOutCubic.transform(t))!;
    _flight.duration = Duration(milliseconds: milliseconds);
    try {
      await _flight.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The screen closed mid-flight.
    }
  }

  Future<void> _flyBack() async {
    _busy = true;
    final session = _session;
    await _fly(_pieceRect!, 320);
    if (_stale(session)) return;
    _floating.value = null;
    _busy = false;
  }

  Future<void> _drop(int slot) async {
    _busy = true;
    final session = _session;
    final target = _layout.onCard(pieceFrame(_game.picture.slots[slot]));
    await _fly(target, 300);
    if (_stale(session)) return;
    final result = _game.drop(slot);

    if (!result.accepted) {
      _voice.playSfx(ShapesSfx.wrong);
      final speech = _voice.say(ShapePhrases.notHereLine);
      await _heardOut(speech, milliseconds: 2500);
      if (_stale(session)) return;
      final kind = _game.pieceKind;
      setState(() {
        _hinting = {
          for (var i = 0; i < _game.picture.slots.length; i++)
            if (!_game.filled.contains(i) && _game.picture.slots[i].kind == kind) i,
        };
        _hintRun++;
      });
      await _fly(_pieceRect!, 320);
      if (_stale(session)) return;
      _floating.value = null;
      _busy = false;
      return;
    }

    _voice.playSfx(ShapesSfx.placed);
    _floating.value = null;
    setState(() => _hinting = const {});
    if (!result.pictureComplete) {
      await _pause(320);
      if (_stale(session)) return;
      _showNextPiece();
      _busy = false;
      return;
    }
    await _celebrate(result, session);
  }

  Future<void> _celebrate(DropResult result, int session) async {
    await _pause(350);
    if (_stale(session)) return;
    setState(() => _alive = true);
    _voice.playSfx(ShapesSfx.pictureDone);
    final speech = _voice.say(ShapePhrases.done(_game.picture));
    await Future.wait([_pause(3500), _heardOut(speech)]);
    if (_stale(session)) return;
    if (result.chainComplete) {
      setState(() => _confettiRun++);
      _voice.playSfx(ShapesSfx.allDone);
      final win = _voice.say(ShapePhrases.winLine);
      await Future.wait([_pause(3200), _heardOut(win)]);
      if (_stale(session)) return;
    }
    _game.nextPicture();
    setState(() {
      _alive = false;
      _justMet = null;
    });
    _showNextPiece();
    _busy = false;
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    // A swipe from the screen edge must not throw a toddler back to the
    // list; the round back button still works.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _paper,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final layout = _layout = _Layout(constraints.biggest);
            final picture = _game.picture;
            final pieceSlot = _game.pieceSlot;
            final background = backgroundAssetOf(picture);
            return Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(rect: layout.bar, child: _buildBar()),
                  Positioned.fromRect(
                    key: const ValueKey('shapes_card'),
                    rect: layout.card,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30 * layout.scale),
                        boxShadow: const [BoxShadow(color: _shadow, blurRadius: 18, offset: Offset(0, 12))],
                      ),
                      child: ShapePictureView(
                        picture: picture,
                        filled: _game.filled,
                        highlighted: _over,
                        hinting: _hinting,
                        hintRun: _hintRun,
                        alive: _alive,
                        backgroundAsset: _bundled.contains(background) ? background : null,
                      ),
                    ),
                  ),
                  Positioned.fromRect(rect: layout.mat, child: const _Mat()),
                  if (pieceSlot != null)
                    ValueListenableBuilder<Rect?>(
                      valueListenable: _floating,
                      builder: (context, floating, _) => Positioned.fromRect(
                        key: const ValueKey('shapes_piece'),
                        rect: layout.pieceOnMat(picture.slots[pieceSlot]),
                        child: Opacity(
                          opacity: floating == null ? 1 : 0,
                          child: _MatPiece(
                            svg: pieceSvg(picture, pieceSlot),
                            popRun: _pieceRun,
                            wiggleRun: _wiggleRun,
                          ),
                        ),
                      ),
                    ),
                  if (pieceSlot != null)
                    ValueListenableBuilder<Rect?>(
                      valueListenable: _floating,
                      builder: (context, floating, _) => floating == null
                          ? const Positioned(left: 0, top: 0, child: SizedBox.shrink())
                          : Positioned.fromRect(
                              rect: floating,
                              child: IgnorePointer(child: SvgPicture.string(pieceSvg(picture, pieceSlot))),
                            ),
                    ),
                  if (_confettiRun > 0)
                    Positioned.fill(child: IgnorePointer(child: _Confetti(key: ValueKey(_confettiRun)))),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildBar() {
    final met = _game.metKinds;
    return Row(
      children: [
        _RoundButton(
          key: const ValueKey('shapes_back_button'),
          icon: Icons.arrow_back_ios_new_rounded,
          tooltip: 'Назад',
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Semantics(
            label: 'Знакомых фигурок: ${met.length} из ${ShapeKind.values.length}',
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                for (final kind in ShapeKind.values)
                  AnimatedScale(
                    key: ValueKey('shapes_kind_${kind.name}'),
                    scale: kind == _justMet ? 1.35 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: SvgPicture.string(kindIconSvg(kind, met: met.contains(kind)), width: 26, height: 26),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 56),
      ],
    );
  }
}

/// The soft stitched mat the piece lies on.
class _Mat extends StatelessWidget {
  const _Mat();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _mat,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: _shadow, blurRadius: 26, offset: Offset(0, 10))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _stitch, width: 2),
          ),
        ),
      ),
    );
  }
}

/// The piece on the mat: it pops in when new ([popRun] changes) and
/// wiggles when tapped ([wiggleRun] changes).
class _MatPiece extends StatelessWidget {
  const _MatPiece({required this.svg, required this.popRun, required this.wiggleRun});

  final String svg;
  final int popRun;
  final int wiggleRun;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('pop_$popRun'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('wiggle_$wiggleRun'),
        tween: Tween(begin: wiggleRun == 0 ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, t, child) =>
            Transform.rotate(angle: math.sin(t * 2 * math.pi) * .17, child: child),
        child: SvgPicture.string(svg),
      ),
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
          color: _cardColor,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _shadow, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onPressed, child: Icon(icon, color: _ink, size: 28)),
        ),
      ),
    );
  }
}

/// A burst of confetti in toy colours, falling once from top to bottom.
class _Confetti extends StatefulWidget {
  const _Confetti({super.key});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  static const _colors = [
    ToyColors.red, ToyColors.blue, ToyColors.yellow, ToyColors.green,
    ToyColors.orange, ToyColors.purple, ToyColors.pink, ToyColors.lightBlue,
  ];
  late final AnimationController _fall =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..forward();
  final _pieces = [
    for (var i = 0; i < 40; i++)
      (x: (i * 37 % 100) / 100, delay: (i * 13 % 10) / 25, spin: (i % 7 - 3) * 1.4, color: _colors[i % _colors.length]),
  ];

  @override
  void dispose() {
    _fall.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return AnimatedBuilder(
        animation: _fall,
        builder: (context, _) => Stack(children: [
          for (final p in _pieces)
            if (_fall.value > p.delay)
              Positioned(
                left: p.x * size.width,
                top: -20 + (size.height + 60) * ((_fall.value - p.delay) / (1 - p.delay)),
                child: Transform.rotate(
                  angle: p.spin * _fall.value * math.pi,
                  child: Container(
                    width: 14,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | int.parse(p.color.substring(1), radix: 16)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
        ]),
      );
    });
  }
}
