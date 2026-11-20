import 'dart:async';

import 'package:yandee/audio/monster_voice.dart';
import 'package:yandee/domain/monsters/monster_phrases.dart';

/// Records what the "Монстрики" screen asked to hear, playing nothing.
class FakeMonsterVoice implements MonsterVoice {
  /// The text of every line said, in order.
  final List<String> said = [];
  final List<MonsterSfx> sfx = [];
  int stopCalls = 0;
  bool disposeCalled = false;

  Completer<void>? _held;

  /// Makes the next [say] not finish until [finishSpeaking] is called —
  /// models a line that is still being spoken.
  void holdSpeech() => _held = Completer<void>();

  void finishSpeaking() {
    _held?.complete();
    _held = null;
  }

  @override
  Future<void> say(VoiceLine line) async {
    said.add(line.text);
    final held = _held;
    if (held != null) await held.future;
  }

  @override
  void playSfx(MonsterSfx sfx) => this.sfx.add(sfx);

  @override
  void stop() => stopCalls++;

  @override
  void dispose() => disposeCalled = true;
}
