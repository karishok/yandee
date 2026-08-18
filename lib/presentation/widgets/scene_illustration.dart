import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/cached_scene.dart';
import '../../domain/models/scene_object.dart';
import '../controllers/scene_controller.dart';

class SceneIllustration extends StatefulWidget {
  const SceneIllustration({super.key, required this.cachedScene});

  final CachedScene cachedScene;

  @override
  State<SceneIllustration> createState() => _SceneIllustrationState();
}

class _SceneIllustrationState extends State<SceneIllustration> {
  late final ImageProvider _imageProvider;
  ImageStreamListener? _listener;
  Size? _imageSize;
  bool _hasError = false;

  // Which object each active pointer (finger) is currently over, keyed by
  // Flutter's PointerEvent.pointer id. Absent/null means "over empty
  // space". Tracked per-pointer so two simultaneous touches (e.g. a child
  // holding the phone with one hand while the other slides across the
  // picture) are followed independently.
  final Map<int, String?> _activeObjectIdByPointer = {};

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
  }

  @override
  void dispose() {
    _imageProvider.resolve(const ImageConfiguration()).removeListener(_listener!);
    super.dispose();
  }

  /// The object whose rect (scaled to [size]) contains [localPosition], or
  /// null if none does. Objects are checked last-to-first so that, when
  /// rects overlap, the one later in `scene.objects` wins — the same
  /// "painted on top" priority the old Stack ordering gave it.
  SceneObject? _objectAt(Offset localPosition, Size size) {
    for (final object in widget.cachedScene.scene.objects.reversed) {
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
    return Center(
      child: AspectRatio(
        aspectRatio: imageSize.width / imageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: _imageProvider, fit: BoxFit.fill),
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
                for (final object in widget.cachedScene.scene.objects)
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
