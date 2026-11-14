import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/cached_scene.dart';
import '../../domain/models/scene_object.dart';
import '../controllers/scene_controller.dart';
import 'flashlight_darkness.dart';

class SceneIllustration extends StatefulWidget {
  const SceneIllustration({super.key, required this.cachedScene});

  final CachedScene cachedScene;

  @override
  State<SceneIllustration> createState() => _SceneIllustrationState();
}

class _SceneIllustrationState extends State<SceneIllustration> {
  late final ImageProvider _imageProvider;
  ImageStreamListener? _listener;

  // The scene's realistic picture, for scenes that have one. Resolved up
  // front (see initState) so that switching to it is instant rather than
  // showing a blank frame while a 1024x1536 PNG decodes.
  ImageProvider? _realisticImageProvider;
  ImageStreamListener? _realisticListener;
  Size? _imageSize;
  bool _hasError = false;

  // Which object each active pointer (finger) is currently over, keyed by
  // Flutter's PointerEvent.pointer id. Absent/null means "over empty
  // space". Tracked per-pointer so two simultaneous touches (e.g. a child
  // holding the phone with one hand while the other slides across the
  // picture) are followed independently.
  final Map<int, String?> _activeObjectIdByPointer = {};

  // Where the flashlight points, normalized to the picture. It follows the
  // finger and stays put where the finger lifts, so a child who only taps
  // still moves the light around. Starts in the middle of the picture.
  Offset _lightCenter = const Offset(0.5, 0.5);

  @override
  void initState() {
    super.initState();
    _imageProvider = FileImage(File(widget.cachedScene.backgroundPath));
    _listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      },
      onError: (exception, stackTrace) {
        // A missing/corrupt background.png must not spin forever with no
        // user-visible feedback — surface a simple error state instead.
        if (!mounted) return;
        setState(() => _hasError = true);
      },
    );
    _imageProvider.resolve(const ImageConfiguration()).addListener(_listener!);

    final realisticPath = widget.cachedScene.realisticBackgroundPath;
    if (realisticPath != null) {
      final provider = FileImage(File(realisticPath));
      _realisticImageProvider = provider;
      // Only here to keep the decoded picture alive in the image cache and
      // to swallow a load failure: a broken realistic picture must not take
      // the whole scene down, the Image below shows its own fallback.
      _realisticListener = ImageStreamListener((_, __) {}, onError: (_, __) {});
      provider.resolve(const ImageConfiguration()).addListener(_realisticListener!);
    }
  }

  @override
  void dispose() {
    _imageProvider.resolve(const ImageConfiguration()).removeListener(_listener!);
    _realisticImageProvider?.resolve(const ImageConfiguration()).removeListener(_realisticListener!);
    super.dispose();
  }

  /// The object whose rect (scaled to [size]) contains [localPosition], or
  /// null if none does. Objects are checked last-to-first so that, when
  /// rects overlap, the one later in `scene.objects` wins — the same
  /// "painted on top" priority the old Stack ordering gave it. The rects
  /// are those of whichever picture is currently shown. In the flashlight
  /// game only the things to find are there to be hit.
  SceneObject? _objectAt(Offset localPosition, Size size) {
    for (final object in context.read<SceneController>().touchableObjects.reversed) {
      final rect = Rect.fromLTWH(
        object.rect.x * size.width,
        object.rect.y * size.height,
        object.rect.width * size.width,
        object.rect.height * size.height,
      );
      if (rect.contains(localPosition)) return object;
    }
    return null;
  }

  // Shared by onPointerDown/onPointerMove: whenever this pointer's current
  // object differs from what it was last time (including from/to empty
  // space), record the new one and — only when it just entered a real
  // object — dispatch the tap. This is what makes a plain tap and a finger
  // sliding through several objects without lifting behave the same way:
  // both are just "this pointer just entered object X".
  void _handlePointerActivity(PointerEvent event, Size size) {
    if (context.read<SceneController>().flashlight != null) {
      setState(() {
        _lightCenter = Offset(
          (event.localPosition.dx / size.width).clamp(0.0, 1.0),
          (event.localPosition.dy / size.height).clamp(0.0, 1.0),
        );
      });
    }
    final object = _objectAt(event.localPosition, size);
    final previousId = _activeObjectIdByPointer[event.pointer];
    if (object?.id == previousId) return;
    _activeObjectIdByPointer[event.pointer] = object?.id;
    if (object != null) {
      context.read<SceneController>().onObjectTapped(object);
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _activeObjectIdByPointer.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('Не удалось загрузить изображение'),
          ],
        ),
      );
    }
    final imageSize = _imageSize;
    if (imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final controller = context.watch<SceneController>();
    final realisticImageProvider = _realisticImageProvider;
    final showsRealistic = controller.showsRealisticPicture && realisticImageProvider != null;
    // The realistic picture is laid out in the default picture's frame, so
    // both must share one aspect ratio (all scene art is 2:3).
    return Center(
      child: AspectRatio(
        aspectRatio: imageSize.width / imageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  layoutBuilder: (currentChild, previousChildren) =>
                      Stack(fit: StackFit.expand, children: [...previousChildren, if (currentChild != null) currentChild]),
                  child: Image(
                    key: ValueKey(showsRealistic),
                    image: showsRealistic ? realisticImageProvider : _imageProvider,
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.white,
                      child: Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
                    ),
                  ),
                ),
                if (controller.flashlight case final flashlight?)
                  Positioned.fill(
                    child: FlashlightDarkness(
                      lightCenter: _lightCenter,
                      objects: controller.touchableObjects,
                      isFound: flashlight.isFound,
                      lightsOn: flashlight.isComplete,
                    ),
                  ),
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (event) => _handlePointerActivity(event, size),
                    onPointerMove: (event) => _handlePointerActivity(event, size),
                    onPointerUp: _handlePointerEnd,
                    onPointerCancel: _handlePointerEnd,
                  ),
                ),
                // Inert geometry markers only — no gesture handling of
                // their own (IgnorePointer keeps them out of hit-testing
                // entirely, so they never shadow the Listener above).
                // Widget tests use their keys/rects to find and measure a
                // given object's tap zone.
                for (final object in controller.visibleObjects)
                  Positioned(
                    key: ValueKey('object_zone_${object.id}'),
                    left: object.rect.x * size.width,
                    top: object.rect.y * size.height,
                    width: object.rect.width * size.width,
                    height: object.rect.height * size.height,
                    child: const IgnorePointer(child: SizedBox.shrink()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
