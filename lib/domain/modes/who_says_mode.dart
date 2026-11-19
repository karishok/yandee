import 'dart:async';

import '../models/scene_object.dart';
import 'find_mode.dart' show shuffleFindOrder;
import 'scene_mode.dart';
import 'scene_mode_effects.dart';

/// «Кто это?» — Find mode by ear. The child hears the sound a thing makes
/// (a cow's moo, a tractor's rattle) and taps whoever or whatever makes it;
/// a right answer is praised and the next sound follows straight away.
///
/// Only objects with a sound of their own take part, one per label (like
/// in Find mode, several cows are one thing to find and tapping any of
/// them counts). A round is a few of them — a toddler's attention runs out
/// long before a farm's ten sounds do — picked afresh for every round (a
/// new round is a new instance, see `SceneController.setMode`).
class WhoSaysMode implements SceneMode {
  /// [shuffle] orders the sound objects before the round takes the first
  /// [roundSize] of them; tests pass a fixed order.
  WhoSaysMode({
    required List<SceneObject> objects,
    required this.effects,
    List<SceneObject> Function(List<SceneObject>) shuffle = shuffleFindOrder,
  }) : _targets = List.unmodifiable(shuffle(soundObjects(objects)).take(roundSize)) {
    assert(_targets.isNotEmpty, 'WhoSaysMode requires at least one object with a sound');
  }

  /// How many distinct sounds a scene needs for this game to be offered:
  /// with fewer, guessing is too easy for it to be a game.
  static const int minSounds = 5;

  /// How many sounds one round asks for.
  static const int roundSize = 5;

  /// The objects with a sound of their own, one per label, in scene order.
  static List<SceneObject> soundObjects(List<SceneObject> objects) {
    final seenLabels = <String>{};
    return [
      for (final object in objects)
        if (object.sound != null && seenLabels.add(object.label)) object,
    ];
  }

  /// Whether a scene with these objects offers the game.
  static bool isAvailableIn(List<SceneObject> objects) => soundObjects(objects).length >= minSounds;

  final SceneModeEffects effects;
  final List<SceneObject> _targets;

  int _foundCount = 0;
  bool _waitingForCorrectFeedback = false;

  /// How many sounds this round asks for.
  int get roundLength => _targets.length;

  /// Whether every sound of the round has been found.
  bool get isComplete => _foundCount == _targets.length;

  /// The object whose sound is to be found, or null once the round is over.
  SceneObject? get currentTarget => isComplete ? null : _targets[_foundCount];

  @override
  void activate() {
    _foundCount = 0;
    _waitingForCorrectFeedback = false;
    effects.promptSound(_targets.first); // first of the round: with "Где"
  }

  @override
  void onObjectTapped(SceneObject object) {
    if (_waitingForCorrectFeedback) return;
    final target = currentTarget;
    if (target == null) return;

    if (object.label != target.label) {
      effects.hintThenRepeatSound(target);
      return;
    }
    _waitingForCorrectFeedback = true;
    unawaited(_advanceAfterCorrectAnswer());
  }

  /// Plays the current sound once more (the repeat button). Does nothing
  /// while a right answer is being praised or once the round is over.
  void repeatSound() {
    if (_waitingForCorrectFeedback) return;
    final target = currentTarget;
    if (target == null) return;
    effects.promptSound(target, announceIntro: false);
  }

  Future<void> _advanceAfterCorrectAnswer() async {
    // Praise only, no name: a name between the sounds slows the game down.
    await effects.playSystemPhrase(SystemPhrase.correct);
    _foundCount++;

    if (isComplete) {
      await effects.playSystemPhrase(SystemPhrase.roundComplete);
      effects.onRoundCompleted();
    } else {
      effects.promptSound(_targets[_foundCount], announceIntro: false);
    }
    _waitingForCorrectFeedback = false;
  }
}
