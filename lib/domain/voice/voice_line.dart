/// One recorded piece of speech: a whole short sentence, stored as its own
/// audio file. Shared by the games that speak in a recorded voice.
class VoiceClip {
  const VoiceClip(this.id, this.text);

  /// File name without the extension, e.g. `food_red_strawberry`.
  final String id;

  /// What to say when recording it.
  final String text;

  @override
  bool operator ==(Object other) => other is VoiceClip && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VoiceClip($id: $text)';
}

/// Something a game says: one or more [clips] played back to back.
class VoiceLine {
  const VoiceLine(this.clips);

  final List<VoiceClip> clips;

  String get text => clips.map((clip) => clip.text).join(' ');

  @override
  String toString() => 'VoiceLine($text)';
}
