import '../models/scene_object.dart';

/// A pluggable game mode over the same scene and objects. New modes (e.g.
/// "fact about the object", "find in sequence") are added as new classes
/// implementing this interface — `SceneController` and the screens never
/// change to support them.
abstract class SceneMode {
  /// Called once when this mode becomes active (scene opened in this mode,
  /// or the parent switched into it). May trigger a starting side effect
  /// (e.g. Find mode announces its first target).
  void activate();

  /// Called when the child taps an object's zone.
  void onObjectTapped(SceneObject object);
}
