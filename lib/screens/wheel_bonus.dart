import 'dart:math';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../cheat.dart';
import '../paths.dart';
import '../theme.dart';
import '../widgets/look.dart';

class Slice {
  final String label;
  final int mult;
  final String? badge;
  final int weight;

  const Slice(this.label, this.mult, this.weight, [this.badge]);
}

// 12 entries — matches the 12 painted wedges on the wheel artwork exactly,
// so every label sits centered in its own wedge instead of straddling
// the gold spokes.
const slices = [
  Slice('x2', 2, 20),
  Slice('x5', 5, 14),
  Slice('MINI', 20, 8, A.badgeMini),
  Slice('x3', 3, 16),
  Slice('x10', 10, 9),
  Slice('MINOR', 50, 4, A.badgeMinor),
  Slice('x2', 2, 20),
  Slice('x8', 8, 10),
  Slice('MAJOR', 150, 2, A.badgeMajor),
  Slice('x5', 5, 14),
  Slice('x15', 15, 6),
  Slice('GRAND', 500, 1, A.badgeGrand),
];

// Slices that are "juicy" for the cheat to weight towards.
const _fatIdx = [5, 8, 11];

class WheelBonus extends StatefulWidget {
  final int stake;
  const WheelBonus({super.key, required this.stake});

  @override
  State<WheelBonus> createState() => _WheelBonusState();
}

class _WheelBonusState extends State<WheelBonus> with TickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _rot;
  late final AnimationController _idle;
  late final AnimationController _reveal;
  final rnd = Random();
  var spinning = false;
  var done = false;
  Slice? hit;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 5200));
    _rot = const AlwaysStoppedAnimation(0);
    _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    Future<void>.delayed(const Duration(milliseconds: 700), _spin);
  }

  int _pick() {
    if (cheatOn && rnd.nextDouble() < 0.35) {
      return _fatIdx[rnd.nextInt(_fatIdx.length)];
    }
    final total = slices.fold<int>(0, (a, s) => a + s.weight);
    var u = rnd.nextInt(total);
    for (var i = 0; i < slices.length; i++) {
      u -= slices[i].weight;
      if (u < 0) return i;
    }
    return 0;
  }

  Future<void> _spin() async {
    if (spinning || done) return;
    spinning = true;
    final i = _pick();
    hit = slices[i];
    final step = 2 * pi / slices.length;
    // pointer at top. segment 0 starts at -90deg - step/2
    final land = -pi / 2 - (i + 0.5) * step;
    final turns = 7 * 2 * pi + land;
    _rot = Tween<double>(begin: 0, end: turns).animate(CurvedAnimation(
      parent: _c,
      curve: const Cubic(0.11, 0.68, 0.06, 1),
    ));
    sfx.spinWheel();
    await _c.forward(from: 0);
    sfx.wheelDone();
    sfx.buzzHard();
    setState(() {
      spinning = false;
      done = true;
    });
    _reveal.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    Navigator.pop(context, widget.stake * hit!.mult);
  }

  @override
  void dispose() {
    _c.dispose();
    _idle.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = topCutout(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0B2A4A), Color(0xFF041526), Color(0xFF020B14)],
              ),
            ),
          ),
          const SparkleField(color: C.frost),
          Padding(
            padding: EdgeInsets.fromLTRB(12, topSafe + 8, 12, 12),
            child: Column(
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'WHEEL OF MYTH',
                    maxLines: 1,
                    style: deco(
                      size: 26,
                      color: C.snow,
                      ls: 1.4,
                      shadows: const [
                        Shadow(color: Color(0xAA000000), blurRadius: 10, offset: Offset(0, 2)),
                        Shadow(color: Color(0x995AC8FF), blurRadius: 22),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0x33FFFFFF),
                    border: Border.all(color: C.frost.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Text('STAKE ${money(widget.stake)}', style: cinzel(size: 12, color: C.frost, ls: 1)),
                ),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final wheelSize = box.maxWidth * 0.98;
                    return Column(
                      children: [
                        const Spacer(flex: 3),
                        SizedBox(
                          width: box.maxWidth,
                          height: wheelSize,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              // ambient glow behind the whole wheel
                              AnimatedBuilder(
                                animation: _idle,
                                builder: (context, child) {
                                  return Container(
                                    width: wheelSize * 0.88,
                                    height: wheelSize * 0.88,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: C.frost.withValues(alpha: 0.22 + _idle.value * 0.14),
                                          blurRadius: 60,
                                          spreadRadius: 6,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              SizedBox(
                                width: wheelSize,
                                height: wheelSize,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _c,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle: _rot.value,
                                          child: child,
                                        );
                                      },
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.asset(A.wheel, fit: BoxFit.contain),
                                          CustomPaint(
                                            size: Size(wheelSize, wheelSize),
                                            painter: _LabelsPaint(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // winning wedge spotlight, fixed under the pointer
                                    if (done)
                                      AnimatedBuilder(
                                        animation: _reveal,
                                        builder: (context, child) {
                                          return CustomPaint(
                                            size: Size(wheelSize, wheelSize),
                                            painter: _SpotlightPaint(_reveal.value),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              Positioned(
                                top: -wheelSize * 0.085,
                                child: const _Pointer(),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 2),
                        _ResultPlaque(reveal: _reveal, spinning: !done, hit: hit, stake: widget.stake),
                        const Spacer(flex: 3),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPlaque extends StatelessWidget {
  final AnimationController reveal;
  final bool spinning;
  final Slice? hit;
  final int stake;

  const _ResultPlaque({required this.reveal, required this.spinning, required this.hit, required this.stake});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: (!spinning && hit != null)
              ? ScaleTransition(
                  key: const ValueKey('done'),
                  scale: CurvedAnimation(parent: reveal, curve: Curves.elasticOut),
                  child: Panel(
                    blue: true,
                    pad: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hit!.badge != null)
                          Image.asset(hit!.badge!, height: 58, fit: BoxFit.contain)
                        else
                          Text(hit!.label, style: deco(size: 26, color: C.goldPale)),
                        const SizedBox(height: 4),
                        Text('+${money(stake * hit!.mult)}', style: cinzel(size: 17, color: C.frost)),
                      ],
                    ),
                  ),
                )
              : Padding(
                  key: const ValueKey('spin'),
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('The ice decides...', style: cinzel(size: 14, color: C.frost)),
                ),
        ),
      ),
    );
  }
}

class _Pointer extends StatelessWidget {
  const _Pointer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(40, 46),
      painter: _PointerPaint(),
    );
  }
}

class _PointerPaint extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(size.width * 0.12, size.height * 0.32)
      ..quadraticBezierTo(size.width / 2, -size.height * 0.06, size.width * 0.88, size.height * 0.32)
      ..close();

    canvas.drawPath(
      body.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.goldPale, C.gold, C.goldDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = C.snow
        ..strokeWidth = 1.4,
    );

    final gem = Offset(size.width / 2, size.height * 0.28);
    canvas.drawCircle(
      gem,
      size.width * 0.15,
      Paint()
        ..shader = const RadialGradient(
          colors: [C.snow, C.frost, C.ice],
        ).createShader(Rect.fromCircle(center: gem, radius: size.width * 0.15)),
    );
    canvas.drawCircle(gem, size.width * 0.15, Paint()..style = PaintingStyle.stroke..color = C.goldDeep..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LabelsPaint extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.235;
    final step = 2 * pi / slices.length;
    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      final isBadge = s.badge != null;
      final ang = -pi / 2 + (i + 0.5) * step;
      final p = Offset(c.dx + cos(ang) * r, c.dy + sin(ang) * r);

      final tp = TextPainter(
        text: TextSpan(
          text: s.label,
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: isBadge ? 12.5 : 14,
            fontWeight: FontWeight.w800,
            color: isBadge ? const Color(0xFF3A2406) : const Color(0xFF082038),
            letterSpacing: 0.3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // keep every plaque readable (never upside-down), even on the
      // bottom half of the wheel — flip by pi when needed.
      var rot = ang + pi / 2;
      while (rot > pi / 2) {
        rot -= pi;
      }
      while (rot < -pi / 2) {
        rot += pi;
      }

      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(rot);

      final plateW = tp.width + 16;
      final plateH = tp.height + 8;
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: plateW, height: plateH),
        const Radius.circular(9),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..shader = LinearGradient(
            colors: isBadge
                ? const [Color(0xF0E6C25A), Color(0xF0B8860B)]
                : const [Color(0xE8FFFFFF), Color(0xE8DCEFFA)],
          ).createShader(plate.outerRect),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = isBadge ? const Color(0xFFFFF1C2) : const Color(0xFF7ED0F0),
      );

      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpotlightPaint extends CustomPainter {
  final double t;
  _SpotlightPaint(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final sweep = pi / 6 * (0.6 + t * 0.4);
    final start = -pi / 2 - sweep / 2;
    final rect = Rect.fromCircle(center: c, radius: size.width * 0.5);
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        transform: GradientRotation(start),
        colors: [
          C.goldPale.withValues(alpha: 0),
          C.goldPale.withValues(alpha: 0.55 * t),
          C.goldPale.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(rect)
      ..blendMode = BlendMode.plus;
    canvas.drawArc(rect, start, sweep, true, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPaint old) => old.t != t;
}
