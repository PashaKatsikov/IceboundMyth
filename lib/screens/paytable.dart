import 'package:flutter/material.dart';

import '../paths.dart';
import '../slot/symbols.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/look.dart';

class PaytableScreen extends StatelessWidget {
  const PaytableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shown = Sym.values.where((s) => !s.isScatter || s == Sym.fish || s == Sym.glass).toList();

    return Scaffold(
      body: FillBg(
        asset: A.bg3,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, topCutout(context) + 8, 14, 10),
          child: Column(
            children: [
              Row(
                children: [
                  IconOrb(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  Text('PAYTABLE', style: deco(size: 22)),
                  const Spacer(),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Bet ${money(wallet.bet)}  ·  5 lines',
                style: cinzel(size: 13, color: C.gold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children: [
                    Panel(
                      pad: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                      child: Column(
                        children: [
                          Text('BONUSES', style: deco(size: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '3+ Myth Fish start the Ice Crash. Cash out before the line snaps.\n'
                            '3+ Fate Glasses spin the Wheel of Myth.',
                            textAlign: TextAlign.center,
                            style: cinzel(size: 12, color: C.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final s in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Panel(
                          pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Image.asset(s.art, width: 52, height: 52, fit: BoxFit.contain),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.info.title, style: cinzel(size: 15)),
                                    const SizedBox(height: 4),
                                    Text(
                                      s.isScatter
                                          ? (s == Sym.fish ? 'Scatter · Ice Crash' : 'Scatter · Wheel')
                                          : '3× ${s.info.pay[0]}   4× ${s.info.pay[1]}   5× ${s.info.pay[2]}',
                                      style: cinzel(size: 12, color: C.gold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
