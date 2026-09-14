import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio.dart';
import '../cheat.dart';
import '../paths.dart';
import '../theme.dart';
import '../widgets/look.dart';

class FishBonus extends StatefulWidget {
  final int stake;
  const FishBonus({super.key, required this.stake});

  @override
  State<FishBonus> createState() => _FishBonusState();
}

class _FishBonusState extends State<FishBonus> with SingleTickerProviderStateMixin {
  late final Ticker _tick;
  final rnd = Random();
  var t = 0.0;
  var mult = 1.0;
  late final double crash;
  var live = true;
  var cashed = false;
  var gone = false;

  @override
  void initState() {
    super.initState();
    crash = cheatOn ? 18 + rnd.nextDouble() * 22 : _rollCrash();
    _tick = createTicker(_onTick)..start();
    sfx.open();
  }

  double _rollCrash() {
    final u = rnd.nextDouble();
    if (u < 0.28) return 1.15 + rnd.nextDouble() * 0.8;
    if (u < 0.55) return 2.0 + rnd.nextDouble() * 2.2;
    if (u < 0.78) return 4.2 + rnd.nextDouble() * 4.0;
    if (u < 0.92) return 8.2 + rnd.nextDouble() * 7.0;
    return 15 + rnd.nextDouble() * 25;
  }

  void _onTick(Duration e) {
    if (!live) return;
    t = e.inMilliseconds / 1000.0;
    mult = 1.0 * pow(1.085, t * 2.15);
    if (mult >= crash) {
      live = false;
      gone = true;
      _tick.stop();
      sfx.lose();
      sfx.buzzHard();
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.pop(context, 0);
      });
    }
    setState(() {});
  }

  void _cash() {
    if (!live || cashed) return;
    live = false;
    cashed = true;
    _tick.stop();
    sfx.big();
    sfx.buzzHard();
    final won = (widget.stake * mult).round();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) Navigator.pop(context, won);
    });
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  String get fishArt {
    if (mult < 3) return 'assets/symbols/fish_gold.webp';
    if (mult < 8) return 'assets/symbols/fish_blue.webp';
    return 'assets/symbols/fish_red.webp';
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = topCutout(context);
    final h = MediaQuery.sizeOf(context).height;
    final climb = ((log(mult) / log(crash.clamp(1.2, 80))).clamp(0.0, 1.0));
    // fisherman stands near the top of the hole; the fish starts deep in
    // the water and gets reeled closer to him as the multiplier climbs.
    final fishY = 0.80 - climb * 1.10;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8EC8E8), Color(0xFF1A5A86), Color(0xFF041526)],
              ),
            ),
          ),
          const SparkleField(color: C.frost),
          CustomPaint(painter: _WaterPaint(t)),
          CustomPaint(
            painter: _LinePaint(fishY, gone),
            size: Size.infinite,
          ),
          Align(
            alignment: Alignment(0.36, fishY),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: gone ? 0 : 1,
              child: Transform.rotate(
                angle: gone ? 0.5 : sin(t * 6) * 0.1,
                child: Image.asset(fishArt, height: 78 + climb * 36, fit: BoxFit.contain),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.42, -0.42),
            child: Image.asset(A.fisher, height: h * 0.30, fit: BoxFit.contain),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topSafe + 8, 16, 12),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('ICE CRASH', maxLines: 1, style: deco(size: 26, color: C.snow, ls: 1)),
                ),
                Text('Stake ${money(widget.stake)}', style: cinzel(size: 13, color: C.frost)),
                const SizedBox(height: 12),
                Text(
                  '${mult.toStringAsFixed(2)}x',
                  style: deco(
                    size: 48,
                    color: gone ? C.blush : C.goldPale,
                    ls: 0.5,
                    shadows: const [
                      Shadow(color: Color(0xAA041526), blurRadius: 16),
                    ],
                  ),
                ),
                const Spacer(),
                if (cashed)
                  Text('+${money((widget.stake * mult).round())}', style: deco(size: 32, ls: 0.5)),
                if (gone && !cashed)
                  Text('SNAPPED', style: deco(size: 30, color: C.blush, ls: 1)),
                const SizedBox(height: 10),
                GoldBtn(
                  label: live ? 'CASH OUT' : (cashed ? 'NICE' : 'GONE'),
                  height: 56,
                  width: 220,
                  size: 18,
                  blue: true,
                  pulse: live,
                  onTap: live ? _cash : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterPaint extends CustomPainter {
  final double t;
  _WaterPaint(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x33E8F7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.18 + i * 0.1) + sin(t * 2 + i) * 6;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 16) {
        path.lineTo(x, y + sin(x * 0.03 + t * 3 + i) * 5);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterPaint old) => old.t != t;
}

class _LinePaint extends CustomPainter {
  final double fishY;
  final bool snapped;
  _LinePaint(this.fishY, this.snapped);

  @override
  void paint(Canvas canvas, Size size) {
    final from = Offset(size.width * 0.315, size.height * 0.275);
    final to = Offset(size.width * 0.68, size.height * ((fishY + 1) / 2));
    final paint = Paint()
      ..color = snapped ? const Color(0x88FF8A93) : const Color(0xDDE8F7FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    if (snapped) {
      canvas.drawLine(from, Offset.lerp(from, to, 0.45)!, paint);
      canvas.drawLine(Offset.lerp(from, to, 0.62)!, to, paint);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePaint old) => old.fishY != fishY || old.snapped != snapped;
}
