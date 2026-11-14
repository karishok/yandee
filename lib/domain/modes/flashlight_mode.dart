import 'dart:async';

import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// The scene is dark; the child moves a flashlight over it looking for the
/// things hiding there. Each one the light reaches lights up for good and
/// says its name; lighting up the last one turns the lights on for the
/// whole scene (the round is complete).
///
/// What hides is the objects that have an outline marked up — a handful
/// per scene (the animals in the forest), not everything on the picture,
/// so there is dark to search between them. Everything else is scenery
/// here: the light shows it, and touching it does nothing.
///
/// No order and no wrong answers: the child finds things in whatever order
/// the light happens to reach them. Targets are counted by label, like in
/// Find mode — several of the same thing are one thing to find, and
/// lighting any of them lights all of them.
class FlashlightMode implements SceneMode {
  FlashlightMode({required List<SceneObject> objects, required this.effects})
      : _labels = List.unmodifiable(objects.where((o) => o.outline != null).map((o) => o.label).toSet()) {
    assert(_labels.isNotEmpty, 'FlashlightMode requires at least one object with an outline');
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

  /// Whether [object] is one of the things hiding in the dark. Goes by
  /// label, so it holds for the object on any of the scene's pictures.
  bool isTarget(SceneObject object) => _labels.contains(object.label);

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
    if (_completed || !isTarget(object)) return;
    final isNewFind = _foundLabels.add(object.label);
    if (!isNewFind || _foundLabels.length < _labels.length) {
      // A find, or an already lit object touched again: say its name, like
      // in Explore mode. The effects never cut a name off and, of several
      // asked for while one is being said, say only the latest.
      effects.playObjectAudio(object);
      return;
    }
    _completed = true;
    unawaited(_finishRound(object));
  }

  Future<void> _finishRound(SceneObject lastObject) async {
    // The last name is the latest asked for, so it is the one that follows
    // whatever is being said — and the fanfare waits for it.
    await effects.announceObject(lastObject);
    await effects.playSystemPhrase(SystemPhrase.roundComplete);
    effects.onRoundCompleted();
  }
}
