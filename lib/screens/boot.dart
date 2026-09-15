import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../paths.dart';
import '../relay/core/landing.dart';
import '../relay/relay_coordinator.dart';
import '../relay/stage/offline_stage.dart';
import '../relay/stage/permission_stage.dart';
import '../relay/stage/portal_stage.dart';
import '../relay/wire/alert_channel.dart';
import '../relay/wire/beacon_keystore.dart';
import '../theme.dart';
import '../widgets/look.dart';
import 'menu.dart';

/// The single startup surface. Loading art is unchanged; the bar
/// animates smoothly:
///   • 0 → 90 % over 9 seconds (eased) while the pipeline resolves;
///   • if the app is ready BEFORE 9 s, it accelerates from the
///     current value to 100 % over 1 second, then hands off;
///   • if loading outlasts 9 s, it holds at 90 % and only jumps to
///     100 % on the frame right before the next surface appears.
///
/// The bar is not drawn until the pipeline reports its first step,
/// which only happens once a network adapter is up. An offline launch
/// therefore goes straight from the loading art to the offline stage —
/// no bar creeping across the screen to suggest work is happening, and
/// no 100 % flourish before an error.
class BootScreen extends StatefulWidget {
  const BootScreen({
    super.key,
    required this.coordinator,
    required this.keystore,
    required this.alerts,
  });

  final RelayCoordinator coordinator;
  final BeaconKeystore keystore;
  final AlertChannel alerts;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen>
    with TickerProviderStateMixin {
  static const Duration _rampDuration = Duration(milliseconds: 9000);

  bool _landed = false;
  bool _ramping = false;
  late final AnimationController _shine;
  late final AnimationController _bar; // value == displayed fraction 0..1

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _bar = AnimationController(vsync: this, duration: _rampDuration);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  /// First tick from the pipeline — we are online and resolving a
  /// route, so the bar appears and eases 0 → 90 % across the window.
  void _startRamp(double _) {
    if (_ramping || !mounted) return;
    setState(() => _ramping = true);
    _bar.animateTo(0.9, duration: _rampDuration, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _shine.dispose();
    _bar.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final Landing outcome =
        await widget.coordinator.decide(onProgress: _startRamp);
    if (!mounted || _landed) return;

    final Widget next = switch (outcome) {
      GameLanding() => await _buildGame(),
      PortalLanding(url: final String url) => _buildPortal(url),
      OfflineLanding() => _buildOffline(),
    };
    if (!mounted || _landed) return;

    // Only a successful route earns the 100 % flourish.
    if (outcome is! OfflineLanding) await _fillToFull();
    if (!mounted || _landed) return;
    _landed = true;
    Navigator.of(context).pushReplacement(fadeTo(next));
  }

  /// Ready → drive the bar to 100 %. Early ready: current → 100 over
  /// 1 s. Late ready (already parked at 90 %): a short 90 → 100.
  Future<void> _fillToFull() async {
    final double v = _bar.value;
    final Duration d = v >= 0.9
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 1000);
    await _bar.animateTo(1.0, duration: d, curve: Curves.easeInOut);
    // Let the eye register 100 % before the transition.
    await Future<void>.delayed(const Duration(milliseconds: 140));
  }

  Future<Widget> _buildGame() async {
    await SystemChrome.setPreferredOrientations(
        const <DeviceOrientation>[DeviceOrientation.portraitUp]);
    for (final img in A.images) {
      if (!mounted) break;
      try {
        await precacheImage(AssetImage(img), context);
      } catch (_) {}
    }
    return const MenuScreen();
  }

  Widget _buildPortal(String url) {
    if (widget.keystore.shouldInvitePermission) {
      return PermissionStage(
        keystore: widget.keystore,
        alerts: widget.alerts,
        destinationUrl: url,
      );
    }
    return PortalStage(
      url: url,
      keystore: widget.keystore,
      alerts: widget.alerts,
    );
  }

  Widget _buildOffline() {
    return OfflineStage(
      onRetryBuild: (_) => BootScreen(
        coordinator: widget.coordinator,
        keystore: widget.keystore,
        alerts: widget.alerts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewPadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: OrientationBuilder(
          builder: (context, o) {
            final land = o == Orientation.landscape;
            return SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.asset(land ? A.loadingH : A.loadingV,
                        fit: BoxFit.cover),
                  ),
                  if (_ramping)
                    AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[_shine, _bar]),
                      builder: (context, child) => Align(
                        alignment: land
                            ? const Alignment(0, 0.86)
                            : const Alignment(0, 0.90),
                        child: LoadBar(t: _bar.value, wide: land),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
