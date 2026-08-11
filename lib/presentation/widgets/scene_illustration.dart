import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/cached_scene.dart';
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
    return Center(
      child: AspectRatio(
        aspectRatio: imageSize.width / imageSize.height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(image: _imageProvider, fit: BoxFit.fill),
                for (final object in widget.cachedScene.scene.objects)
                  Positioned(
                    key: ValueKey('object_zone_${object.id}'),
                    left: object.rect.x * width,
                    top: object.rect.y * height,
                    width: object.rect.width * width,
                    height: object.rect.height * height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => controller.onObjectTapped(object),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
