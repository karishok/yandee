/// Who recorded one object's sound (`<scene>/<id>_sound.wav`) and under
/// which license: one entry of docs/animal-sounds-credits.json.
class SoundCredit {
  const SoundCredit({
    required this.id,
    required this.scene,
    required this.artist,
    required this.license,
    required this.page,
  });

  final String id;
  final String scene;
  final String artist;
  final String license;
  final Uri page;

  /// The credits file is one object keyed by sound id, in the order the
  /// sounds were added.
  static List<SoundCredit> listFromJson(Map<String, dynamic> json) => [
        for (final entry in json.entries)
          SoundCredit(
            id: entry.key,
            scene: (entry.value as Map<String, dynamic>)['scene'] as String,
            artist: (entry.value as Map<String, dynamic>)['artist'] as String,
            license: (entry.value as Map<String, dynamic>)['license'] as String,
            page: Uri.parse((entry.value as Map<String, dynamic>)['page'] as String),
          ),
      ];
}
