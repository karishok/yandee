/// One row of the hosting root's index manifest (`index.json`) — enough to
/// render a scene-list card and decide whether a newer version needs
/// downloading, without fetching the full `scene.json`.
class SceneManifestEntry {
  const SceneManifestEntry({
    required this.id,
    required this.version,
    required this.title,
    required this.thumbnail,
  });

  final String id;
  final int version;
  final String title;

  /// Path to the thumbnail image, relative to the hosting root (already
  /// includes the scene id, e.g. `"city/thumb.png"` — unlike `Scene`'s own
  /// fields, which are relative to that scene's own folder).
  final String thumbnail;

  factory SceneManifestEntry.fromJson(Map<String, dynamic> json) {
    return SceneManifestEntry(
      id: json['id'] as String,
      version: json['version'] as int,
      title: json['title'] as String,
      thumbnail: json['thumbnail'] as String,
    );
  }
}
