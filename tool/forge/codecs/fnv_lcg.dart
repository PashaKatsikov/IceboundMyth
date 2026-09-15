// ============================================================
// Codec template + encoder — salt-seeded xorshift pad
// ============================================================
// A djb2 hash of the salt seeds a 32-bit xorshift generator. The
// generator fills a fixed-length pad, and each source byte is XORed
// with pad[i % len]. Symmetric, so encode and reveal share the pad.
// Distinct shape from the position-mask and RC4 variants.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

int _seedFromSalt(List<int> salt) {
  int h = 5381;
  for (final int b in salt) {
    h = ((h << 5) + h + b) & 0xFFFFFFFF;
  }
  return h == 0 ? 0x1A2B3C4D : h;
}

Uint8List _buildPad(List<int> salt, int padLen) {
  int x = _seedFromSalt(salt);
  final Uint8List pad = Uint8List(padLen);
  for (int i = 0; i < padLen; i++) {
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    x &= 0xFFFFFFFF;
    pad[i] = (x >> ((i & 3) << 3)) & 0xFF;
  }
  return pad;
}

List<int> encodeFnvLcg({
  required String plain,
  required List<int> salt,
  required int streamLen,
}) {
  if (plain.isEmpty) return const <int>[];
  final Uint8List pad = _buildPad(salt, streamLen);
  final List<int> src = utf8.encode(plain);
  final Uint8List out = Uint8List(src.length);
  for (int i = 0; i < src.length; i++) {
    out[i] = (src[i] ^ pad[i % streamLen]) & 0xFF;
  }
  return out;
}

bool roundTripsFnvLcg({
  required String plain,
  required List<int> salt,
  required int streamLen,
}) {
  final List<int> encoded = encodeFnvLcg(
    plain: plain,
    salt: salt,
    streamLen: streamLen,
  );
  final Uint8List pad = _buildPad(salt, streamLen);
  final Uint8List out = Uint8List(encoded.length);
  for (int i = 0; i < encoded.length; i++) {
    out[i] = (encoded[i] ^ pad[i % streamLen]) & 0xFF;
  }
  return utf8.decode(out) == plain;
}

String fnvLcgRuntimeSource({
  required List<int> salt,
  required int streamLen,
}) =>
    _template
        .replaceFirst('__SALT__', _formatBytes(salt))
        .replaceFirst('__STREAM_LEN__', streamLen.toString());

String _formatBytes(List<int> bytes) {
  final StringBuffer buf = StringBuffer('<int>[\n');
  for (int i = 0; i < bytes.length; i++) {
    if (i % 8 == 0) buf.write('  ');
    buf.write('0x${bytes[i].toRadixString(16).toUpperCase().padLeft(2, '0')}');
    buf.write(',');
    if (i % 8 == 7 || i == bytes.length - 1) {
      buf.write('\n');
    } else {
      buf.write(' ');
    }
  }
  buf.write(']');
  return buf.toString();
}

const String _template = r"""import 'dart:convert';
import 'dart:typed_data';

// String obfuscation used across the config layer. A salt seeds a
// small xorshift generator; the resulting pad is XOR-combined with
// the stored bytes. Symmetric, so the same routine both hides and
// restores a value. Not cryptography — it only keeps endpoints and
// keys out of the binary as readable literals.

const List<int> _salt = __SALT__;
const int _padLen = __STREAM_LEN__;

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
""";
