import 'dart:async';

import 'package:yandee/audio/shapes_voice.dart';
import 'package:yandee/domain/voice/voice_line.dart';

/// Records what the "Фигурки" screen asked to hear, playing nothing.
class FakeShapesVoice implements ShapesVoice {
  /// The text of every line said, in order.
  final List<String> said = [];
  final List<ShapesSfx> sfx = [];
  int stopCalls = 0;
  bool disposeCalled = false;

  Completer<void>? _held;

  /// Makes the next [say] not finish until [finishSpeaking] is called.
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
  void playSfx(ShapesSfx sfx) => this.sfx.add(sfx);

  @override
  void stop() => stopCalls++;

  @override
  void dispose() => disposeCalled = true;
}
