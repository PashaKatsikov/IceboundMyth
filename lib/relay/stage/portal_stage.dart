import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import '../wire/device_signature.dart';
import '../wire/pulse_probe.dart';
import '../wire/web_scripts.dart';
import 'offline_stage.dart';

// Full-screen WebView that hosts the destination URL. It:
//   • uses the device User-Agent (same string as the HTTP client);
//   • forwards keyboard cover as a fraction (see web_scripts.dart);
//   • hands off external schemes (tel:, mailto:, intent://);
//   • recovers from main-frame redirect loops (-1007 / -9) with a
//     bounded retry;
//   • guards connectivity behind a debounce;
//   • loads warm push URLs via [AlertChannel.onIncomingUrl];
//   • opens a native file chooser over a MethodChannel;
//   • installs its JS through `WebScripts.installAll`.
//
// The client does not inspect the page it loads — anything the business
// needs from the session lives server-side.
// ============================================================

class PortalStage extends StatefulWidget {
  const PortalStage({
    super.key,
    required this.url,
    required this.keystore,
    required this.alerts,
  });

  final String url;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinner = true;
  bool _offlineShown = false;
  String? _lastMainFrame;
  int _retryCounter = 0;
  Timer? _dropDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // Must stay in sync with MainActivity.kt → `channelName`.
  static const MethodChannel _uploadChannel = MethodChannel('myth/vault');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _listenHost();
    _primeNotch();
    _buildController();

    widget.alerts.onIncomingUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    // Debounce connectivity drops — a VPN reconnect or a brief cell
    // switch produces a burst of `none` events that must not fire
    // the offline stage. Only sustained drops route out.
    _connSub = PulseProbe().statusStream.listen((List<ConnectivityResult> r) {
      final bool allNone =
          r.isNotEmpty && r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _dropDebounce?.cancel();
        return;
      }
      _dropDebounce?.cancel();
      _dropDebounce = Timer(
        Duration(milliseconds: RelayConfig.reachDropDebounceMs),
        _showOffline,
      );
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ));
  }

  /// From API 30 the IME inset arrives through WindowInsets.Type.ime()
  /// regardless of soft-input mode, so MainActivity parks the window
  /// on ADJUST_NOTHING and we tell the page the cover fraction. Below
  /// that the window still resizes and Chromium scrolls the focused
  /// field itself — pushing our own offset there would move the
  /// content twice.
  static bool get _drivesKeyboard => DeviceSignature.apiLevel >= 30;

  double _imePx = 0;

  void _listenHost() {
    _uploadChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'cutout') {
        _acceptHostNotch(call.arguments);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  /// Forwards IME geometry without a rebuild. Routing it through
  /// setState would resize the WebView a frame late — that lag is
  /// the jitter. Physical pixels on both sides of the division so
  /// the page gets a dimensionless share of its own height.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    if (!_notchFromHost) {
      final EdgeInsets rotated = _viewNotch();
      if (rotated != _notch) setState(() => _notch = rotated);
    }
    if (!_drivesKeyboard) return;
    final ui.FlutterView view = View.of(context);
    final double ratio = view.devicePixelRatio;
    if (ratio <= 0) return;
    final double inset = view.viewInsets.bottom / ratio;
    if ((inset - _imePx).abs() < 1) return;
    _imePx = inset;
    _feedCover();
  }

  void _feedCover() {
    if (!mounted) return;
    final ui.FlutterView view = View.of(context);
    final double ratio = view.devicePixelRatio;
    if (ratio <= 0) return;
    final double height = view.physicalSize.height - _notch.top * ratio;
    if (height <= 0) return;
    WebScripts.feedCover(
      _web,
      cover: (_imePx * ratio / height).clamp(0.0, 1.0),
    );
  }

  void _buildController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(DeviceSignature.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinner = true);
        },
        onPageFinished: (_) async {
          if (mounted) setState(() => _spinner = false);
          _retryCounter = 0;
          await WebScripts.installAll(_web);
          if (_imePx > 0) _feedCover();
        },
        onWebResourceError: _onError,
        onNavigationRequest: _onNavigate,
      ));

    _configureAndroid();
    _web.loadRequest(Uri.parse(widget.url));
  }

  void _onError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final String desc = err.description.toLowerCase();
    final bool isLoop = desc.contains('too_many_redirects') ||
        desc.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;

    if (isLoop &&
        _lastMainFrame != null &&
        _retryCounter < RelayConfig.redirectLoopRetries) {
      _retryCounter++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the WebView's native error page immediately so the
    // Android chrome robot never leaks visually.
    if (mounted) setState(() => _spinner = true);

    final bool isConnectivity = desc.contains('name_not_resolved') ||
        desc.contains('address_unreachable') ||
        desc.contains('internet_disconnected') ||
        desc.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21 ||
        err.errorCode == -2 ||
        err.errorCode == -6;

    if (isConnectivity) {
      _showOffline();
    } else {
      _guardOffline();
    }
  }

  NavigationDecision _onNavigate(NavigationRequest req) {
    final Uri? uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    const Set<String> inApp = <String>{
      'http',
      'https',
      'about',
      'data',
      'blob',
    };
    if (inApp.contains(uri.scheme)) {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _openExternally(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController controller =
        _web.platform as AndroidWebViewController;

    controller.setMediaPlaybackRequiresUserGesture(false);
    controller.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest r) => r.grant(),
    );
    controller.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(controller, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _openExternally(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _guardOffline() async {
    if (_offlineShown) return;
    final bool online = await PulseProbe().canDialOut();
    if (online) return;
    _showOffline();
  }

  void _showOffline() {
    if (_offlineShown || !mounted) return;
    _offlineShown = true;
    final String current = _lastMainFrame ?? widget.url;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflineStage(
          onRetryBuild: (_) => PortalStage(
            url: current,
            keystore: widget.keystore,
            alerts: widget.alerts,
          ),
        ),
      ),
    );
  }

  Future<void> _stepBack() async {
    if (await _web.canGoBack()) await _web.goBack();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dropDebounce?.cancel();
    _connSub?.cancel();
    _uploadChannel.setMethodCallHandler(null);
    widget.alerts.onIncomingUrl = null;
    super.dispose();
  }

  EdgeInsets _notch = EdgeInsets.zero;
  bool _notchReady = false;
  bool _notchFromHost = false;

  /// Display-cutout insets straight from the host window, already
  /// rotated for the current orientation — in landscape the gutter
  /// lands on the left or right edge, exactly where the camera hole
  /// is, instead of on top.
  Future<void> _primeNotch() async {
    try {
      _acceptHostNotch(
        await _uploadChannel.invokeMethod<List<Object?>>('cutout'),
      );
    } catch (_) {}
  }

  /// The host is authoritative once it has answered, even when the
  /// answer is "no cutout at all" — that zero has to win over the view
  /// padding, which would otherwise hand us a status-bar-sized gutter
  /// on a device with no camera hole.
  void _acceptHostNotch(Object? raw) {
    final EdgeInsets? parsed = _parseInsets(raw);
    if (parsed == null || !mounted) return;
    _notchFromHost = true;
    _notchReady = true;
    if (parsed == _notch) return;
    setState(() => _notch = parsed);
  }

  static EdgeInsets? _parseInsets(Object? raw) {
    if (raw is! List || raw.length < 4) return null;
    double at(int i) {
      final Object? value = raw[i];
      return value is num ? value.toDouble() : 0;
    }

    return EdgeInsets.fromLTRB(at(0), at(1), at(2), at(3));
  }

  /// Fallback for hosts that report no cutout (pre-API-28 devices, or
  /// a channel that never answered). The app-wide MediaQuery override
  /// zeros `viewPadding`, so it has to be read from the raw view.
  /// Bottom stays 0 here — on this path the value would be the nav bar
  /// rather than a cutout.
  EdgeInsets _viewNotch() {
    final EdgeInsets raw =
        MediaQueryData.fromView(View.of(context)).viewPadding;
    return EdgeInsets.only(left: raw.left, top: raw.top, right: raw.right);
  }

  @override
  Widget build(BuildContext context) {
    if (!_notchReady) {
      _notch = _viewNotch();
      _notchReady = true;
    }
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _stepBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              // Cutout only. Keyboard inset is never applied here —
              // resizing the WebView reflows the document (fixed
              // dialogs collapse) and races Blink's visual-viewport
              // pan. Cover fraction goes to the page via feedCover.
              padding: _notch,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinner && !landscape)
              const ColoredBox(
                color: Color(0x80000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFE6C25A)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
