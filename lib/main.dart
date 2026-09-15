import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'relay/relay_coordinator.dart';
import 'relay/wire/alert_channel.dart';
import 'relay/wire/attribution_pulse.dart';
import 'relay/wire/beacon_keystore.dart';
import 'relay/wire/device_signature.dart';
import 'relay/wire/pulse_probe.dart';
import 'relay/wire/verdict_call.dart';
import 'screens/boot.dart';
import 'theme.dart';
import 'wallet.dart';

void hideChrome() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

// ============================================================
// main.dart — bootstrap wiring
// ============================================================
// Order of operations (do NOT reorder without reading the relay docs):
//   1. WidgetsFlutterBinding — required before any plugin call.
//   2. Firebase + AppCheck   — wrapped in try/catch. The app compiles
//      and runs without google-services.json; a failure here must
//      NEVER block startup (the coordinator falls back to the native
//      game path).
//   3. Immersive chrome + orientations — set once so the boot screen
//      renders edge-to-edge on frame one. All four orientations are
//      allowed at boot; the game path re-locks to portrait.
//   4. wallet + sfx — the native game's own state (unchanged).
//   5. DeviceSignature.prime — builds the device User-Agent used by
//      BOTH the HTTP client (RelayAgent) and the WebView. MUST run
//      before any bridge or the WebView is constructed.
//   6. BeaconKeystore.prime — reads SharedPreferences into memory so
//      the coordinator's route decision is synchronous.
//   7. Assemble the relay pipeline and mount the app.
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (_) {}

  hideChrome();
  await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

  await wallet.load();
  await sfx.load();

  await DeviceSignature.prime();

  final BeaconKeystore keystore = BeaconKeystore();
  await keystore.prime();

  final PulseProbe probe = PulseProbe();
  final AttributionPulse pulse = AttributionPulse();
  final VerdictCall verdict = VerdictCall(keystore);
  final AlertChannel alerts = AlertChannel(keystore);
  // Must finish before the first frame: getInitialMessage / the
  // launch-intent extras are only reliable around process start. If
  // this runs after decide(), a push tap is lost and the cached
  // config URL wins (then the leftover message fires next launch).
  // Network-free by design — the FCM token is fetched later, inside
  // the pipeline, so a launch with no connection is not held up here.
  try {
    await alerts.primeLaunchTap();
  } catch (_) {}

  final RelayCoordinator coordinator = RelayCoordinator(
    keystore: keystore,
    probe: probe,
    pulse: pulse,
    verdict: verdict,
    alerts: alerts,
  );

  runApp(IceboundApp(
    coordinator: coordinator,
    keystore: keystore,
    alerts: alerts,
  ));
}

class IceboundApp extends StatefulWidget {
  const IceboundApp({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final RelayCoordinator coordinator;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<IceboundApp> createState() => _IceboundAppState();
}

class _IceboundAppState extends State<IceboundApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    hideChrome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) hideChrome();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Icebound Myth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.burgundy,
        fontFamily: 'Cinzel',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: BootScreen(
        coordinator: widget.coordinator,
        keystore: widget.keystore,
        alerts: widget.alerts,
      ),
    );
  }
}
