import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/cached_scene.dart';
import '../../data/content_repository.dart';
import '../../domain/monsters/monster_color.dart';
import '../monsters/monster_art.dart';
import 'monsters_screen.dart';
import 'scene_screen.dart';
import 'settings_screen.dart';

class SceneListScreen extends StatefulWidget {
  const SceneListScreen({super.key, required this.contentRepository, this.monstersScreenBuilder});

  final ContentRepository contentRepository;

  /// Builds the screen the "Монстрики" card opens. Defaults to the real
  /// game; tests pass one that needs no audio plugin.
  final WidgetBuilder? monstersScreenBuilder;

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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final scenes = _scenes!;
    if (scenes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Yandee'), actions: [_settingsButton(context)]),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Нет подключения'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Yandee'), actions: [_settingsButton(context)]),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        // The colour game is not a scene, but it is entered the same way:
        // a card like the others, first in the grid.
        children: [_buildMonstersCard(), ...scenes.map(_buildCard)],
      ),
    );
  }

  Widget _buildMonstersCard() {
    return GestureDetector(
      key: const ValueKey('monsters_card'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: widget.monstersScreenBuilder ?? (_) => const MonstersScreen()),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              // Where a scene card shows its thumbnail, this one shows two
              // of the monsters on the game's sky-blue background.
              child: ColoredBox(
                color: const Color(0xFFD9EFFF),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(child: SvgPicture.string(MonsterLayers.of(MonsterColor.red).whole)),
                      Expanded(child: SvgPicture.string(MonsterLayers.of(MonsterColor.blue).whole)),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(padding: EdgeInsets.all(8), child: Text('Монстрики')),
          ],
        ),
      ),
    );
  }

  Widget _settingsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: IconButton(
        key: const ValueKey('settings_button'),
        icon: const Icon(Icons.settings),
        tooltip: 'Настройки',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
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
