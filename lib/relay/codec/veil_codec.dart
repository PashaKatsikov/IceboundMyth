import 'dart:convert';
import 'dart:typed_data';

// String obfuscation used across the config layer. A salt seeds a
// small xorshift generator; the resulting pad is XOR-combined with
// the stored bytes. Symmetric, so the same routine both hides and
// restores a value. Not cryptography — it only keeps endpoints and
// keys out of the binary as readable literals.

const List<int> _salt = <int>[
  0x7E, 0x3A, 0xC1, 0x08, 0x95, 0x4D, 0xB2, 0x6F,
  0x21, 0xE9, 0x5C, 0x84, 0x37, 0xA0, 0xD6, 0x1B,
  0x72, 0xCE,
];
const int _padLen = 37;

int _seed() {
  int h = 5381;
  for (final int b in _salt) {
    h = ((h << 5) + h + b) & 0xFFFFFFFF;
  }
  return h == 0 ? 0x1A2B3C4D : h;
}

Uint8List _buildPad() {
  int x = _seed();
  final Uint8List pad = Uint8List(_padLen);
  for (int i = 0; i < _padLen; i++) {
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    x &= 0xFFFFFFFF;
    pad[i] = (x >> ((i & 3) << 3)) & 0xFF;
  }
  return pad;
}

final Uint8List _pad = _buildPad();

String reveal(List<int> data) {
  if (data.isEmpty) return '';
  final Uint8List out = Uint8List(data.length);
  for (int i = 0; i < data.length; i++) {
    out[i] = (data[i] ^ _pad[i % _padLen]) & 0xFF;
  }
  return utf8.decode(out);
}
