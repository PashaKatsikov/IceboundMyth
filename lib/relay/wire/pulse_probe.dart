import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/relay_config.dart';

// Connectivity plus a real DNS lookup. connectivity_plus alone is
// optimistic — captive portals, half-open VPN interfaces and routeless
// cells all report "connected". Resolving a neutral host confirms there
// is an actual path before the pipeline commits to online routing.

// Two hosts that resolve cheaply and have nothing to do with the
// backend or the partner. Alternating between them avoids a retry when
// one is momentarily unresolvable.
const List<String> _probeHosts = <String>[
  'wikipedia.org',
  'microsoft.com',
];

// Adapters treated as live. VPN and Bluetooth are deliberately in the
// set: leaving them out produced false offline results in the field,
// VPN most of all.
const Set<ConnectivityResult> _liveAdapters = <ConnectivityResult>{
  ConnectivityResult.wifi,
  ConnectivityResult.mobile,
  ConnectivityResult.ethernet,
  ConnectivityResult.vpn,
  ConnectivityResult.bluetooth,
  ConnectivityResult.other,
};

class PulseProbe {
  PulseProbe({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  int _hostCursor = 0;

  /// True when at least one adapter is live. Does not touch DNS — use
  /// [canDialOut] for that.
  Future<bool> hasAdapter() async {
    try {
      final List<ConnectivityResult> states =
          await _connectivity.checkConnectivity();
      return states.any(_liveAdapters.contains);
    } catch (_) {
      return false;
    }
  }

  /// Resolves one of the probe hosts inside the configured timeout,
  /// moving the starting host forward on each success.
  Future<bool> canDialOut() async {
    if (!await hasAdapter()) return false;
    final Duration timeout =
        Duration(seconds: RelayConfig.reachProbeTimeoutSeconds);
    final int count = _probeHosts.length;
    for (int step = 0; step < count; step++) {
      final String host = _probeHosts[(_hostCursor + step) % count];
      try {
        final List<InternetAddress> hits =
            await InternetAddress.lookup(host).timeout(timeout);
        if (hits.any((InternetAddress a) => a.rawAddress.isNotEmpty)) {
          _hostCursor = (_hostCursor + step + 1) % count;
          return true;
        }
      } catch (_) {
        // try the next candidate before giving up
      }
    }
    return false;
  }

  Stream<List<ConnectivityResult>> get statusStream =>
      _connectivity.onConnectivityChanged;
}
