import 'dart:io';

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
    final flashlight = controller.flashlight;
    return Scaffold(
      // Night all around the picture too, while the flashlight game is on.
      backgroundColor: flashlight != null && !flashlight.isComplete ? const Color(0xFF060A1C) : null,
      body: SafeArea(
        child: Stack(
          children: [
            // The top chrome (see below) is at most two rows tall — back
            // button/mode switch, plus the find banner underneath when it's
            // showing — up to ~120px including its own 16px offset from the
            // top edge; insetting the illustration by 152px on top and a
            // smaller 24px on the bottom/sides guarantees its rendered
            // area — and therefore every tap zone inside it — never sits
            // under any chrome, regardless of aspect ratio, mode, or where
            // in the scene an object's rect happens to be authored. Nothing
            // sits at the bottom any more (the back button now lives in the
            // top bar with everything else), so that edge only needs
            // breathing room, not a matching chrome-sized inset.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 152, bottom: 24, left: 16, right: 16),
                child: SceneIllustration(cachedScene: cachedScene),
              ),
            ),
            // Back button and mode switch share one row (left/right); the
            // find banner sits in a row of its own underneath, right-aligned
            // so it reads as belonging to the mode switch above it — the
            // space below the switch has nothing else in it. Putting it in
            // its own row (rather than squeezed between the two other
            // controls) is also what guarantees it can never overlap either
            // of them, whatever its content's width turns out to be.
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const _BackButton(),
                      const Spacer(),
                      _ModeSwitch(modeType: controller.modeType, onChanged: controller.setMode),
                    ],
                  ),
                  if (showBanner || controller.hasRealisticPicture || controller.hasFlashlight) ...[
                    const SizedBox(height: 10),
                    // The second row: the picture toggle on the left (only
                    // for scenes that have a realistic picture), the find
                    // banner on the right. The toggle lives down here rather
                    // than next to the back button because the first row is
                    // already full on a narrow phone.
                    Row(
                      children: [
                        if (controller.hasRealisticPicture) ...[
                          _PictureToggle(
                            // Shows the picture a tap switches *to*.
                            previewPath: controller.showsRealisticPicture
                                ? cachedScene.backgroundPath
                                : cachedScene.realisticBackgroundPath!,
                            showsRealisticPicture: controller.showsRealisticPicture,
                            onPressed: controller.togglePicture,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (controller.hasFlashlight) ...[
                          _FlashlightButton(
                            isOn: flashlight != null,
                            onPressed: () => controller.setMode(
                              flashlight != null ? SceneModeType.explore : SceneModeType.flashlight,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: showBanner
                                ? _FindBanner(target: controller.currentFindTarget)
                                : flashlight != null
                                    ? _FlashlightStars(found: flashlight.foundCount, total: flashlight.totalCount)
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ],
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

/// Turns the flashlight game on and off. Wordless, like the picture
/// toggle next to it: a flashlight icon on a dark (night) circle.
class _FlashlightButton extends StatelessWidget {
  const _FlashlightButton({required this.isOn, required this.onPressed});

  final bool isOn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isOn ? 'Выключить фонарик' : 'Фонарик',
      child: Material(
        key: const ValueKey('flashlight_button'),
        color: isOn ? Colors.amber : const Color(0xFF1B2140),
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              isOn ? Icons.flashlight_off : Icons.flashlight_on,
              color: isOn ? const Color(0xFF1B2140) : Colors.amber,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

/// One star per thing to find in the dark; each lights up as it's found.
class _FlashlightStars extends StatelessWidget {
  const _FlashlightStars({required this.found, required this.total});

  final int found;
  final int total;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Container(
        key: const ValueKey('flashlight_stars'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2140),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedScale(
                scale: i < found ? 1.15 : 1,
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  i < found ? Icons.star_rounded : Icons.star_outline_rounded,
                  key: ValueKey('flashlight_star_${i < found ? 'on' : 'off'}_$i'),
                  color: i < found ? Colors.amber : Colors.white38,
                  size: 24,
                ),
              ),
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

/// Swaps the scene's default illustration for its realistic picture and
/// back. Wordless on purpose — it is a small round preview of the picture a
/// tap switches to, so a child who can't read still sees what it does.
class _PictureToggle extends StatelessWidget {
  const _PictureToggle({
    required this.previewPath,
    required this.showsRealisticPicture,
    required this.onPressed,
  });

  final String previewPath;
  final bool showsRealisticPicture;
  final VoidCallback onPressed;

  static const double _size = 52;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: showsRealisticPicture ? 'Показать рисунок' : 'Показать как в жизни',
      child: Material(
        key: const ValueKey('picture_toggle'),
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              child: SizedBox(
                width: _size - 6,
                height: _size - 6,
                child: Image(
                  // Keyed so the preview swaps cleanly instead of briefly
                  // showing the previous picture's frame.
                  key: ValueKey(previewPath),
                  image: FileImage(File(previewPath)),
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => Icon(Icons.image, color: colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
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
              children: [Icon(Icons.search, size: 20), SizedBox(width: 6), Text('Найти')],
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
