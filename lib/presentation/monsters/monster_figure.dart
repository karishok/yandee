import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/monsters/monster_color.dart';
import 'monster_art.dart';

/// The shape of a monster's mouth.
enum MonsterMouth {
  /// A small smile.
  idle,

  /// Wide open, waiting for food.
  open,

  /// Munching.
  chomp,

  /// Disgusted, tongue out — the eyes squint shut with it.
  yuck,
}

/// A one-off movement of the whole monster.
enum MonsterMove { chomp, shake, giggle, enter, leave }

enum _ArmMove { clap, wave }

/// One animated monster, drawn into a square.
///
/// What it looks like at rest comes from the widget's fields; movements are
/// started through its [MonsterFigureState] (via a `GlobalKey`), because a
/// movement is an event — "clap now" — rather than a state to rebuild into.
class MonsterFigure extends StatefulWidget {
  const MonsterFigure({
    super.key,
    required this.color,
    this.mouth = MonsterMouth.idle,
    this.lookDirection,
    this.growth = 1,
  });

  final MonsterColor color;
  final MonsterMouth mouth;

  /// Which way the pupils look, as a direction of length 1; null looks
  /// straight ahead.
  final Offset? lookDirection;

  /// The monster's size relative to normal — it swells a little with every
  /// treat.
  final double growth;

  @override
  State<MonsterFigure> createState() => MonsterFigureState();
}

class MonsterFigureState extends State<MonsterFigure> with TickerProviderStateMixin {
  late final AnimationController _move = AnimationController(vsync: this);
  late final AnimationController _arms = AnimationController(vsync: this);
  late final AnimationController _dance =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  MonsterMove? _moveKind;
  _ArmMove _armMove = _ArmMove.clap;

  static const _moveDurations = {
    MonsterMove.chomp: Duration(milliseconds: 450),
    MonsterMove.shake: Duration(milliseconds: 500),
    MonsterMove.giggle: Duration(milliseconds: 600),
    MonsterMove.enter: Duration(milliseconds: 700),
    MonsterMove.leave: Duration(milliseconds: 700),
  };

  /// The movement in progress, or — for [MonsterMove.leave] — the one the
  /// monster is frozen at the end of. Null when standing still.
  @visibleForTesting
  MonsterMove? get currentMove => _moveKind;

  @visibleForTesting
  bool get isClapping => _arms.isAnimating && _armMove == _ArmMove.clap;

  @visibleForTesting
  bool get isWaving => _arms.isAnimating && _armMove == _ArmMove.wave;

  @visibleForTesting
  bool get isDancing => _dance.isAnimating;

  /// Plays [move] once from the start. After [MonsterMove.leave] the
  /// monster stays gone until the next [MonsterMove.enter]; after any other
  /// move it stands still again.
  void play(MonsterMove move) {
    _moveKind = move;
    _move.duration = _moveDurations[move];
    _move.forward(from: 0).whenComplete(() {
      if (!mounted || _moveKind != move || move == MonsterMove.leave) return;
      if (_move.status == AnimationStatus.completed) {
        setState(() => _moveKind = null);
      }
    });
  }

  /// Two claps in front of the belly.
  void clap() => _swingArms(_ArmMove.clap, const Duration(milliseconds: 900));

  /// Waves goodbye with the right hand.
  void wave() => _swingArms(_ArmMove.wave, const Duration(milliseconds: 1000));

  void _swingArms(_ArmMove move, Duration duration) {
    _armMove = move;
    _arms.duration = duration;
    _arms.forward(from: 0).whenComplete(() {
      if (mounted && _arms.status == AnimationStatus.completed) _arms.value = 0;
    });
  }

  /// Starts or stops the celebration dance: bouncing from foot to foot and
  /// clapping without end.
  void setDancing(bool dancing, {Duration delay = Duration.zero}) {
    if (dancing) {
      _armMove = _ArmMove.clap;
      _arms.duration = const Duration(milliseconds: 900);
      _arms.repeat();
      // Neighbours start out of step, so the row doesn't bounce as one block.
      _dance.value = delay.inMilliseconds / 500;
      _dance.repeat(reverse: true);
    } else {
      _dance
        ..stop()
        ..value = 0;
      _arms
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _move.dispose();
    _arms.dispose();
    _dance.dispose();
    super.dispose();
  }

  // Interpolates along CSS-style keyframes: `stops` are the keyframe
  // positions (0…1), `values` the value at each, and the easing curve
  // applies within each pair of neighbours, as CSS animations do.
  static double _track(double t, List<double> stops, List<double> values, Curve curve) {
    for (var i = 1; i < stops.length; i++) {
      if (t <= stops[i]) {
        final local = (t - stops[i - 1]) / (stops[i] - stops[i - 1]);
        final eased = curve.transform(local.clamp(0.0, 1.0));
        return values[i - 1] + (values[i] - values[i - 1]) * eased;
      }
    }
    return values.last;
  }

  static const _enterCurve = Cubic(.3, 1.6, .5, 1);
  static double _deg(double degrees) => degrees * math.pi / 180;

  // The whole-body transform for this frame. Distances in the keyframes are
  // in pixels of the prototype's ~180px monster, scaled by `unit` here.
  ({Matrix4 transform, double opacity}) _bodyPose(double unit) {
    var dx = 0.0, dy = 0.0, scaleX = 1.0, scaleY = 1.0, rotation = 0.0, opacity = 1.0;
    final t = _move.value;
    switch (_moveKind) {
      case MonsterMove.chomp:
        scaleX = _track(t, const [0, .3, .6, 1], const [1, 1.12, .95, 1], Curves.ease);
        scaleY = _track(t, const [0, .3, .6, 1], const [1, .9, 1.08, 1], Curves.ease);
      case MonsterMove.shake:
        dx = _track(t, const [0, .2, .4, .6, .8, 1], const [0, -8, 8, -6, 5, 0], Curves.ease);
        rotation = _deg(_track(t, const [0, .2, .4, .6, .8, 1], const [0, -3, 3, 0, 0, 0], Curves.ease));
      case MonsterMove.giggle:
        rotation = _deg(_track(t, const [0, .25, .75, 1], const [0, -6, 6, 0], Curves.ease));
      case MonsterMove.enter:
        final eased = _enterCurve.transform(t);
        scaleX = scaleY = math.max(0, eased);
        rotation = _deg(-20 * (1 - eased));
      case MonsterMove.leave:
        dy = _track(t, const [0, .3, 1], const [0, -14, 40], Curves.easeIn);
        scaleX = scaleY = _track(t, const [0, .3, 1], const [1, 1.05, 0], Curves.easeIn);
        rotation = _deg(_track(t, const [0, .3, 1], const [0, 0, 25], Curves.easeIn));
        opacity = _track(t, const [0, .3, 1], const [1, 1, 0], Curves.easeIn);
      case null:
        break;
    }
    if (_dance.isAnimating) {
      final sway = Curves.easeInOut.transform(_dance.value);
      dy += -14 * sway;
      rotation += _deg(-4 + 8 * sway);
    }
    final transform = Matrix4.identity()
      ..translateByDouble(dx * unit, dy * unit, 0, 1)
      ..rotateZ(rotation)
      ..scaleByDouble(scaleX, scaleY, 1, 1);
    return (transform: transform, opacity: opacity.clamp(0.0, 1.0));
  }

  // How far each arm is swung, in radians, for the left arm; the right arm
  // mirrors a clap. A wave moves the right arm only.
  ({double left, double right}) _armAngles() {
    final t = _arms.value;
    switch (_armMove) {
      case _ArmMove.clap:
        final angle =
            _deg(_track(t, const [0, .25, .45, .65, 1], const [0, -100, -70, -100, 0], Curves.easeInOut));
        return (left: angle, right: -angle);
      case _ArmMove.wave:
        final angle = _deg(
          _track(t, const [0, .2, .4, .6, .8, 1], const [0, -150, -120, -150, -120, 0], Curves.easeInOut),
        );
        return (left: 0, right: angle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = MonsterLayers.of(widget.color);
    final squinting = widget.mouth == MonsterMouth.yuck;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final viewBoxUnit = side / monsterViewBoxSize;
        final look = widget.lookDirection;
        final pupilShift =
            look == null ? Offset.zero : look * (monsterPupilReach(widget.color) * viewBoxUnit);

        Widget layer(String svg, {bool visible = true}) => Offstage(
              offstage: !visible,
              child: SvgPicture.string(svg, width: side, height: side),
            );

        Widget arm(String svg, ({double x, double y}) shoulder, double angle) => Transform.rotate(
              angle: angle,
              alignment: FractionalOffset(shoulder.x, shoulder.y),
              child: layer(svg),
            );

        return Center(
          child: SizedBox.square(
            dimension: side,
            child: AnimatedScale(
              scale: widget.growth,
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
              child: AnimatedBuilder(
                animation: Listenable.merge([_move, _arms, _dance]),
                builder: (context, _) {
                  final pose = _bodyPose(side / 180);
                  final arms = _armAngles();
                  return Opacity(
                    opacity: pose.opacity,
                    child: Transform(
                      transform: pose.transform,
                      alignment: Alignment.center,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          layer(layers.body),
                          layer(layers.eyeWhites, visible: !squinting),
                          TweenAnimationBuilder<Offset>(
                            tween: Tween(end: pupilShift),
                            duration: const Duration(milliseconds: 150),
                            builder: (context, shift, child) =>
                                Transform.translate(offset: shift, child: child),
                            child: layer(layers.pupils, visible: !squinting),
                          ),
                          layer(layers.squint, visible: squinting),
                          layer(layers.mouthIdle, visible: widget.mouth == MonsterMouth.idle),
                          layer(layers.mouthOpen, visible: widget.mouth == MonsterMouth.open),
                          layer(layers.mouthChomp, visible: widget.mouth == MonsterMouth.chomp),
                          layer(layers.mouthYuck, visible: widget.mouth == MonsterMouth.yuck),
                          arm(layers.leftArm, monsterLeftShoulderAt, arms.left),
                          arm(layers.rightArm, monsterRightShoulderAt, arms.right),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
