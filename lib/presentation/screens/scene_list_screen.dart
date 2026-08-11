import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/cached_scene.dart';
import '../../data/content_repository.dart';
import 'scene_screen.dart';

class SceneListScreen extends StatefulWidget {
  const SceneListScreen({super.key, required this.contentRepository});

  final ContentRepository contentRepository;

  @override
  State<SceneListScreen> createState() => _SceneListScreenState();
}

class _SceneListScreenState extends State<SceneListScreen> {
  List<CachedSceneSummary>? _scenes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cached = await widget.contentRepository.loadCachedIndex();
    if (!mounted) return;
    setState(() {
      _scenes = cached;
      _loading = false;
    });
    await widget.contentRepository.refresh();
    if (!mounted) return;
    final updated = await widget.contentRepository.loadCachedIndex();
    if (!mounted) return;
    setState(() => _scenes = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scenes = _scenes!;
    if (scenes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Нет подключения'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Yandee')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: scenes.map(_buildCard).toList(),
      ),
    );
  }

  Widget _buildCard(CachedSceneSummary scene) {
    return GestureDetector(
      key: ValueKey('scene_card_${scene.id}'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SceneScreen(contentRepository: widget.contentRepository, sceneId: scene.id),
      )),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Image.file(
                File(scene.thumbnailPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFE0E0E0),
                  child: Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(8), child: Text(scene.title)),
          ],
        ),
      ),
    );
  }
}
