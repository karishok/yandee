import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../audio/audio_sink.dart';
import '../../data/cached_scene.dart';
import '../../domain/models/scene_object.dart';
import '../../domain/modes/explore_mode.dart';
import '../../domain/modes/find_mode.dart';
import '../../domain/modes/scene_mode.dart';
import '../../domain/modes/scene_mode_effects.dart';

enum SceneModeType { explore, find }

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
  // prompt begins, or they play on top of each other. `playObjectAudio`
  // (Explore-mode taps) deliberately stays off this queue: its separate
  // current-plus-latest policy must not wait behind Find-mode instructions.
  Future<void> _voiceQueue = Future.value();

  // True while a "correct" phrase is somewhere between being queued and
  // actually finishing playback. Guards against a burst of rapid correct
  // taps each queueing their own full "Молодец" — the child has already
  // moved on to the next target by the time they'd all finish, so only the
  // first one (per busy stretch) actually plays; see playSystemPhrase.
  bool _correctPending = false;

  // Explore-mode names are deliberately not a FIFO queue. While one name is
  // being spoken, retain only the latest object the child reaches; once the
  // current name finishes, speak that one object and discard everything in
  // between.
  bool _objectAudioPlaying = false;
  String? _pendingObjectAudioPath;

  SceneModeType get modeType => _modeType;
  bool get showCongrats => _showCongrats;

  SceneObject? get currentFindTarget => _mode is FindMode ? (_mode as FindMode).currentTarget : null;

  void setMode(SceneModeType type) {
    if (type == _modeType) return;
    _congratsTimer?.cancel();
    _showCongrats = false;
    _modeType = type;
    _mode = type == SceneModeType.explore
        ? ExploreMode(effects: this)
        : FindMode(objects: cachedScene.scene.objects, effects: this, shuffle: findModeShuffle);
    _mode.activate();
    notifyListeners();
  }

  void onObjectTapped(SceneObject object) => _mode.onObjectTapped(object);

  @override
  void playObjectAudio(SceneObject object) {
    final path = cachedScene.audioPathFor(object);
    if (_objectAudioPlaying) {
      _pendingObjectAudioPath = path;
      return;
    }
    _playObjectAudio(path);
  }

  void _playObjectAudio(String path) {
    _objectAudioPlaying = true;
    unawaited(_finishObjectAudio(path));
  }

  Future<void> _finishObjectAudio(String path) async {
    try {
      await _audio.playExploreFile(path);
    } catch (_) {
      // Audio failures must not affect touch interaction. The concrete sink
      // logs its own errors; this protects alternate implementations too.
    }

    final nextPath = _pendingObjectAudioPath;
    _pendingObjectAudioPath = null;
    if (nextPath == null) {
      _objectAudioPlaying = false;
      return;
    }
    _playObjectAudio(nextPath);
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
  void playSystemPhrase(SystemPhrase phrase) {
    if (phrase == SystemPhrase.wrongHint) {
      // A child mistapping several times in a row fires this repeatedly,
      // faster than one "try again" take is to say. Routing it through the
      // interruptible path (instead of the serialized _voiceQueue below)
      // means each new mistap cuts off the previous hint instead of queuing
      // behind it — otherwise a 5-tap streak would leave the hint droning
      // on for many seconds after the child has moved on.
      unawaited(_audio.playInterruptibleSystemPhrase(phrase));
      return;
    }

    // Any other phrase means the hint has been overtaken by events — most
    // often "Попробуй ещё раз" still playing when the child gets it right.
    // Cut it here, synchronously, rather than inside _voiceQueue: the queue
    // may be several seconds deep, and a stop that lands then isn't a stop
    // the child connects to their own correct tap.
    _audio.stopInterruptible();

    if (phrase == SystemPhrase.correct) {
      if (_correctPending) {
        // Still saying (or waiting to say) an earlier "Молодец" from a
        // previous rapid tap — a second one would just repeat right on top
        // of/behind it, so drop this one instead of queueing another full
        // play. The next find prompt (or the round-complete fanfare) still
        // follows right after, unaffected — this only skips the phrase.
        return;
      }
      _correctPending = true;
      _voiceQueue = _voiceQueue.then((_) => _audio.playSystemPhrase(phrase)).whenComplete(() {
        _correctPending = false;
      });
      return;
    }
    _voiceQueue = _voiceQueue.then((_) => _audio.playSystemPhrase(phrase));
  }

  @override
  void onRoundCompleted() {
    _showCongrats = true;
    notifyListeners();
    _congratsTimer = Timer(congratsDuration, () => setMode(SceneModeType.explore));
  }

  @override
  void dispose() {
    _congratsTimer?.cancel();
    _audio.dispose();
    super.dispose();
  }
}
