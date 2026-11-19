import 'dart:developer' as developer;

import 'package:audioplayers/audioplayers.dart';

/// «Пора отдыхать!», recorded by a person (never synthesised) with
/// `dart run tool/slice_voiceover.dart parents <take>`.
const restPhraseAsset = 'audio/system/rest_time.wav';

/// Says the rest-time phrase once, on a player of its own. Until the phrase
/// is recorded the file isn't there; that, like any playback failure, is
/// logged and swallowed — the rest screen then simply stays quiet.
Future<void> playRestPhrase() async {
  final player = AudioPlayer();
  try {
    // `ignore()`: if `play` throws, `done` is never awaited, and disposing
    // the player would otherwise end it with an uncaught "No element".
    final done = player.onPlayerComplete.first..ignore();
    await player.play(AssetSource(restPhraseAsset));
    await done.timeout(const Duration(seconds: 6));
  } catch (error, stackTrace) {
    developer.log('Rest phrase did not play', name: 'RestPhrase', error: error, stackTrace: stackTrace);
  } finally {
    try {
      await player.dispose();
    } catch (_) {}
  }
}
