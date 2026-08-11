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
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Назад'),
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
    final showBanner = controller.modeType == SceneModeType.find && !controller.showCongrats;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // The top bar (back button, find banner, mode switch — see
            // below) is up to ~64px tall plus its own 16px offset from the
            // top edge; insetting the illustration by 96px on top and a
            // smaller 24px on the bottom/sides guarantees its rendered
            // area — and therefore every tap zone inside it — never sits
            // under any chrome, regardless of aspect ratio or where in the
            // scene an object's rect happens to be authored. Nothing sits
            // at the bottom any more (the back button now lives in the top
            // bar with everything else), so that edge only needs breathing
            // room, not a matching chrome-sized inset.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 96, bottom: 24, left: 16, right: 16),
                child: SceneIllustration(cachedScene: cachedScene),
              ),
            ),
            // A single top row — rather than independently-positioned
            // corners — is what actually guarantees the back button, find
            // banner, and mode switch can never overlap each other: the
            // banner's Expanded region is only ever as wide as the space
            // left over between the two fixed-size controls on either side
            // of it, whatever their rendered widths turn out to be.
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const _BackButton(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: showBanner
                        ? Center(child: _FindBanner(target: controller.currentFindTarget))
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 12),
                  _ModeSwitch(modeType: controller.modeType, onChanged: controller.setMode),
                ],
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('find_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, color: colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              target.label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.modeType, required this.onChanged});

  final SceneModeType modeType;
  final ValueChanged<SceneModeType> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('mode_switch'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ToggleButtons(
        isSelected: [modeType == SceneModeType.explore, modeType == SceneModeType.find],
        onPressed: (index) => onChanged(index == 0 ? SceneModeType.explore : SceneModeType.find),
        borderWidth: 0,
        borderRadius: BorderRadius.circular(20),
        selectedColor: Colors.white,
        color: colorScheme.primary,
        fillColor: colorScheme.primary,
        splashColor: colorScheme.primary.withValues(alpha: 0.2),
        constraints: const BoxConstraints(minHeight: 44, minWidth: 56),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.explore, size: 20), SizedBox(width: 6), Text('Исследовать')],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Icon(Icons.search, size: 20), SizedBox(width: 6), Text('Найди')],
            ),
          ),
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
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      child: IconButton(
        key: const ValueKey('scene_back_button'),
        icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
        iconSize: 26,
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
