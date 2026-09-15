import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

// Wire envelope for the verdict body (schema rev 3). The body is never
// sent as clean JSON; it is packed here and the relay unpacks it with
// the matching server routine (relay_service.py → `unpack`).
//
//   envelope = { "v": 3, "n": <hex 16B>, "p": <base64url>, "g": <hex 16> }
//     raw       = utf8(json(body))                  // compact, no spaces
//     keystream = sha256(secret + nonce + counterBE32) blocks
//     enc       = raw XOR keystream
//     p         = base64url(enc) without padding
//     g         = HMAC_sha256(secret, nonce + enc).hex()[:16]
//     n         = nonce (16 random bytes) as hex
//
// Anything the relay can't verify (bad tag, bad payload, wrong path,
// GET) comes back 404. The nonce is per-request, so two identical
// bodies never encode to the same bytes.

abstract final class VeilPack {
  static const int schemaRev = 3;

  static final Random _rng = Random.secure();

  /// Seal [body] into the opaque envelope using [secret] (RELAY_SECRET).
  static Map<String, dynamic> seal(Map<String, dynamic> body, String secret) {
    final Uint8List secretBytes = Uint8List.fromList(utf8.encode(secret));
    final Uint8List raw = Uint8List.fromList(
      utf8.encode(jsonEncode(body)),
    );
    final Uint8List nonce = _nonce(16);
    final Uint8List ks = _keystream(secretBytes, nonce, raw.length);

    final Uint8List enc = Uint8List(raw.length);
    for (int i = 0; i < raw.length; i++) {
      enc[i] = raw[i] ^ ks[i];
    }

    final String payload = _b64uNoPad(enc);
    final String tag = _tag(secretBytes, nonce, enc);

    return <String, dynamic>{
      'v': schemaRev,
      'n': _hex(nonce),
      'p': payload,
      'g': tag,
    };
  }

  // sha256(secret + nonce + counterBE32) concatenated, truncated to [length].
  static Uint8List _keystream(
    Uint8List secret,
    Uint8List nonce,
    int length,
  ) {
    final BytesBuilder out = BytesBuilder(copy: false);
    int counter = 0;
    while (out.length < length) {
      final Uint8List block = Uint8List(secret.length + nonce.length + 4);
      block.setRange(0, secret.length, secret);
      block.setRange(secret.length, secret.length + nonce.length, nonce);
      final ByteData ctr = ByteData(4)..setUint32(0, counter, Endian.big);
      block.setRange(
        secret.length + nonce.length,
        block.length,
        ctr.buffer.asUint8List(),
      );
      out.add(sha256.convert(block).bytes);
      counter++;
    }
    return Uint8List.fromList(out.toBytes().sublist(0, length));
  }

  // HMAC-SHA256(secret, nonce + enc), first 16 hex chars.
  static String _tag(Uint8List secret, Uint8List nonce, Uint8List enc) {
    final Uint8List msg = Uint8List(nonce.length + enc.length);
    msg.setRange(0, nonce.length, nonce);
    msg.setRange(nonce.length, msg.length, enc);
    final Digest d = Hmac(sha256, secret).convert(msg);
    return _hex(Uint8List.fromList(d.bytes)).substring(0, 16);
  }

  static Uint8List _nonce(int n) {
    final Uint8List b = Uint8List(n);
    for (int i = 0; i < n; i++) {
      b[i] = _rng.nextInt(256);
    }
    return b;
  }

  static String _b64uNoPad(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _hex(Uint8List bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
