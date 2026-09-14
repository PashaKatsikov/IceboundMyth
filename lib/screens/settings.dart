import 'package:flutter/material.dart';

import '../paths.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/look.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FillBg(
        asset: A.bg1,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, topCutout(context) + 8, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconOrb(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  const Spacer(),
                  Text('SETTINGS', style: deco(size: 22)),
                  const Spacer(),
                  const SizedBox(width: 42),
                ],
              ),
              const SizedBox(height: 28),
              ListenableBuilder(
                listenable: wallet,
                builder: (context, child) {
                  return Panel(
                    child: Column(
                      children: [
                        _row('Sound', wallet.sound, wallet.setSound),
                        const SizedBox(height: 16),
                        _row('Haptics', wallet.haptic, wallet.setHaptic),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              Panel(
                child: Column(
                  children: [
                    Text('ICEBOUND MYTH', style: deco(size: 18)),
                    const SizedBox(height: 8),
                    Text(
                      'A social casino. Play for fun coins only.\nNo real-money gambling.',
                      textAlign: TextAlign.center,
                      style: cinzel(size: 13, color: C.gold),
                    ),
                    const SizedBox(height: 12),
                    Text('v1.0.0', style: cinzel(size: 12, color: C.goldDeep)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, bool on, void Function(bool) set) {
    return Row(
      children: [
        Expanded(child: Text(label, style: cinzel(size: 18))),
        GestureDetector(
          onTap: () => set(!on),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 64,
            height: 34,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: on ? const [C.gold, C.goldDeep] : const [Color(0xFF3A2020), Color(0xFF1A0A0A)],
              ),
              border: Border.all(color: C.goldPale.withValues(alpha: 0.7)),
            ),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.goldPale, C.gold]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
