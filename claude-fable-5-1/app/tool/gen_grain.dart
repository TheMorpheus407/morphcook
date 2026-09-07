// Generates assets/textures/grain.png — a tiling paper-grain tile.
// Run from app/: dart run tool/gen_grain.dart
import 'dart:io';
import 'dart:typed_data';

void main() {
  const size = 192;
  final rows = <int>[];
  var seed = 0x2F6E2B1;
  int next() {
    seed = (seed * 1103515245 + 12345) & 0x7fffffff;
    return seed;
  }

  for (var y = 0; y < size; y++) {
    rows.add(0); // filter: none
    for (var x = 0; x < size; x++) {
      final r = next();
      final v = (r >> 8) & 0xff;
      // Mostly transparent; a sparse scatter of darker fibre specks and
      // a few lighter ones, so the paper reads as paper, not as dirt.
      int gray;
      int alpha;
      if (v < 18) {
        gray = 40 + ((r >> 16) & 0x1f);
        alpha = 14 + ((r >> 20) & 0x0f);
      } else if (v < 30) {
        gray = 255;
        alpha = 10 + ((r >> 20) & 0x07);
      } else {
        gray = 90;
        alpha = ((r >> 12) & 0x3) == 0 ? 3 : 0;
      }
      rows..add(gray)..add(alpha);
    }
  }
  final raw = Uint8List.fromList(rows);
  final idat = ZLibEncoder(level: 9).convert(raw);

  final out = BytesBuilder();
  out.add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  final ihdr = BytesBuilder()
    ..add(_u32(size))
    ..add(_u32(size))
    ..add([8, 4, 0, 0, 0]); // 8-bit, grayscale+alpha
  out.add(_chunk('IHDR', ihdr.toBytes()));
  out.add(_chunk('IDAT', Uint8List.fromList(idat)));
  out.add(_chunk('IEND', Uint8List(0)));

  final file = File('assets/textures/grain.png');
  file.createSync(recursive: true);
  file.writeAsBytesSync(out.toBytes());
  stdout.writeln('wrote ${file.path} (${file.lengthSync()} bytes)');
}

Uint8List _u32(int v) => Uint8List.fromList([(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]);

Uint8List _chunk(String type, Uint8List data) {
  final typeBytes = type.codeUnits;
  final b = BytesBuilder()
    ..add(_u32(data.length))
    ..add(typeBytes)
    ..add(data)
    ..add(_u32(_crc32(Uint8List.fromList([...typeBytes, ...data]))));
  return b.toBytes();
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return (c ^ 0xffffffff) & 0xffffffff;
}
