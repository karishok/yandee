import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/object_outline.dart';
import '../../domain/models/scene_object.dart';

/// The night laid over a scene in the flashlight game: everything is dark
/// except a soft circle of light at [lightCenter] and the objects the child
/// has already found, which stay lit. When [lightsOn] turns true the whole
/// darkness fades away.
///
/// Purely visual — it never takes part in hit-testing, so the scene's own
/// pointer handling (which moves the light and finds objects) sits on top.
class FlashlightDarkness extends StatefulWidget {
  const FlashlightDarkness({
    super.key,
    required this.lightCenter,
    required this.objects,
    required this.isFound,
    required this.lightsOn,
  });

  /// Where the light points, normalized to the picture (0..1 on each axis).
  final Offset lightCenter;

  /// The things to find, as they sit on the picture being shown. A found
  /// one shows through the dark in the shape of its outline (or, with no
  /// outline on this picture, as a soft oval over its tap zone).
  final List<SceneObject> objects;

  /// Whether an object has already been found (and so stays lit).
  final bool Function(SceneObject object) isFound;

  /// True once everything is found: the lights come on.
  final bool lightsOn;

  /// How long the light has to sit still before an object still hiding in
  /// the dark starts to twinkle, so a child who's stuck gets a nudge.
  static const hintDelay = Duration(seconds: 6);

  @override
  State<FlashlightDarkness> createState() => _FlashlightDarknessState();
}

class _FlashlightDarknessState extends State<FlashlightDarkness> with SingleTickerProviderStateMixin {
  // Drives the hint twinkle and the "just found" glow; repaints every frame
  // while the game is on.
  late final AnimationController _ticker =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  final Stopwatch _clock = Stopwatch()..start();

  // When each object id was found, on [_clock], for its reveal animation.
  final Map<String, Duration> _foundAt = {};

  Timer? _hintTimer;
  bool _hintsVisible = false;

  @override
  void initState() {
    super.initState();
    for (final object in widget.objects) {
      // Already lit when the widget appears: no reveal animation.
      if (widget.isFound(object)) _foundAt[object.id] = Duration.zero;
    }
    _restartHintTimer();
  }

  @override
  void didUpdateWidget(FlashlightDarkness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lightCenter != oldWidget.lightCenter) _restartHintTimer();
    for (final object in widget.objects) {
      if (widget.isFound(object)) _foundAt.putIfAbsent(object.id, () => _clock.elapsed);
    }
    if (widget.lightsOn) {
      _hintTimer?.cancel();
      _hintsVisible = false;
    }
  }

  void _restartHintTimer() {
    _hintTimer?.cancel();
    _hintsVisible = false;
    _hintTimer = Timer(FlashlightDarkness.hintDelay, () {
      if (mounted) setState(() => _hintsVisible = true);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        key: const ValueKey('flashlight_darkness'),
        opacity: widget.lightsOn ? 0 : 1,
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeInOut,
        child: CustomPaint(
          size: Size.infinite,
          painter: _DarknessPainter(
            repaint: _ticker,
            clock: _clock,
            lightCenter: widget.lightCenter,
            objects: widget.objects,
            foundAt: _foundAt,
            hintsVisible: _hintsVisible,
          ),
        ),
      ),
    );
  }
}

class _DarknessPainter extends CustomPainter {
  _DarknessPainter({
    required Listenable repaint,
    required this.clock,
    required this.lightCenter,
    required this.objects,
    required this.foundAt,
    required this.hintsVisible,
  }) : super(repaint: repaint);

  final Stopwatch clock;
  final Offset lightCenter;
  final List<SceneObject> objects;
  final Map<String, Duration> foundAt;
  final bool hintsVisible;

  static const _night = Color(0xF5060A1C);
  static const _revealDuration = Duration(milliseconds: 500);

  @override
  void paint(Canvas canvas, Size size) {
    final now = clock.elapsed;
    final bounds = Offset.zero & size;
    final lightRadius = size.width * 0.2;
    final light = Offset(lightCenter.dx * size.width, lightCenter.dy * size.height);

    // The night, with holes cut out of it (dstOut) for the light and for
    // every found object.
    canvas.saveLayer(bounds, Paint());
    canvas.drawRect(bounds, Paint()..color = _night);

    // Objects that share an outline (the pieces of a path) are found
    // together and need cutting out only once.
    final cut = <ObjectOutline>{};
    for (final object in objects) {
      final found = foundAt[object.id];
      if (found == null) continue;
      final progress = Curves.easeOutBack
          .transform(((now - found).inMicroseconds / _revealDuration.inMicroseconds).clamp(0.0, 1.0));
      if (progress <= 0) continue;
      final outline = object.outline;
      if (outline != null && !cut.add(outline)) continue;
      if (outline == null) {
        _cutOval(canvas, _rectOf(object, size), progress);
      } else {
        _cutSilhouette(canvas, _pathOf(outline, size), size, progress);
      }
    }

    canvas.drawCircle(
      light,
      lightRadius,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = RadialGradient(
          colors: const [Colors.black, Colors.black, Colors.transparent],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: light, radius: lightRadius)),
    );
    canvas.restore();

    // A faint warm tint, so it reads as a flashlight's beam rather than a
    // hole in the screen.
    canvas.drawCircle(
      light,
      lightRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFE9A8).withValues(alpha: 0.22), const Color(0x00FFE9A8)],
        ).createShader(Rect.fromCircle(center: light, radius: lightRadius)),
    );

    if (hintsVisible) _paintHints(canvas, size, now);
  }

  // The found object's own shape, with a little room around it and a soft
  // edge, popping out from its middle.
  void _cutSilhouette(Canvas canvas, Path silhouette, Size size, double progress) {
    final center = silhouette.getBounds().center;
    final edge = MaskFilter.blur(BlurStyle.normal, size.width * 0.008);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(progress);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawPath(
      silhouette,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = edge,
    );
    // Stroking the same shape widens the hole past the silhouette, so the
    // soft edge falls on the scenery around the object, not on the object.
    canvas.drawPath(
      silhouette,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.02
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = edge,
    );
    canvas.restore();
  }

  // For an object with no outline on the picture being shown: a soft oval
  // over its tap zone.
  void _cutOval(Canvas canvas, Rect rect, double progress) {
    final glow = rect.inflate(rect.shortestSide * 0.12);
    canvas.drawOval(
      Rect.fromCenter(center: glow.center, width: glow.width * progress, height: glow.height * progress),
      Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rect.shortestSide * 0.15),
    );
  }

  Path _pathOf(ObjectOutline outline, Size size) => Path()
    ..addPolygon([for (final point in outline.points) Offset(point.x * size.width, point.y * size.height)], true);

  // A soft twinkle on one object still hiding in the dark — just one, so
  // the hint points somewhere instead of scattering sparkles everywhere.
  // The one nearest the light, so the child only has to move a little.
  void _paintHints(Canvas canvas, Size size, Duration now) {
    final light = Offset(lightCenter.dx * size.width, lightCenter.dy * size.height);
    Offset? target;
    for (final object in objects) {
      if (foundAt.containsKey(object.id)) continue;
      final center = _rectOf(object, size).center;
      if (target == null || (center - light).distance < (target - light).distance) target = center;
    }
    if (target == null) return;
    final seconds = now.inMicroseconds / Duration.microsecondsPerSecond;
    final pulse = (math.sin(seconds * 4) + 1) / 2;
    final radius = size.width * (0.04 + 0.03 * pulse);
    canvas.drawCircle(
      target,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.5 + 0.5 * pulse),
            const Color(0xFFFFF3B0).withValues(alpha: 0.35 * pulse),
            const Color(0x00FFF3B0),
          ],
          stops: const [0, 0.35, 1],
        ).createShader(Rect.fromCircle(center: target, radius: radius)),
    );
  }

  Rect _rectOf(SceneObject object, Size size) => Rect.fromLTWH(
        object.rect.x * size.width,
        object.rect.y * size.height,
        object.rect.width * size.width,
        object.rect.height * size.height,
      );

  @override
  bool shouldRepaint(_DarknessPainter oldDelegate) =>
      oldDelegate.lightCenter != lightCenter ||
      oldDelegate.objects != objects ||
      oldDelegate.hintsVisible != hintsVisible;
}
