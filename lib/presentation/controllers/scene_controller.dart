import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/audio_sink.dart';
import '../../data/cached_scene.dart';
import '../../domain/models/scene_object.dart';
import '../../domain/modes/explore_mode.dart';
import '../../domain/modes/find_mode.dart';
import '../../domain/modes/flashlight_mode.dart';
import '../../domain/modes/scene_mode.dart';
import '../../domain/modes/scene_mode_effects.dart';

enum SceneModeType { explore, find, flashlight }

/// Owns the active [SceneMode] for one open scene, and is where mode
/// switching, audio dispatch, and the Find-round congratulations timing
/// live — none of which belongs inside `SceneMode` itself, so future modes
/// get all of it for free.
class SceneController extends ChangeNotifier implements SceneModeEffects {
  SceneController({
    required this.cachedScene,
    required AudioSink audioSink,
    this.congratsDuration = const Duration(seconds: 2),
    this.findModeShuffle = shuffleFindOrder,
  }) : _audio = audioSink {
    _mode = ExploreMode(effects: this)..activate();
  }

  final CachedScene cachedScene;
  final Duration congratsDuration;
  // Passed straight through to FindMode; defaults to an actual shuffle.
  // Tests override it with an identity (or otherwise fixed) function to
  // keep Find rounds deterministic and assertable — see FindMode's own doc
  // for why this same override lives at both levels.
  final List<SceneObject> Function(List<SceneObject>) findModeShuffle;
  final AudioSink _audio;

  late SceneMode _mode;
  SceneModeType _modeType = SceneModeType.explore;
  bool _showCongrats = false;
  Timer? _congratsTimer;

  // Serializes the "spoken" effects (system phrases and Find prompts) so
  // each one waits for the previous to actually finish before starting —
  // e.g. the "correct" phrase must finish before the next "find: <object>"
  // prompt begins, or they play on top of each other. Object names
  // (`playObjectAudio`, `announceObject`) deliberately stay off this queue:
  // their own current-plus-latest policy must not wait behind Find-mode
  // instructions.
  Future<void> _voiceQueue = Future.value();

  // True while a "correct" phrase is somewhere between being queued and
  // actually finishing playback. Guards against a burst of rapid correct
  // taps each queueing their own full "Молодец" — the child has already
  // moved on to the next target by the time they'd all finish, so only the
  // first one (per busy stretch) actually plays; see playSystemPhrase.
  bool _correctPending = false;
  bool _wrongHintPlaying = false;

  // Object names (Explore taps, flashlight finds) are deliberately not a
  // FIFO queue. The name being said is always said to its end — a later
  // tap never cuts it off. Of the names asked for meanwhile only the
  // latest is kept and said next; the ones in between are skipped, so a
  // child sweeping across the picture doesn't leave a backlog droning on.
  bool _nameBeingSaid = false;
  _Name? _nextName;

  // Set once the scene is closed: a name still waiting its turn then must
  // not start up over whatever screen comes next.
  bool _disposed = false;

  // Which of the scene's pictures is on screen. Deliberately not part of
  // the mode: switching it changes how the objects look and where they sit,
  // not what the child is doing, so a Find round carries straight on.
  bool _showsRealisticPicture = false;

  SceneModeType get modeType => _modeType;
  bool get showCongrats => _showCongrats;

  /// Whether this scene has a realistic picture to switch to at all.
  bool get hasRealisticPicture => cachedScene.scene.realistic != null;

  /// Whether the realistic picture (rather than the default illustration)
  /// is the one being shown. Every scene opens on the default.
  bool get showsRealisticPicture => _showsRealisticPicture;

  /// The picture being shown.
  String get visibleBackgroundPath =>
      (_showsRealisticPicture ? cachedScene.realisticBackgroundPath : null) ?? cachedScene.backgroundPath;

  /// The scene's objects with the tap zones of the picture being shown.
  List<SceneObject> get visibleObjects =>
      cachedScene.scene.objectsFor(realistic: _showsRealisticPicture);

  /// Swaps the default illustration for the realistic picture, or back.
  /// Does nothing for a scene that has no realistic picture.
  void togglePicture() {
    if (!hasRealisticPicture) return;
    _showsRealisticPicture = !_showsRealisticPicture;
    notifyListeners();
  }

  /// Whether this scene offers the flashlight game: it does when it has
  /// something to hide in the dark, i.e. objects with an outline marked up.
  bool get hasFlashlight => cachedScene.scene.objects.any((object) => object.outline != null);

  /// The running flashlight game, or null in any other mode.
  FlashlightMode? get flashlight => _mode is FlashlightMode ? _mode as FlashlightMode : null;

  /// The objects a finger can land on right now, in the picture's tap
  /// order: all of them, except in the flashlight game, where only the
  /// things to find count — so a tree or a path whose tap zone lies over
  /// an animal's doesn't keep the finger from reaching it.
  List<SceneObject> get touchableObjects {
    final flashlight = this.flashlight;
    final objects = visibleObjects;
    return flashlight == null ? objects : objects.where(flashlight.isTarget).toList();
  }

  SceneObject? get currentFindTarget => _mode is FindMode ? (_mode as FindMode).currentTarget : null;

  void setMode(SceneModeType type) {
    if (type == _modeType) return;
    _congratsTimer?.cancel();
    _showCongrats = false;
    _modeType = type;
    _mode = switch (type) {
      SceneModeType.explore => ExploreMode(effects: this),
      SceneModeType.find => FindMode(objects: cachedScene.scene.objects, effects: this, shuffle: findModeShuffle),
      SceneModeType.flashlight => FlashlightMode(objects: cachedScene.scene.objects, effects: this),
    };
    _mode.activate();
    notifyListeners();
  }

  void onObjectTapped(SceneObject object) {
    final flashlight = this.flashlight;
    final foundBefore = flashlight?.foundCount;
    _mode.onObjectTapped(object);
    // A newly lit object changes what the darkness looks like.
    if (flashlight != null && flashlight.foundCount != foundBefore) notifyListeners();
  }

  @override
  void playObjectAudio(SceneObject object) => unawaited(_sayName(object));

  /// Asks for a name to be said (see [_nameBeingSaid] for when it is). The
  /// future completes once it has been said to its end — or right away if
  /// a later name takes its place before its turn comes.
  ///
  /// An object with a sound of its own (an animal's voice) makes it right
  /// after its name — unless another name was asked for while the name was
  /// being said: the child has moved on, so that name comes next instead.
  Future<void> _sayName(SceneObject object) {
    final done = Completer<void>();
    final name = (path: cachedScene.audioPathFor(object), soundPath: cachedScene.soundPathFor(object), done: done);
    if (_nameBeingSaid) {
      _nextName?.done.complete(); // overtaken: it will not be said
      _nextName = name;
    } else {
      _nameBeingSaid = true;
      unawaited(_sayNames(name));
    }
    return done.future;
  }

  Future<void> _sayNames(_Name first) async {
    for (var name = first; ;) {
      await _playToEnd(name.path);
      final soundPath = name.soundPath;
      if (soundPath != null && _nextName == null) await _playToEnd(soundPath);
      name.done.complete();

      final next = _nextName;
      _nextName = null;
      if (next == null) {
        _nameBeingSaid = false;
        return;
      }
      name = next;
    }
  }

  Future<void> _playToEnd(String path) async {
    try {
      if (!_disposed) await _audio.playFileToEnd(path);
    } catch (_) {
      // Audio failures must not affect touch interaction. The concrete
      // sink logs its own errors; this protects alternate implementations.
    }
  }

  @override
  void promptFind(SceneObject target, {bool announceIntro = true}) {
    _voiceQueue = _voiceQueue.then(
      (_) => announceIntro
          ? _audio.playSystemPhraseThenFile(SystemPhrase.findIntro, cachedScene.audioPathFor(target))
          : _audio.playFile(cachedScene.audioPathFor(target)),
    );
    notifyListeners();
  }

  @override
  Future<void> announceObject(SceneObject object) => _sayName(object);

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) {
    if (phrase == SystemPhrase.wrongHint) {
      if (_wrongHintPlaying) return Future<void>.value();
      _wrongHintPlaying = true;
      // A child mistapping several times in a row fires this repeatedly,
      // faster than one "try again" take is to say. Routing it through the
      // interruptible path (instead of the serialized _voiceQueue below)
      // means each new mistap cuts off the previous hint instead of queuing
      // behind it — otherwise a 5-tap streak would leave the hint droning
      // on for many seconds after the child has moved on.
      final playback = _audio.playInterruptibleSystemPhrase(phrase);
      playback.whenComplete(() => _wrongHintPlaying = false);
      return playback;
    }

    // Any other phrase means the hint has been overtaken by events — most
    // often "Попробуй ещё раз" still playing when the child gets it right.
    // Cut it here, synchronously, rather than inside _voiceQueue: the queue
    // may be several seconds deep, and a stop that lands then isn't a stop
    // the child connects to their own correct tap.
    _audio.stopInterruptible();
    _wrongHintPlaying = false;

    if (phrase == SystemPhrase.correct) {
      if (_correctPending) {
        // Still saying (or waiting to say) an earlier "Молодец" from a
        // previous rapid tap — a second one would just repeat right on top
        // of/behind it, so drop this one instead of queueing another full
        // play. The next find prompt (or the round-complete fanfare) still
        // follows right after, unaffected — this only skips the phrase.
        return Future<void>.value();
      }
      _correctPending = true;
      final playback = _voiceQueue.then((_) => _audio.playSystemPhrase(phrase));
      _voiceQueue = playback.whenComplete(() {
        _correctPending = false;
      });
      return playback;
    }
    final playback = _voiceQueue.then((_) => _audio.playSystemPhrase(phrase));
    _voiceQueue = playback;
    return playback;
  }

  @override
  void onRoundCompleted() {
    _showCongrats = true;
    notifyListeners();
    _congratsTimer = Timer(congratsDuration, () => setMode(SceneModeType.explore));
  }

  @override
  void dispose() {
    _disposed = true;
    _congratsTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }
}

/// A name asked to be said: the recorded name, the object's own sound to
/// follow it (if it has one), and what completes once it is over.
typedef _Name = ({String path, String? soundPath, Completer<void> done});
