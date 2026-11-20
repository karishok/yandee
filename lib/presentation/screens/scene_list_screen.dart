import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/cached_scene.dart';
import '../../data/content_repository.dart';
import '../monsters/monsters_thumbnail.dart';
import 'monsters_screen.dart';
import 'parental_gate_screen.dart';
import 'parents_screen.dart';
import 'scene_screen.dart';

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

  /// True while the gate (or the parents menu behind it) is open, so a second
  /// tap on the gear can't stack a second gate.
  bool _gateOpen = false;

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
            // Where a scene card shows its upright thumbnail, this one
            // shows the game screen in miniature, in the same upright
            // shape: the four starting monsters over the tray of treats.
            const Expanded(child: AspectRatio(aspectRatio: 2 / 3, child: MonstersThumbnail())),
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
        tooltip: 'Для родителей',
        onPressed: () async {
          if (_gateOpen) return;
          _gateOpen = true;
          final navigator = Navigator.of(context);
          try {
            if (!await passParentalGate(navigator)) return;
            await navigator.push(MaterialPageRoute(builder: (_) => const ParentsScreen()));
          } finally {
            _gateOpen = false;
          }
        },
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
