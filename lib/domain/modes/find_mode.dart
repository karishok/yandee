import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// The app asks for one object at a time, in the scene's own list order.
/// Only the current target registers as a correct tap, so found objects
/// are always exactly the objects before the current target's index — a
/// wrong tap never changes state, and there is no way to skip ahead.
class FindMode implements SceneMode {
  FindMode({required List<SceneObject> objects, required this.effects})
      : _objects = List.unmodifiable(objects) {
    assert(_objects.isNotEmpty, 'FindMode requires at least one object');
  }

  final List<SceneObject> _objects;
  final SceneModeEffects effects;

  int _targetIndex = 0;
  int _foundCount = 0;

  /// The object currently being searched for, or null once every object
  /// in the scene has been found.
  SceneObject? get currentTarget =>
      _foundCount == _objects.length ? null : _objects[_targetIndex];

  @override
  void activate() {
    _targetIndex = 0;
    _foundCount = 0;
    effects.promptFind(_objects[_targetIndex]);
  }

  @override
  void onObjectTapped(SceneObject object) {
    final target = currentTarget;
    if (target == null) return; // round already complete

    if (object != target) {
      effects.playSystemPhrase(SystemPhrase.wrongHint);
      return;
    }

    _foundCount++;
    effects.playSystemPhrase(SystemPhrase.correct);

    if (_foundCount == _objects.length) {
      effects.playSystemPhrase(SystemPhrase.roundComplete);
      effects.onRoundCompleted();
      return;
    }

    _targetIndex++;
    effects.promptFind(_objects[_targetIndex]);
  }
}
