import '../models/scene_object.dart';
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// The default [FindMode] round order: an actual shuffle. A top-level
/// function (rather than private to [FindMode]) so `SceneController` can
/// use this exact same default for its own pass-through override, instead
/// of duplicating "what counts as the real, non-test ordering".
List<SceneObject> shuffleFindOrder(List<SceneObject> objects) => List.of(objects)..shuffle();

/// The app asks for one object at a time, in a fresh random order each
/// round (a new round is a new `FindMode` instance — see
/// `SceneController.setMode`) — so a child can't just learn the fixed
/// sequence and tap along without actually finding each word. Only the
/// current target registers as a correct tap, so found objects are always
/// exactly the objects before the current target's index — a wrong tap
/// never changes state, and there is no way to skip ahead.
///
/// A scene can draw several instances of the same thing (e.g. 3 houses,
/// each its own tap zone so Explore mode can name any of them) — those
/// share one label, so they're collapsed into a single find target here:
/// tapping *any* of them counts, and the round only asks for that name
/// once, not once per instance.
class FindMode implements SceneMode {
  /// [shuffle] picks the round's order from the scene's objects; defaults
  /// to [shuffleFindOrder] (an actual shuffle). Tests — and
  /// `SceneController`, which exposes its own override for the same
  /// reason — inject an identity (or otherwise fixed) function to keep
  /// round order deterministic and assertable.
  ///
  /// Deduplication runs before the shuffle, so the round order is a
  /// permutation of the distinct labels rather than of the raw tap zones.
  FindMode({
    required List<SceneObject> objects,
    required this.effects,
    List<SceneObject> Function(List<SceneObject>) shuffle = shuffleFindOrder,
  }) : _objects = List.unmodifiable(shuffle(_dedupeByLabel(objects))) {
    assert(_objects.isNotEmpty, 'FindMode requires at least one object');
  }

  static List<SceneObject> _dedupeByLabel(List<SceneObject> objects) {
    final seenLabels = <String>{};
    return List.unmodifiable(objects.where((o) => seenLabels.add(o.label)));
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
    effects.promptFind(_objects[_targetIndex]); // first target of the round: announce "Найди:"
  }

  @override
  void onObjectTapped(SceneObject object) {
    final target = currentTarget;
    if (target == null) return; // round already complete

    if (object.label != target.label) {
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
    effects.promptFind(_objects[_targetIndex], announceIntro: false); // same round: skip the intro word
  }
}
