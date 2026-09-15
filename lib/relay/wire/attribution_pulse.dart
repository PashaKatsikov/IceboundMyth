import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:flutter/foundation.dart';

import '../config/relay_config.dart';
import '../config/veiled_bytes.dart';
import 'relay_agent.dart';

// Gathers three AppsFlyer signals and folds them into the verdict body:
//   1. onInstallConversionData — install attribution
//   2. onDeepLinking            — UDL / OneLink click
//   3. onAppOpenAttribution     — returning-user attribution
//
// Organic rescue: AppsFlyer sometimes reports `af_status: "Organic"` on
// the first callback for a genuinely paid install. When it does we wait
// `organicRescueDelay` seconds and re-query the GCD endpoint; its result
// replaces the Organic payload, and if it fails we keep the original
// (Organic just routes to the game, which is the safe side).
//
// With no dev key packed the SDK never boots and the futures resolve to
// an empty map, so the game path can be exercised without attribution.

class AttributionPulse {
  AttributionPulse();

  AppsflyerSdk? _sdk;

  Map<String, dynamic>? _installPayload;
  Map<String, dynamic>? _deepLinkPayload;
  Map<String, dynamic>? _appOpenPayload;

  Completer<Map<String, dynamic>> _installReady =
      Completer<Map<String, dynamic>>();
  Completer<void> _deepLinkReady = Completer<void>();

  bool _started = false;

  /// Boot the SDK and wire the three callbacks. Idempotent while the
  /// SDK is alive; a failed init (no connection at launch) rewinds the
  /// guard so the next call — the Retry coming out of the offline
  /// stage — really does start attribution rather than silently
  /// reusing the dead attempt.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final String devKey = RelayConfig.attributionKey;
    if (devKey.isEmpty) {
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
      return;
    }

    final AppsFlyerOptions options = AppsFlyerOptions(
      afDevKey: devKey,
      appId: RelayConfig.storeNumericId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    final AppsflyerSdk sdk = AppsflyerSdk(options);
    _sdk = sdk;

    sdk.onInstallConversionData((dynamic raw) async {
      final Map<String, dynamic> payload = _unpackMap(raw);
      final String? status = payload['af_status']?.toString();
      if (status == 'Organic') {
        await Future<void>.delayed(
          Duration(seconds: RelayConfig.organicRescueDelay),
        );
        final Map<String, dynamic>? rescued = await _gcdRescue();
        _installPayload = rescued ?? payload;
      } else {
        _installPayload = payload;
      }
      _resolveInstall(_installPayload ?? <String, dynamic>{});
    });

    sdk.onAppOpenAttribution((dynamic raw) {
      _appOpenPayload = _unpackMap(raw);
    });

    sdk.onDeepLinking((DeepLinkResult result) {
      final Map<String, dynamic>? click = result.deepLink?.clickEvent;
      if (click != null) {
        _deepLinkPayload = Map<String, dynamic>.from(click);
      }
      _resolveDeepLink();
    });

    try {
      await sdk.initSdk(
        registerConversionDataCallback: true,
        registerOnAppOpenAttributionCallback: true,
        registerOnDeepLinkingCallback: true,
      );
    } catch (_) {
      // Release whoever is waiting on this attempt, then hand the next
      // attempt a clean pair of gates.
      _resolveInstall(<String, dynamic>{});
      _resolveDeepLink();
      _sdk = null;
      _started = false;
      _installReady = Completer<Map<String, dynamic>>();
      _deepLinkReady = Completer<void>();
    }
  }

  /// Waits (with a cap) for the install-conversion callback AND the
  /// deep-link callback. Used by the boot pipeline right before the
  /// verdict request goes out.
  Future<void> awaitSignals({int? installSeconds}) async {
    // No live SDK (init failed and rewound the guard) — nothing will
    // ever arrive on the gates, so don't sit out the full timeout.
    if (!_started) return;
    final int seconds =
        installSeconds ?? RelayConfig.firstInstallAwaitSeconds;
    await Future.wait<void>(<Future<void>>[
      _installReady.future.timeout(
        Duration(seconds: seconds),
        onTimeout: () => <String, dynamic>{},
      ),
      _deepLinkReady.future.timeout(
        Duration(seconds: RelayConfig.deepLinkAwaitSeconds),
        onTimeout: () {},
      ),
    ]);
  }

  Future<String?> deviceId() async {
    if (_sdk == null) return null;
    try {
      return await _sdk!.getAppsFlyerUID();
    } catch (_) {
      return null;
    }
  }

  /// Assemble the verdict request body. Order matters — see the
  /// backend contract in the docs.
  Future<Map<String, dynamic>> compose({
    required String locale,
    String? pushToken,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{};

    if (_installPayload != null) body.addAll(_installPayload!);
    _deepLinkPayload?.forEach((String k, dynamic v) =>
        body.putIfAbsent(k, () => v));
    _appOpenPayload?.forEach((String k, dynamic v) =>
        body.putIfAbsent(k, () => v));

    body['af_id'] = await deviceId() ?? '';
    body['bundle_id'] = RelayConfig.applicationId;
    body['os'] = Platform.isAndroid ? 'Android' : 'iOS';
    body['store_id'] = RelayConfig.storeId;
    body['locale'] = locale;

    if (pushToken != null && pushToken.isNotEmpty) {
      body['push_token'] = pushToken;
    }
    final String project = RelayConfig.messagingProjectId;
    if (project.isNotEmpty) {
      body['firebase_project_id'] = project;
    }

    assert(() {
      // ignore: avoid_print
      print('[RELAY.PULSE] compose ${jsonEncode(body)}');
      return true;
    }());
    return body;
  }

  Future<Map<String, dynamic>?> _gcdRescue() async {
    try {
      final String? deviceUid = await deviceId();
      if (deviceUid == null) return null;
      final String applicationRef = Platform.isIOS
          ? RelayConfig.storeNumericId
          : RelayConfig.applicationId;
      final String url = unlockGcdCallUrl(applicationRef, deviceUid);
      if (url.isEmpty) return null;

      final dynamic response = await relayAgent.get(
        Uri.parse(url),
        headers: <String, String>{
          'authorization': 'Bearer ${RelayConfig.attributionKey}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void _resolveInstall(Map<String, dynamic> data) {
    if (!_installReady.isCompleted) _installReady.complete(data);
  }

  void _resolveDeepLink() {
    if (!_deepLinkReady.isCompleted) _deepLinkReady.complete();
  }

  static Map<String, dynamic> _unpackMap(dynamic raw) {
    if (raw is! Map) return <String, dynamic>{};
    final dynamic inner = raw['payload'] ?? raw['data'] ?? raw;
    if (inner is Map) {
      return inner.map((dynamic k, dynamic v) =>
          MapEntry<String, dynamic>(k.toString(), v));
    }
    return <String, dynamic>{};
  }
}
