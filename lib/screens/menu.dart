import 'package:flutter/material.dart';

import '../audio.dart';
import '../paths.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/look.dart';
import 'paytable.dart';
import 'settings.dart';
import 'slot.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    final topSafe = topCutout(context);
    final h = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: FillBg(
        asset: A.bg2,
        child: Stack(
          children: [
            const SparkleField(),
            Padding(
              padding: EdgeInsets.fromLTRB(18, topSafe + 6, 18, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CoinChip(),
                      const Spacer(),
                      IconOrb(icon: Icons.settings, onTap: () {
                        sfx.open();
                        Navigator.of(context).push(fadeTo(const SettingsScreen()));
                      }),
                    ],
                  ),
                  SizedBox(height: h * 0.02),
                  Flexible(
                    child: Image.asset(A.gameName, height: h * 0.30, fit: BoxFit.contain),
                  ),
                  const Spacer(),
                  GoldBtn(
                    label: 'PLAY',
                    height: 68,
                    width: 250,
                    size: 32,
                    pulse: true,
                    onTap: () {
                      sfx.ok();
                      wallet.rescueIfBroke();
                      Navigator.of(context).push(fadeTo(const SlotScreen()));
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GoldBtn(
                        label: 'PAYTABLE',
                        height: 46,
                        width: 138,
                        size: 13,
                        onTap: () => Navigator.of(context).push(fadeTo(const PaytableScreen())),
                      ),
                      const SizedBox(width: 10),
                      GoldBtn(
                        label: 'BANK',
                        height: 46,
                        width: 110,
                        size: 13,
                        onTap: () => _bank(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (wallet.dailyReady)
                    GoldBtn(
                      label: 'DAILY GIFT',
                      height: 44,
                      width: 200,
                      size: 14,
                      pulse: true,
                      onTap: () {
                        final n = wallet.claimDaily();
                        if (n > 0) {
                          sfx.win();
                          _toast('Daily blessing: +${money(n)}');
                          setState(() {});
                        }
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bank() {
    sfx.open();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'bank',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, animation, secondary) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ROYAL BANK', style: deco(size: 22)),
                    const SizedBox(height: 8),
                    Text(
                      'Social coins only. Nothing here is real money.',
                      textAlign: TextAlign.center,
                      style: cinzel(size: 12, color: C.gold),
                    ),
                    const SizedBox(height: 16),
                    GoldBtn(
                      label: wallet.vaultReady ? 'CLAIM 1,500' : 'VAULT RESTING',
                      height: 50,
                      width: 220,
                      onTap: wallet.vaultReady
                          ? () {
                              final n = wallet.claimVault();
                              sfx.win();
                              Navigator.pop(ctx);
                              _toast('Vault opened: +${money(n)}');
                              setState(() {});
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    GoldBtn(
                      label: 'CLOSE',
                      height: 44,
                      width: 160,
                      size: 14,
                      onTap: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: C.velvet,
        content: Text(msg, style: cinzel(size: 14, color: C.goldPale)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
