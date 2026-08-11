import 'dart:typed_data';

/// Builds a minimal, valid, silent 16-bit mono PCM WAV — a placeholder
/// stand-in for a recorded name/phrase, wherever real audio isn't
/// available yet.
Uint8List buildSilentWav({double seconds = 0.4, int sampleRate = 8000}) {
  final numSamples = (sampleRate * seconds).round();
  final dataSize = numSamples * 2;
  final b = BytesBuilder();

  void writeString(String s) => b.add(s.codeUnits);
  void writeUint32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void writeUint16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(sampleRate);
  writeUint32(sampleRate * 2);
  writeUint16(2);
  writeUint16(16);
  writeString('data');
  writeUint32(dataSize);
  b.add(List<int>.filled(dataSize, 0));
  return b.toBytes();
}
