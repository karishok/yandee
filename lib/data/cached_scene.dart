import 'package:path/path.dart' as p;
import '../domain/models/scene.dart';
import '../domain/models/scene_object.dart';

/// A summary row for `SceneListScreen` — everything needed to render a
/// card without parsing the full `scene.json`.
class CachedSceneSummary {
  const CachedSceneSummary({required this.id, required this.title, required this.thumbnailPath});

  final String id;
  final String title;
  final String thumbnailPath;
}

/// A fully-cached scene plus the local directory its files live in, so
/// callers never need to know the cache's on-disk layout.
class CachedScene {
  const CachedScene({required this.scene, required this.directoryPath});

  final Scene scene;
  final String directoryPath;

  String get backgroundPath => p.join(directoryPath, scene.background);

  String audioPathFor(SceneObject object) => p.join(directoryPath, object.audio);
}
