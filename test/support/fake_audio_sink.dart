import 'package:yandee/audio/audio_sink.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

class FakeAudioSink implements AudioSink {
  final List<String> playedFiles = [];
  final List<SystemPhrase> playedSystemPhrases = [];
  final List<(SystemPhrase, String)> playedSequences = [];
  bool disposeCalled = false;

  @override
  Future<void> playFile(String absolutePath) async => playedFiles.add(absolutePath);

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) async => playedSystemPhrases.add(phrase);

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async =>
      playedSequences.add((phrase, objectAudioPath));

  @override
  void dispose() => disposeCalled = true;
}
