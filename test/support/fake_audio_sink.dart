import 'dart:async';

import 'package:yandee/audio/audio_sink.dart';
import 'package:yandee/domain/modes/scene_mode_effects.dart';

class FakeAudioSink implements AudioSink {
  final List<String> playedFiles = [];
  final List<SystemPhrase> playedSystemPhrases = [];
  final List<SystemPhrase> playedInterruptibleSystemPhrases = [];
  final List<(SystemPhrase, String)> playedSequences = [];
  int stopInterruptibleCalls = 0;
  bool disposeCalled = false;

  final Map<SystemPhrase, Completer<void>> _held = {};
  final Map<SystemPhrase, Completer<void>> _heldInterruptible = {};
  final Map<String, Completer<void>> _heldFiles = {};

  /// Makes playSystemPhrase(phrase) start (and record itself as played) but
  /// not resolve until [releasePhrase] is called — lets a test tell whether
  /// a caller waits for this phrase to actually finish before dispatching
  /// whatever comes next, instead of firing it immediately in parallel.
  void holdPhrase(SystemPhrase phrase) => _held[phrase] = Completer<void>();

  void releasePhrase(SystemPhrase phrase) => _held.remove(phrase)?.complete();

  void holdInterruptiblePhrase(SystemPhrase phrase) =>
      _heldInterruptible[phrase] = Completer<void>();

  void releaseInterruptiblePhrase(SystemPhrase phrase) =>
      _heldInterruptible.remove(phrase)?.complete();

  /// Makes [playExploreFile] record itself but not finish until [releaseFile] is
  /// called. This models a name that is still being spoken.
  void holdFile(String absolutePath) => _heldFiles[absolutePath] = Completer<void>();

  void releaseFile(String absolutePath) => _heldFiles.remove(absolutePath)?.complete();

  @override
  Future<void> playFile(String absolutePath) async => playedFiles.add(absolutePath);

  @override
  Future<void> playExploreFile(String absolutePath) async {
    playedFiles.add(absolutePath);
    final hold = _heldFiles[absolutePath];
    if (hold != null) await hold.future;
  }

  @override
  Future<void> playSystemPhrase(SystemPhrase phrase) async {
    playedSystemPhrases.add(phrase);
    final hold = _held[phrase];
    if (hold != null) await hold.future;
  }

  @override
  Future<void> playSystemPhraseThenFile(SystemPhrase phrase, String objectAudioPath) async =>
      playedSequences.add((phrase, objectAudioPath));

  @override
  Future<void> playInterruptibleSystemPhrase(SystemPhrase phrase) async {
    playedInterruptibleSystemPhrases.add(phrase);
    final hold = _heldInterruptible[phrase];
    if (hold != null) await hold.future;
  }

  @override
  void stopInterruptible() => stopInterruptibleCalls++;

  @override
  void dispose() => disposeCalled = true;
}
