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
  void promptFind(SceneObject target) {
    unawaited(_audio.playSystemPhraseThenFile(SystemPhrase.findIntro, cachedScene.audioPathFor(target)));
    notifyListeners();
  }

  @override
  void playSystemPhrase(SystemPhrase phrase) {
    unawaited(_audio.playSystemPhrase(phrase));
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
