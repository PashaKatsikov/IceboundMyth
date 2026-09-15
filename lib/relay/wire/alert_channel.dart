import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/relay_config.dart';
import 'beacon_keystore.dart';
import 'relay_agent.dart';

// Firebase Messaging plus the local-notifications channel. A cold-start
// tap (app killed) stashes the URL in the keystore for the boot pipeline
// to read on the next frame; warm taps (background/foreground) arrive
// through [onIncomingUrl] and are not persisted. The channel id below
// must match default_notification_channel_id in AndroidManifest.xml.

// Must match the value in AndroidManifest.xml.
const String kAlertChannelId = 'im_rewards';
// Shown to the user in Android system settings.
const String kAlertChannelName = 'Bonuses & Offers';
const String _smallIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  // OS renders the notification; the tap is handled on resume/boot.
}

class AlertChannel {
  AlertChannel(this._keystore);

  final BeaconKeystore _keystore;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _messaging;
  String? _token;
  bool _ready = false;
  bool _tapResolved = false;
  String? _launchTapUrl;

  /// Warm-tap URL delivery — the WebView should load this directly.
  void Function(String url)? onIncomingUrl;

  /// FCM rotated the token. Coordinator re-POSTs the verdict so the
  /// backend can target this device.
  void Function(String token)? onTokenChanged;

  String? get token => _token;

  /// Everything that works with the network down: Firebase handles,
  /// the local-notifications channel, and the launch-tap capture.
  /// This is what main() awaits — blocking the first frame on a token
  /// request would hang the app for as long as FCM keeps retrying.
  Future<void> primeLaunchTap() async {
    await _wire();
    await _captureLaunchTap();
  }

  /// Full boot: the local wiring plus the FCM token, the one piece
  /// that needs a live connection.
  Future<void> boot() async {
    await _wire();
    // A launch with no connection leaves the token null. The next
    // pipeline run — a Retry from the offline stage above all — rearms
    // and asks again, so the token lands as soon as the user is back
    // online without every boot() inside one run paying the timeout.
    if (_ready && _token == null && !_tokenMissed) await _fetchToken();
    // Capture is OUTSIDE the wiring guard. main() runs before the
    // engine can answer MethodChannels; decide() runs again after the
    // first frame so the native launch-intent extras land.
    await _captureLaunchTap();
  }

  Future<void> _wire() async {
    if (_ready) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_bgHandler);

      await _setupLocal();

      _messaging!.onTokenRefresh.listen((String t) {
        _token = t;
        onTokenChanged?.call(t);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      _ready = true;
    } catch (_) {
      // Firebase not configured yet, or the plugins failed while
      // offline — push stays dormant and the next boot() retries.
    }
  }

  Future<void>? _tokenCall;
  bool _tokenMissed = false;

  /// Lets the next [boot] ask for a token again after an attempt came
  /// back empty. Called once per pipeline run.
  void rearmToken() => _tokenMissed = false;

  Future<void> _fetchToken() {
    final Future<void>? running = _tokenCall;
    if (running != null) return running;
    final Future<void> call = _requestToken();
    _tokenCall = call;
    return call.whenComplete(() => _tokenCall = null);
  }

  Future<void> _requestToken() async {
    try {
      _token = await _messaging!
          .getToken()
          .timeout(Duration(seconds: RelayConfig.verdictTimeoutSeconds));
    } catch (_) {
      _token = null;
    }
    _tokenMissed = _token == null;
  }

  /// One-shot in-memory tap URL. Null unless THIS process was opened
  /// by a notification tap. Never read a persisted slot — that is
  /// what leaked push URLs onto later icon launches.
  String? takeLaunchTapUrl() {
    final String? url = _launchTapUrl;
    _launchTapUrl = null;
    return url;
  }

  /// Collects a *tap* URL (never a silent receive). Runs once per
  /// process. A launcher / task-restore open must not pick up a
  /// stale `getInitialMessage` or a leftover local-notifications flag.
  Future<void> _captureLaunchTap() async {
    if (_tapResolved) return;
    _tapResolved = true;

    final String kind = await _readLaunchKind();
    if (kind == 'icon' || kind == 'restore') {
      _launchTapUrl = null;
      return;
    }

    if (kind == 'push') {
      final String? native = await _readNativeLaunchTap();
      if (native != null) {
        _launchTapUrl = native;
        return;
      }
      if (_messaging != null) {
        final String? fromFcm = urlFromMessage(await _messaging!.getInitialMessage());
        if (fromFcm != null) _launchTapUrl = fromFcm;
      }
      return;
    }

    if (kind == 'local') {
      final NotificationAppLaunchDetails? local =
          await _local.getNotificationAppLaunchDetails();
      if (local?.didNotificationLaunchApp == true) {
        _launchTapUrl = urlFromPayload(local!.notificationResponse?.payload);
      }
    }
  }

  static Future<String> _readLaunchKind() async {
    try {
      final String? kind = await const MethodChannel('myth/vault')
          .invokeMethod<String>('launchKind');
      if (kind == 'push' || kind == 'local' || kind == 'restore' || kind == 'icon') {
        return kind!;
      }
    } catch (_) {}
    return 'icon';
  }

  static Future<String?> _readNativeLaunchTap() async {
    try {
      final String? url =
          await const MethodChannel('myth/vault').invokeMethod<String>('takeLaunchTap');
      if (url != null && url.startsWith('http')) return url;
    } catch (_) {}
    return null;
  }

  static String? urlFromMessage(RemoteMessage? message) {
    if (message == null) return null;
    return urlFromData(message.data);
  }

  static String? urlFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map) {
        return urlFromData(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      if (payload.startsWith('http')) return payload;
    }
    return null;
  }

  static String? urlFromData(Map<String, dynamic> data) {
    for (final String key in <String>['url', 'link', 'click_url', 'deeplink']) {
      final Object? value = data[key];
      if (value is String && value.startsWith('http')) return value;
    }
    return null;
  }

  Future<void> _setupLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? url = urlFromPayload(r.payload);
        if (url == null) return;
        if (onIncomingUrl != null) {
          onIncomingUrl!(url);
        } else {
          _launchTapUrl = url;
        }
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          kAlertChannelId,
          kAlertChannelName,
          description: 'Updates and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// System permission prompt. Records an OS-denied flag so the
  /// invite stage stops reappearing after a hard "no".
  Future<bool> askPermission() async {
    if (_messaging == null) return false;
    final NotificationSettings settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
    await _keystore.markPermissionGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _keystore.markPermissionBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _fetchImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kAlertChannelId,
          kAlertChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kAlertChannelId,
      kAlertChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = urlFromMessage(message);
    if (url == null) return;
    if (onIncomingUrl != null) {
      onIncomingUrl!(url);
    } else {
      _launchTapUrl = url;
    }
  }

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final dynamic res = await relayAgent
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
