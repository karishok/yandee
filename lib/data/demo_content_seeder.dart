import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'content_repository.dart';

/// Copies the bundled placeholder demo scene into the content cache the
/// first time the app runs with an empty cache, so there is something to
/// see and tap before any real hosted content has been published. Once
/// real content exists, `ContentRepository.refresh` naturally replaces it
/// (a real scene's higher `version` wins) — no special-casing needed.
class DemoContentSeeder {
  const DemoContentSeeder();

  static const _bundleDir = 'assets/demo_content/demo';
  static const _sceneFiles = [
    'scene.json',
    'background.png',
    'thumb.png',
    'ball.wav',
    'cat.wav',
    'tree.wav',
    'sun.wav',
  ];

  Future<void> seedIfEmpty(Directory cacheRoot) async {
    final contentCacheDir = Directory(p.join(cacheRoot.path, ContentRepository.cacheSubdirName));
    if (await contentCacheDir.exists()) {
      final hasAnyScene = await contentCacheDir.list().any((e) => e is Directory);
      if (hasAnyScene) return;
    }

    final targetDir = Directory(p.join(contentCacheDir.path, 'demo'));
    await targetDir.create(recursive: true);
    for (final fileName in _sceneFiles) {
      final data = await rootBundle.load('$_bundleDir/$fileName');
      await File(p.join(targetDir.path, fileName))
          .writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }
  }
}
