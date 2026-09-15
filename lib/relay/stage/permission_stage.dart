import 'package:flutter/material.dart';

import '../../paths.dart';
import '../../theme.dart';
import '../../widgets/look.dart';
import '../config/relay_config.dart';
import '../wire/alert_channel.dart';
import '../wire/beacon_keystore.dart';
import 'portal_stage.dart';

/// One-shot push opt-in promo shown before the portal (only when
/// `keystore.shouldInvitePermission` is true — first time, or after
/// the snooze window expired).
///
/// Rendered fully in-app on the Icebound theme. Accept and Skip are
/// both real gradient buttons — Skip is not a faint text link.
class PermissionStage extends StatefulWidget {
  const PermissionStage({
    super.key,
    required this.keystore,
    required this.alerts,
    required this.destinationUrl,
  });

  final BeaconKeystore keystore;
  final AlertChannel alerts;
  final String destinationUrl;

  @override
  State<PermissionStage> createState() => _PermissionStageState();
}

class _PermissionStageState extends State<PermissionStage> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    _busy = true;
    final bool granted = await widget.alerts.askPermission();
    if (!granted) {
      await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    }
    if (mounted) _forward();
  }

  Future<void> _skip() async {
    if (_busy) return;
    _busy = true;
    await widget.keystore.writePermissionSnoozeUntil(_snoozeTarget());
    if (mounted) _forward();
  }

  int _snoozeTarget() =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000 +
      RelayConfig.permissionSnoozeSeconds;

  void _forward() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PortalStage(
          url: widget.destinationUrl,
          keystore: widget.keystore,
          alerts: widget.alerts,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: FillBg(
        asset: A.bg2,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const SparkleField(),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: landscape ? size.width * 0.12 : 24,
                ),
                child: Panel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.notifications_active_rounded,
                          color: C.gold, size: landscape ? 40 : 56),
                      const SizedBox(height: 14),
                      Text(
                        'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS',
                        textAlign: TextAlign.center,
                        style: deco(size: landscape ? 18 : 21),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Stay tuned for special offers and rewards',
                        textAlign: TextAlign.center,
                        style: cinzel(size: 14, color: C.goldPale),
                      ),
                      const SizedBox(height: 22),
                      GoldBtn(
                        label: 'ALLOW',
                        height: 54,
                        width: landscape ? 220 : 250,
                        size: 20,
                        pulse: true,
                        onTap: _accept,
                      ),
                      const SizedBox(height: 12),
                      GoldBtn(
                        label: 'SKIP',
                        height: 46,
                        width: landscape ? 160 : 170,
                        size: 15,
                        onTap: _skip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
