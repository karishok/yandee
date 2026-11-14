import 'dart:async';

import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// The scene is dark; the child moves a flashlight over it and every object
/// the light reaches lights up for good and says its name. Lighting up the
/// last one turns the lights on for the whole scene (the round is complete).
///
/// No order and no wrong answers: the child finds things in whatever order
/// the light happens to reach them. Objects are counted by label, like in
/// Find mode — a scene that draws several trees has one "Дерево" to find,
/// and lighting any of them lights all of them.
class FlashlightMode implements SceneMode {
  FlashlightMode({required List<SceneObject> objects, required this.effects})
      : _labels = List.unmodifiable(objects.map((o) => o.label).toSet()) {
    assert(_labels.isNotEmpty, 'FlashlightMode requires at least one object');
  }

  final SceneModeEffects effects;
  final List<String> _labels;
  final Set<String> _foundLabels = {};
  bool _completed = false;

  /// How many distinct things there are to find in this scene.
  int get totalCount => _labels.length;

  /// How many of them the light has reached so far.
  int get foundCount => _foundLabels.length;

  /// Whether every object has been found (the lights are on).
  bool get isComplete => _completed;

  /// Whether [object] has already been lit — by itself or by another
  /// instance with the same label.
  bool isFound(SceneObject object) => _foundLabels.contains(object.label);

  @override
  void activate() {
    _foundLabels.clear();
    _completed = false;
  }

  @override
  void onObjectTapped(SceneObject object) {
    if (_completed) return;
    if (!_foundLabels.add(object.label)) {
      // Already lit: just say its name again, like in Explore mode.
      effects.playObjectAudio(object);
      return;
    }
    if (_foundLabels.length < _labels.length) {
      effects.playObjectAudio(object);
      return;
    }
    _completed = true;
    unawaited(_finishRound(object));
  }

  Future<void> _finishRound(SceneObject lastObject) async {
    await effects.announceObject(lastObject);
    await effects.playSystemPhrase(SystemPhrase.roundComplete);
    effects.onRoundCompleted();
  }
}
