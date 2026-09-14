import 'dart:math';

import 'package:flutter/material.dart';

import '../audio.dart';
import '../cheat.dart';
import '../paths.dart';
import '../slot/engine.dart';
import '../slot/symbols.dart';
import '../theme.dart';
import '../wallet.dart';
import '../widgets/look.dart';
import 'fish_bonus.dart';
import 'settings.dart';
import 'wheel_bonus.dart';

class SlotScreen extends StatefulWidget {
  const SlotScreen({super.key});

  @override
  State<SlotScreen> createState() => _SlotScreenState();
}

class _SlotScreenState extends State<SlotScreen> {
  final engine = Engine();
  late List<List<Sym>> grid;
  var token = 0;
  var busy = false;
  var auto = false;
  var lastWin = 0;
  var banner = '';
  Set<(int, int)> glow = {};
  Force force = Force.none;
  var stopped = 0;
  // Cheat panel is hidden by default. It only appears when the player
  // taps the invisible button tucked in the bottom-right corner, and
  // hides again the moment spin (or any cheat button) is pressed.
  var showCheats = false;

  @override
  void initState() {
    super.initState();
    grid = engine.roll();
  }

  Outcome? _pending;

  Future<void> _spin() async {
    if (busy) return;
    if (!wallet.spend(wallet.bet)) {
      wallet.rescueIfBroke();
      _flash('The vault grants 8,000 coins');
      return;
    }
    _pending = engine.play(wallet.bet, force: force);
    force = Force.none;
    setState(() {
      busy = true;
      lastWin = 0;
      banner = '';
      glow = {};
      stopped = 0;
      grid = _pending!.grid;
      token++;
      showCheats = false;
    });
    sfx.buzz();
    sfx.tap();
  }

  void _reelDone() {
    if (!mounted) return;
    stopped++;
    if (stopped < 5) return;
    final out = _pending!;
    setState(() {
      glow = out.glow;
      lastWin = out.payout;
      busy = false;
    });
    if (out.payout > 0) {
      wallet.add(out.payout);
      if (out.payout >= wallet.bet * 20) {
        sfx.big();
        sfx.buzzHard();
        _flash(out.payout >= wallet.bet * 80 ? 'MYTHIC WIN' : 'BIG WIN');
      } else {
        sfx.win();
      }
    }
    _after(out);
  }

  Future<void> _after(Outcome out) async {
    if (out.fishBonus) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final extra = await Navigator.of(context).push<int>(fadeTo(FishBonus(stake: wallet.bet)));
      if (extra != null && extra > 0) {
        wallet.add(extra);
        sfx.big();
        _flash('ICE CRASH  +${money(extra)}');
      }
    }
    if (out.wheelBonus) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final extra = await Navigator.of(context).push<int>(fadeTo(WheelBonus(stake: wallet.bet)));
      if (extra != null && extra > 0) {
        wallet.add(extra);
        sfx.big();
        _flash('WHEEL  +${money(extra)}');
      }
    }
    if (auto && mounted && !busy) {
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (mounted && auto) _spin();
    }
  }

  void _flash(String t) {
    setState(() => banner = t);
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && banner == t) setState(() => banner = '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = topCutout(context);
    final size = MediaQuery.sizeOf(context);
    final h = size.height;

    return Scaffold(
      body: FillBg(
        asset: A.bg2,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Align(
                alignment: const Alignment(-0.92, 0.18),
                child: Transform.rotate(
                  angle: -0.10,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(A.joker, height: h * 0.42, fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0.94, 0.16),
                child: Transform.rotate(
                  angle: 0.10,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(A.zeus, height: h * 0.42, fit: BoxFit.contain),
                ),
              ),
            ),
            // Secret hitbox for the cheat panel — completely invisible, sits
            // under the real UI so it never steals taps from actual buttons.
            if (cheatOn)
              Positioned(
                right: 0,
                bottom: 0,
                width: 88,
                height: 88,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => showCheats = true),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(10, topSafe + 4, 10, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconOrb(icon: Icons.arrow_back, onTap: () {
                        auto = false;
                        Navigator.pop(context);
                      }),
                      const SizedBox(width: 8),
                      const CoinChip(),
                      const Spacer(),
                      IconOrb(
                        icon: Icons.settings,
                        onTap: () => Navigator.of(context).push(fadeTo(const SettingsScreen())),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 28,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: FittedBox(
                        key: ValueKey(banner + lastWin.toString()),
                        fit: BoxFit.scaleDown,
                        child: Text(
                          banner.isEmpty
                              ? (lastWin > 0 ? 'WIN  ${money(lastWin)}' : 'ICEBOUND MYTH')
                              : banner,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: deco(size: banner.isEmpty ? 15 : 18, color: C.goldPale, ls: 0.8),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Cabinet(
                    child: _Board(
                      grid: grid,
                      token: token,
                      glow: glow,
                      onReelDone: _reelDone,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _controls(),
                  if (cheatOn)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SizeTransition(sizeFactor: anim, child: child),
                      ),
                      child: showCheats ? _cheats() : const SizedBox(width: double.infinity, key: ValueKey('hidden')),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    return Column(
      children: [
        Row(
          children: [
            IconOrb(
              icon: Icons.remove,
              size: 40,
              onTap: busy ? () {} : () => wallet.bumpBet(-1),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: wallet,
                builder: (context, child) => Container(
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xCC1A0508),
                    border: Border.all(color: C.gold, width: 1.2),
                  ),
                  child: Text('BET ${money(wallet.bet)}', style: cinzel(size: 14, ls: 0.4)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconOrb(
              icon: Icons.add,
              size: 40,
              onTap: busy ? () {} : () => wallet.bumpBet(1),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => setState(() => auto = !auto),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: auto ? C.hot : C.gold),
                  color: auto ? const Color(0x66C41E3A) : const Color(0x661A0508),
                ),
                child: Text('AUTO', style: cinzel(size: 12, ls: 0.4, color: auto ? C.blush : C.gold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GoldBtn(
          label: busy ? '...' : 'SPIN',
          height: 56,
          width: 220,
          size: 22,
          pulse: !busy,
          onTap: busy ? null : _spin,
        ),
      ],
    );
  }

  Widget _cheats() {
    Widget chip(String t, Force f) {
      return Padding(
        padding: const EdgeInsets.only(right: 6, top: 4),
        child: GestureDetector(
          onTap: () {
            force = f;
            if (!busy) _spin();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xAA000000),
              border: Border.all(color: C.goldDeep),
            ),
            child: Text(t, style: cinzel(size: 10, color: C.goldPale)),
          ),
        ),
      );
    }

    return Wrap(
      children: [
        chip('FISH', Force.fish),
        chip('WHEEL', Force.wheel),
        chip('BIG', Force.big),
        chip('GRAND', Force.grand),
        Padding(
          padding: const EdgeInsets.only(right: 6, top: 4),
          child: GestureDetector(
            onTap: () {
              wallet.add(25000);
              sfx.win();
              setState(() => showCheats = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xAA000000),
                border: Border.all(color: C.goldDeep),
              ),
              child: Text('+COINS', style: cinzel(size: 10, color: C.goldPale)),
            ),
          ),
        ),
      ],
    );
  }
}

class _Board extends StatelessWidget {
  final List<List<Sym>> grid;
  final int token;
  final Set<(int, int)> glow;
  final VoidCallback onReelDone;

  const _Board({
    required this.grid,
    required this.token,
    required this.glow,
    required this.onReelDone,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 5 / 3.15,
      child: LayoutBuilder(builder: (context, box) {
        final cell = box.maxHeight / 3;
        return DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xCC140204)),
          child: Row(
            children: [
              for (var r = 0; r < 5; r++) ...[
                if (r > 0) const VerticalDivider(width: 1, thickness: 1, color: Color(0x66E6C25A)),
                Expanded(
                  child: _Reel(
                    key: ValueKey('reel$r'),
                    land: grid[r],
                    token: token,
                    delay: Duration(milliseconds: 140 * r),
                    cell: cell,
                    glowRows: {for (final g in glow) if (g.$1 == r) g.$2},
                    onDone: onReelDone,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _Reel extends StatefulWidget {
  final List<Sym> land;
  final int token;
  final Duration delay;
  final double cell;
  final Set<int> glowRows;
  final VoidCallback onDone;

  const _Reel({
    super.key,
    required this.land,
    required this.token,
    required this.delay,
    required this.cell,
    required this.glowRows,
    required this.onDone,
  });

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late Animation<double> _anim;
  late List<Sym> strip;
  late List<Sym> shown;
  final rnd = Random();
  var lastToken = 0;

  @override
  void initState() {
    super.initState();
    shown = [...widget.land];
    strip = [...shown];
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _anim = const AlwaysStoppedAnimation(0);
  }

  @override
  void didUpdateWidget(covariant _Reel old) {
    super.didUpdateWidget(old);
    if (widget.token != lastToken && widget.token != 0) {
      lastToken = widget.token;
      _go();
    }
  }

  Future<void> _go() async {
    final pad = 22 + rnd.nextInt(6);
    _c.stop();
    _c.reset();
    strip = [
      ...shown,
      for (var i = 0; i < pad; i++) Sym.values[rnd.nextInt(Sym.values.length)],
      ...widget.land,
    ];
    final end = (strip.length - 3) * widget.cell;
    _anim = Tween<double>(begin: 0, end: end).animate(CurvedAnimation(
      parent: _c,
      curve: const Cubic(0.15, 0.75, 0.12, 1),
    ));
    _c.duration = Duration(milliseconds: 1500 + widget.delay.inMilliseconds);
    if (mounted) setState(() {});
    await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    await _c.forward(from: 0);
    shown = [...widget.land];
    if (mounted) widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          return Stack(
            children: [
              OverflowBox(
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: Offset(0, -_anim.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < strip.length; i++)
                        SizedBox(
                          height: widget.cell,
                          width: double.infinity,
                          child: _cell(strip[i], false),
                        ),
                    ],
                  ),
                ),
              ),
              if (!_c.isAnimating && widget.glowRows.isNotEmpty)
                for (final y in widget.glowRows)
                  Positioned(
                    top: y * widget.cell,
                    left: 2,
                    right: 2,
                    height: widget.cell,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.goldPale, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0xAAE6C25A), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _cell(Sym s, bool hot) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Image.asset(s.art, fit: BoxFit.contain),
    );
  }
}
