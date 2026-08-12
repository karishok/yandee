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
  }) : _audio = audioSink {
    _mode = ExploreMode(effects: this)..activate();
  }

  final CachedScene cachedScene;
  final Duration congratsDuration;
  final AudioSink _audio;

  late SceneMode _mode;
  SceneModeType _modeType = SceneModeType.explore;
  bool _showCongrats = false;
  Timer? _congratsTimer;

  // Serializes the "spoken" effects (system phrases and Find prompts) so
  // each one waits for the previous to actually finish before starting —
  // e.g. the "correct" phrase must finish before the next "find: <object>"
  // prompt begins, or they play on top of each other. `playObjectAudio`
  // (Explore-mode taps) deliberately stays off this queue: a new tap should
  // interrupt whatever's playing immediately, not wait its turn.
  Future<void> _voiceQueue = Future.value();

  // True while a "correct" phrase is somewhere between being queued and
  // actually finishing playback. Guards against a burst of rapid correct
  // taps each queueing their own full "Молодец" — the child has already
  // moved on to the next target by the time they'd all finish, so only the
  // first one (per busy stretch) actually plays; see playSystemPhrase.
  bool _correctPending = false;

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
        : FindMode(objects: cachedScene.scene.objects, effects: this);
    _mode.activate();
    notifyListeners();
  }

  void onObjectTapped(SceneObject object) => _mode.onObjectTapped(object);

  @override
  void playObjectAudio(SceneObject object) {
    unawaited(_audio.playFile(cachedScene.audioPathFor(object)));
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
