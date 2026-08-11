import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../audio/audio_player_service.dart';
import '../../audio/audio_sink.dart';
import '../../data/cached_scene.dart';
import '../../data/content_repository.dart';
import '../../domain/models/scene_object.dart';
import '../controllers/scene_controller.dart';
import '../widgets/scene_illustration.dart';

class SceneScreen extends StatefulWidget {
  const SceneScreen({
    super.key,
    required this.contentRepository,
    required this.sceneId,
    AudioSink Function()? audioSinkFactory,
  }) : audioSinkFactory = audioSinkFactory ?? AudioPlayerService.new;

  final ContentRepository contentRepository;
  final String sceneId;
  final AudioSink Function() audioSinkFactory;

  @override
  State<SceneScreen> createState() => _SceneScreenState();
}

class _SceneScreenState extends State<SceneScreen> {
  CachedScene? _cachedScene;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    widget.contentRepository.loadScene(widget.sceneId).then((scene) {
      if (!mounted) return;
      if (scene == null) {
        setState(() => _loadFailed = true);
        return;
      }
      setState(() => _cachedScene = scene);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadFailed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Не удалось открыть сцену'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      );
    }
    final cachedScene = _cachedScene;
    if (cachedScene == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChangeNotifierProvider(
      create: (_) => SceneController(cachedScene: cachedScene, audioSink: widget.audioSinkFactory()),
      child: _SceneView(cachedScene: cachedScene),
    );
  }
}

class _SceneView extends StatelessWidget {
  const _SceneView({required this.cachedScene});

  final CachedScene cachedScene;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SceneController>();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Chrome (mode switch, find banner at the top; the back button
            // at the bottom) can each be up to ~72px tall (their 16px
            // Positioned offset + control height); insetting the
            // illustration by 80px on both edges guarantees its rendered
            // area — and therefore every tap zone inside it — never sits
            // under any chrome, regardless of aspect ratio, orientation, or
            // where in the scene an object's rect happens to be authored.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 80),
                child: SceneIllustration(cachedScene: cachedScene),
              ),
            ),
            if (controller.modeType == SceneModeType.find && !controller.showCongrats)
              Positioned(
                top: 16,
                left: 16,
                right: 88,
                child: _FindBanner(target: controller.currentFindTarget),
              ),
            Positioned(
              top: 16,
              right: 16,
              child: _ModeSwitch(modeType: controller.modeType, onChanged: controller.setMode),
            ),
            const Positioned(bottom: 16, left: 16, child: _BackButton()),
            if (controller.showCongrats) const Positioned.fill(child: _CongratsOverlay()),
          ],
        ),
      ),
    );
  }
}

class _FindBanner extends StatelessWidget {
  const _FindBanner({required this.target});

  final SceneObject? target;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    if (target == null) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('find_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('Найди: ${target.label}', style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.modeType, required this.onChanged});

  final SceneModeType modeType;
  final ValueChanged<SceneModeType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('mode_switch'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ToggleButtons(
        isSelected: [modeType == SceneModeType.explore, modeType == SceneModeType.find],
        onPressed: (index) => onChanged(index == 0 ? SceneModeType.explore : SceneModeType.find),
        children: const [
          Padding(padding: EdgeInsets.all(8), child: Text('Исследовать')),
          Padding(padding: EdgeInsets.all(8), child: Text('Найди')),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: IconButton(
        key: const ValueKey('scene_back_button'),
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Назад',
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _CongratsOverlay extends StatelessWidget {
  const _CongratsOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: const ValueKey('congrats_overlay'),
        color: Colors.black.withValues(alpha: 0.15),
        child: const Center(child: Icon(Icons.star, size: 96, color: Colors.amber)),
      ),
    );
  }
}
