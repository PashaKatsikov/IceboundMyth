import 'dart:math';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../theme.dart';
import '../wallet.dart';

class FillBg extends StatelessWidget {
  final String asset;
  final Widget child;
  final bool blue;

  const FillBg({super.key, required this.asset, required this.child, this.blue = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(asset, fit: BoxFit.cover),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: blue
                  ? [
                      const Color(0x66031528),
                      const Color(0x88041530),
                      const Color(0xCC021018),
                    ]
                  : [
                      const Color(0x66000000),
                      const Color(0x33000000),
                      const Color(0x99000000),
                    ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class GoldBtn extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final double height;
  final double? width;
  final double size;
  final bool pulse;
  final bool blue;

  const GoldBtn({
    super.key,
    required this.label,
    this.onTap,
    this.height = 52,
    this.width,
    this.size = 18,
    this.pulse = false,
    this.blue = false,
  });

  @override
  State<GoldBtn> createState() => _GoldBtnState();
}

class _GoldBtnState extends State<GoldBtn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  var _down = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant GoldBtn old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.pulse) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.blue ? C.frost : C.hot;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final p = widget.pulse ? 0.35 + _c.value * 0.65 : 0.7;
        return GestureDetector(
          onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
          onTapUp: widget.onTap == null
              ? null
              : (_) {
                  setState(() => _down = false);
                  sfx.tap();
                  sfx.buzz();
                  widget.onTap!();
                },
          onTapCancel: () => setState(() => _down = false),
          child: Transform.scale(
            scale: _down ? 0.96 : 1,
            child: Container(
              height: widget.height,
              width: widget.width,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    C.goldPale,
                    C.gold,
                    C.goldDeep,
                    C.bronze,
                  ],
                ),
                border: Border.all(color: C.goldPale.withValues(alpha: 0.85), width: 1.4),
                boxShadow: [
                  BoxShadow(color: glow.withValues(alpha: 0.28 * p), blurRadius: 18, spreadRadius: 1),
                  BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: cinzel(size: widget.size, color: C.ink, ls: 0.6),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class CoinChip extends StatelessWidget {
  const CoinChip({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: wallet,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xEE3A0810), Color(0xEE1A0206)],
            ),
            border: Border.all(color: C.gold, width: 1.3),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _CoinDot(),
              const SizedBox(width: 8),
              Text(money(wallet.coins), style: cinzel(size: 16, color: C.goldPale)),
            ],
          ),
        );
      },
    );
  }
}

class _CoinDot extends StatelessWidget {
  const _CoinDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.goldPale, C.goldDeep],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: C.ink.withValues(alpha: 0.5), width: 1),
        ),
      ),
    );
  }
}

class IconOrb extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;

  const IconOrb({super.key, required this.icon, required this.onTap, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        sfx.tap();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [C.gold, C.goldDeep, C.bronze],
          ),
          border: Border.all(color: C.goldPale, width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Icon(icon, color: C.ink, size: size * 0.52),
      ),
    );
  }
}

class LoadBar extends StatelessWidget {
  final double t;
  final bool wide;

  const LoadBar({super.key, required this.t, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = wide ? box.maxWidth * 0.62 : box.maxWidth * 0.78;
      final pct = (t * 100).clamp(0, 100).round();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xDD140204),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.gold, width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              '$pct%',
              style: cinzel(size: 20, color: C.cream, w: FontWeight.w700).copyWith(
                height: 1.0,
                shadows: const [
                  Shadow(color: Color(0xFF000000), blurRadius: 6, offset: Offset(0, 1)),
                  Shadow(color: Color(0xFF000000), blurRadius: 2),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: w,
            height: 22,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [C.goldPale, C.goldDeep]),
              boxShadow: const [
                BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Stack(
                children: [
                  const ColoredBox(color: Color(0xFF1A0508)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: t.clamp(0.0, 1.0),
                      heightFactor: 1,
                      alignment: Alignment.centerLeft,
                      child: const SizedBox.expand(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7A1020), C.hot, C.gold, C.hot],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _BarShine(t)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _BarShine extends CustomPainter {
  final double t;
  _BarShine(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final x = (t * 1.4 % 1.0) * size.width;
    final p = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(x - 30, 0, 60, size.height));
    canvas.drawRect(Rect.fromLTWH(x - 30, 0, 60, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _BarShine old) => old.t != t;
}

class Panel extends StatelessWidget {
  final Widget child;
  final bool blue;
  final EdgeInsets pad;

  const Panel({
    super.key,
    required this.child,
    this.blue = false,
    this.pad = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: blue
              ? const [Color(0xEE0A2744), Color(0xEE041526)]
              : const [Color(0xEE4A1018), Color(0xEE1A0508)],
        ),
        border: Border.all(color: C.gold.withValues(alpha: 0.85), width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}

class Cabinet extends StatelessWidget {
  final Widget child;
  const Cabinet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CabinetPaint(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        child: child,
      ),
    );
  }
}

class _CabinetPaint extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromLTRBR(7, 7, size.width - 7, size.height - 7, const Radius.circular(18));
    canvas.drawRRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A0A10), Color(0xFF140204)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.goldPale, C.gold, C.goldDeep, C.goldPale],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      r.deflate(6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = C.crimson,
    );
    canvas.drawRRect(
      r.deflate(9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = C.gold.withValues(alpha: 0.7),
    );

    final jewel = Paint()
      ..shader = const RadialGradient(
        colors: [C.hot, C.crimson, C.velvet],
      ).createShader(const Rect.fromLTWH(0, 0, 14, 14));
    for (final p in [
      Offset(10, 10),
      Offset(size.width - 10, 10),
      Offset(10, size.height - 10),
      Offset(size.width - 10, size.height - 10),
    ]) {
      canvas.drawCircle(p, 5, jewel);
      canvas.drawCircle(p, 5, Paint()..style = PaintingStyle.stroke..color = C.gold..strokeWidth = 1);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SparkleField extends StatefulWidget {
  final Color color;
  const SparkleField({super.key, this.color = C.gold});

  @override
  State<SparkleField> createState() => _SparkleFieldState();
}

class _SparkleFieldState extends State<SparkleField> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _dots = <Offset>[];
  final _rnd = Random(7);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    for (var i = 0; i < 18; i++) {
      _dots.add(Offset(_rnd.nextDouble(), _rnd.nextDouble()));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return CustomPaint(
            painter: _SparklePaint(_dots, _c.value, widget.color),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _SparklePaint extends CustomPainter {
  final List<Offset> dots;
  final double t;
  final Color color;
  _SparklePaint(this.dots, this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < dots.length; i++) {
      final o = dots[i];
      final a = 0.15 + 0.55 * (0.5 + 0.5 * sin((t + i * 0.17) * pi * 2));
      canvas.drawCircle(
        Offset(o.dx * size.width, o.dy * size.height),
        1.2 + (i % 3).toDouble(),
        Paint()..color = color.withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePaint old) => old.t != t;
}
