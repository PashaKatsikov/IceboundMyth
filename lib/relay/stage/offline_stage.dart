import 'package:flutter/material.dart';

import '../../paths.dart';
import '../../theme.dart';
import '../../widgets/look.dart';
import '../wire/pulse_probe.dart';

/// Shown whenever the relay pipeline concludes "no network".
///
/// Retry rebuilds the caller-supplied route through
/// `pushReplacement`. The pipeline is idempotent by design — the
/// coordinator's in-flight cache clears on completion, so Retry
/// runs the full boot flow fresh (attribution → probe → verdict).
///
/// Rendered fully in-app on the game's theme — no dedicated artwork, so
/// it inherits the Icebound look.
class OfflineStage extends StatefulWidget {
  const OfflineStage({super.key, required this.onRetryBuild});

  final WidgetBuilder onRetryBuild;

  @override
  State<OfflineStage> createState() => _OfflineStageState();
}

class _OfflineStageState extends State<OfflineStage> {
  bool _spinning = false;
  bool _stillDown = false;

  /// Only hand back to the pipeline once the connection is genuinely
  /// back — otherwise the user would watch the loading art appear and
  /// bounce straight back here.
  Future<void> _retry() async {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _stillDown = false;
    });
    final bool online = await PulseProbe().canDialOut();
    if (!mounted) return;
    if (!online) {
      setState(() {
        _spinning = false;
        _stillDown = true;
      });
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.onRetryBuild),
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
        asset: A.bg3,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const SparkleField(),
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: landscape ? size.width * 0.14 : 26,
                ),
                child: Panel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.wifi_off_rounded,
                          color: C.gold, size: landscape ? 40 : 54),
                      const SizedBox(height: 14),
                      Text(
                        'NO INTERNET CONNECTION',
                        textAlign: TextAlign.center,
                        style: deco(size: landscape ? 20 : 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _stillDown
                            ? 'Still offline — reconnect and try again'
                            : 'Check your connection and try again',
                        textAlign: TextAlign.center,
                        style: cinzel(size: 14, color: C.goldPale),
                      ),
                      const SizedBox(height: 22),
                      _spinning
                          ? const SizedBox(
                              height: 40,
                              width: 40,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(C.gold),
                              ),
                            )
                          : GoldBtn(
                              label: 'RETRY',
                              height: 54,
                              width: landscape ? 220 : 240,
                              size: 20,
                              pulse: true,
                              onTap: _retry,
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
