import 'package:http/http.dart' as http;

import 'device_signature.dart';

// All relay traffic (verdict POST, GCD rescue, notification image
// fetch) is issued through this client so the device User-Agent is
// stamped in exactly one place. Without it a request would go out with
// Dart's default `dart-io/x.y` agent, which is an obvious tell.

class RelayAgent extends http.BaseClient {
  RelayAgent([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['User-Agent'] = DeviceSignature.userAgent;
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

/// Process-wide instance. Usable once `DeviceSignature.prime()` has run
/// in `main()`.
final RelayAgent relayAgent = RelayAgent();
