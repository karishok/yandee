import 'dart:io';
import 'dart:typed_data';

/// A decoded mono 16-bit PCM WAV: samples normalized to [-1.0, 1.0].
class WavAudio {
  const WavAudio({required this.sampleRate, required this.samples});
  final int sampleRate;
  final Float64List samples;
}

String _fourCC(Uint8List bytes, int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

/// Reads a 16-bit PCM WAV file, downmixing to mono if it isn't already.
/// Tolerant of extra chunks (e.g. `LIST`) between `fmt ` and `data`, which
/// some recorders/editors insert.
WavAudio readMonoWav16(File file) {
  final bytes = file.readAsBytesSync();
  if (bytes.length < 12 || _fourCC(bytes, 0) != 'RIFF' || _fourCC(bytes, 8) != 'WAVE') {
    throw FormatException('Not a RIFF/WAVE file: ${file.path}');
  }
  final data = ByteData.sublistView(bytes);

  int? sampleRate;
  int? bitsPerSample;
  int? numChannels;
  int? dataOffset;
  int? dataLength;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final chunkId = _fourCC(bytes, offset);
    final chunkSize = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;
    if (chunkId == 'fmt ') {
      numChannels = data.getUint16(chunkStart + 2, Endian.little);
      sampleRate = data.getUint32(chunkStart + 4, Endian.little);
      bitsPerSample = data.getUint16(chunkStart + 14, Endian.little);
    } else if (chunkId == 'data') {
      dataOffset = chunkStart;
      dataLength = chunkSize;
    }
    // Chunks are word-aligned: an odd-sized chunk has one byte of padding
    // after it that isn't reflected in chunkSize.
    offset = chunkStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
  }

  if (sampleRate == null || bitsPerSample == null || numChannels == null || dataOffset == null || dataLength == null) {
    throw FormatException('Missing fmt/data chunk: ${file.path}');
  }
  if (bitsPerSample != 16) {
    throw FormatException('Only 16-bit PCM is supported, got $bitsPerSample-bit: ${file.path}');
  }

  final frameBytes = 2 * numChannels;
  final frameCount = dataLength ~/ frameBytes;
  final samples = Float64List(frameCount);
  for (var i = 0; i < frameCount; i++) {
    var sum = 0;
    for (var ch = 0; ch < numChannels; ch++) {
      sum += data.getInt16(dataOffset + i * frameBytes + ch * 2, Endian.little);
    }
    samples[i] = (sum / numChannels) / 32768.0;
  }
  return WavAudio(sampleRate: sampleRate, samples: samples);
}

/// Writes [audio] as a 16-bit mono PCM WAV, clipping any sample that
/// overshoots [-1.0, 1.0].
void writeMonoWav16(File file, WavAudio audio) {
  final n = audio.samples.length;
  final dataSize = n * 2;
  final out = BytesBuilder();

  void writeString(String s) => out.add(s.codeUnits);
  void writeUint32(int v) => out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void writeUint16(int v) => out.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());

  writeString('RIFF');
  writeUint32(36 + dataSize);
  writeString('WAVE');
  writeString('fmt ');
  writeUint32(16);
  writeUint16(1); // PCM
  writeUint16(1); // mono
  writeUint32(audio.sampleRate);
  writeUint32(audio.sampleRate * 2);
  writeUint16(2);
  writeUint16(16);
  writeString('data');
  writeUint32(dataSize);

  final sampleBytes = ByteData(2);
  for (var i = 0; i < n; i++) {
    var v = (audio.samples[i] * 32768.0).round();
    if (v > 32767) v = 32767;
    if (v < -32768) v = -32768;
    sampleBytes.setInt16(0, v, Endian.little);
    out.add(sampleBytes.buffer.asUint8List(0, 2));
  }

  file.writeAsBytesSync(out.toBytes());
}
