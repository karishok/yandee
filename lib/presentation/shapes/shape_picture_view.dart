import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/shapes/shape_picture.dart';
import 'shape_art.dart';
import 'shape_effects.dart';
import 'shape_motion.dart';

/// The picture card of the "Фигурки" game: the background, the dashed
/// places and the pieces already in them, and — once [alive] — the
/// picture's own motion and effects. Square: it takes the largest square
/// that fits.
class ShapePictureView extends StatefulWidget {
  const ShapePictureView({
    super.key,
    required this.picture,
    required this.filled,
    this.highlighted,
    this.hinting = const {},
    this.hintRun = 0,
    this.alive = false,
    this.backgroundAsset,
  });

  final ShapePicture picture;
  final Set<int> filled;

  /// The empty slot the finger is over: its outline is lit up.
  final int? highlighted;

  /// Empty slots to show the child: lit up and pulsing.
  final Set<int> hinting;

  /// Bumped to play the hint pulse again.
  final int hintRun;

  final bool alive;

  /// A painted background to show instead of the stand-in one.
  final String? backgroundAsset;

  @override
  State<ShapePictureView> createState() => _ShapePictureViewState();
}

class _ShapePictureViewState extends State<ShapePictureView> with TickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this);
  late final AnimationController _hint =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Ticker _effectsTicker = createTicker((elapsed) {
    _seconds.value = elapsed.inMicroseconds / 1e6;
  });
  final ValueNotifier<double> _seconds = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    if (widget.alive) _comeAlive();
    if (widget.hinting.isNotEmpty) _pulseHint();
  }

  @override
  void didUpdateWidget(ShapePictureView old) {
    super.didUpdateWidget(old);
    if (widget.alive && !old.alive) _comeAlive();
    if (!widget.alive && old.alive) _settle();
    if (widget.hintRun != old.hintRun && widget.hinting.isNotEmpty) _pulseHint();
  }

  void _comeAlive() {
    _motion.duration = motionDuration(widget.picture.motion);
    _motion.forward(from: 0);
    _seconds.value = 0;
    if (!_effectsTicker.isActive) _effectsTicker.start();
  }

  void _settle() {
    _motion.reset();
    _effectsTicker.stop();
    _seconds.value = 0;
  }

  void _pulseHint() {
    _hint.reset();
    _hint.repeat(reverse: true, count: 4);
  }

  @override
  void dispose() {
    _effectsTicker.dispose();
    _motion.dispose();
    _hint.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = math.min(constraints.maxWidth, constraints.maxHeight);
      final scale = side / cardSize;
      final picture = widget.picture;
      final art = artOf(picture);
      final backdrop = backdropSvg(picture);
      final moving = [for (var i = 0; i < picture.slots.length; i++) if (!picture.slots[i].stays) i];
      final staying = [for (var i = 0; i < picture.slots.length; i++) if (picture.slots[i].stays) i];
      return Center(
        child: SizedBox.square(
          dimension: side,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30 * scale),
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.backgroundAsset != null
                    ? Image.asset(widget.backgroundAsset!, fit: BoxFit.cover)
                    : SvgPicture.string(backgroundSvg(picture)),
                AnimatedBuilder(
                  animation: _motion,
                  builder: (context, child) {
                    final m = pictureMotion(picture.motion, _motion.value, picture.pivot);
                    return Transform(
                      transform: Matrix4.diagonal3Values(scale, scale, 1)
                        ..multiply(m)
                        ..multiply(Matrix4.diagonal3Values(1 / scale, 1 / scale, 1)),
                      child: child,
                    );
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (backdrop.isNotEmpty) SvgPicture.string(backdrop),
                      for (final i in moving) _slot(i, scale),
                      if (widget.alive)
                        ValueListenableBuilder<double>(
                          valueListenable: _seconds,
                          builder: (context, seconds, _) =>
                              CustomPaint(painter: EffectsPainter(art.effects, seconds)),
                        ),
                    ],
                  ),
                ),
                for (final i in staying) _slot(i, scale),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _slot(int index, double scale) {
    final slot = widget.picture.slots[index];
    final filled = widget.filled.contains(index);
    final hinting = !filled && widget.hinting.contains(index);
    final layer = SvgPicture.string(
      slotLayerSvg(widget.picture, index,
          filled: filled, highlighted: !filled && (hinting || widget.highlighted == index)),
    );
    final center = Offset(slot.box.center.x * scale, slot.box.center.y * scale);
    Widget scaled(double s, Widget child) => Transform(
          transform: Matrix4.translationValues(center.dx, center.dy, 0)
            ..multiply(Matrix4.diagonal3Values(s, s, 1))
            ..multiply(Matrix4.translationValues(-center.dx, -center.dy, 0)),
          child: child,
        );
    final Listenable? driver = hinting ? _hint : (widget.alive && slot.pulses ? _motion : null);
    return KeyedSubtree(
      key: ValueKey('shapes_slot_$index'),
      child: driver == null
          ? layer
          : AnimatedBuilder(
              animation: driver,
              builder: (context, child) =>
                  scaled(hinting ? 1 + .12 * _hint.value : pulseScale(_motion.value), child!),
              child: layer,
            ),
    );
  }
}
