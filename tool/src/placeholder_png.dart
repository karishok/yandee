import 'dart:io';
import 'dart:typed_data';

class PlaceholderMarker {
  const PlaceholderMarker({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.rgb,
  });

  final double x, y, width, height;
  final List<int> rgb;
}

final Uint32List _crcTable = _buildCrcTable();

Uint32List _buildCrcTable() {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

Uint8List _chunk(String type, List<int> data) {
  final out = BytesBuilder();
  out.add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List());
  final typeAndData = [...type.codeUnits, ...data];
  out.add(typeAndData.sublist(0, type.length));
  out.add(data);
  out.add((ByteData(4)..setUint32(0, _crc32(typeAndData))).buffer.asUint8List());
  return out.toBytes();
}

/// Builds a minimal, valid, uncompressed-filter 8-bit RGB PNG: a solid
/// background with rectangular "marker" regions — enough to visually and
/// programmatically stand in for real scene art in demos and tests.
Uint8List buildPlaceholderPng({
  required int width,
  required int height,
  required List<int> backgroundRgb,
  List<PlaceholderMarker> markers = const [],
}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter type: None
    for (var x = 0; x < width; x++) {
      var rgb = backgroundRgb;
      for (final m in markers) {
        final mx0 = (m.x * width).round();
        final my0 = (m.y * height).round();
        final mx1 = mx0 + (m.width * width).round();
        final my1 = my0 + (m.height * height).round();
        if (x >= mx0 && x < mx1 && y >= my0 && y < my1) {
          rgb = m.rgb;
          break;
        }
      }
      raw.add(rgb);
    }
  }
  final compressed = ZLibEncoder(level: 6).convert(raw.toBytes());

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // color type: RGB
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final out = BytesBuilder();
  out.add(const [137, 80, 78, 71, 13, 10, 26, 10]);
  out.add(_chunk('IHDR', ihdr.buffer.asUint8List()));
  out.add(_chunk('IDAT', compressed));
  out.add(_chunk('IEND', const []));
  return out.toBytes();
}
