import 'dart:math';

import 'symbols.dart';

enum Force { none, fish, wheel, big, grand }

class LineHit {
  final int line;
  final int count;
  final Sym face;
  final int pay;
  final Set<int> reels;

  LineHit(this.line, this.count, this.face, this.pay, this.reels);
}

class Outcome {
  final List<List<Sym>> grid;
  final List<LineHit> hits;
  final int payout;
  final int fishCount;
  final int glassCount;
  final bool fishBonus;
  final bool wheelBonus;

  Outcome({
    required this.grid,
    required this.hits,
    required this.payout,
    required this.fishCount,
    required this.glassCount,
    required this.fishBonus,
    required this.wheelBonus,
  });

  Set<(int, int)> get glow {
    final s = <(int, int)>{};
    for (final h in hits) {
      for (final r in h.reels) {
        s.add((r, lines[h.line][r]));
      }
    }
    return s;
  }
}

final _bag = <Sym>[
  for (final s in Sym.values)
    for (var i = 0; i < s.info.weight; i++) s,
];

class Engine {
  final rnd = Random();

  Sym pick() => _bag[rnd.nextInt(_bag.length)];

  List<List<Sym>> roll() {
    return List.generate(5, (_) => List.generate(3, (_) => pick()));
  }

  Outcome play(int bet, {Force force = Force.none}) {
    var grid = roll();
    switch (force) {
      case Force.none:
        break;
      case Force.fish:
        grid = roll();
        _plant(grid, Sym.fish, 3);
        break;
      case Force.wheel:
        grid = roll();
        _plant(grid, Sym.glass, 3);
        break;
      case Force.big:
        grid = [
          [Sym.crown, Sym.crown, pick()],
          [Sym.crown, Sym.wild, pick()],
          [Sym.crown, Sym.crown, pick()],
          [Sym.gem, Sym.crown, pick()],
          [Sym.bar, Sym.crown, pick()],
        ];
        break;
      case Force.grand:
        grid = [
          [Sym.wild, Sym.wild, Sym.gem],
          [Sym.wild, Sym.wild, Sym.crown],
          [Sym.wild, Sym.wild, Sym.wild],
          [Sym.gem, Sym.wild, Sym.bar],
          [Sym.crown, Sym.wild, Sym.bells],
        ];
        break;
    }
    return judge(grid, bet);
  }

  void _plant(List<List<Sym>> grid, Sym s, int n) {
    final spots = <(int, int)>[
      for (var r = 0; r < 5; r++)
        for (var y = 0; y < 3; y++) (r, y),
    ]..shuffle(rnd);
    for (var i = 0; i < n; i++) {
      final p = spots[i];
      grid[p.$1][p.$2] = s;
    }
  }

  Outcome judge(List<List<Sym>> grid, int bet) {
    final hits = <LineHit>[];
    var pay = 0;

    for (var li = 0; li < lines.length; li++) {
      final row = lines[li];
      final seq = [for (var r = 0; r < 5; r++) grid[r][row[r]]];
      if (seq[0].isScatter) continue;

      Sym? face;
      var n = 0;
      for (final s in seq) {
        if (s.isScatter) break;
        if (s.isWild) {
          n++;
          continue;
        }
        if (face == null) {
          face = s;
          n++;
          continue;
        }
        if (s == face) {
          n++;
          continue;
        }
        break;
      }
      face ??= n >= 3 ? Sym.wild : null;
      if (face == null || n < 3) continue;
      final mult = face.info.pay[n - 3];
      if (mult <= 0) continue;
      final won = bet * mult;
      pay += won;
      hits.add(LineHit(li, n, face, won, {for (var i = 0; i < n; i++) i}));
    }

    var fish = 0;
    var glass = 0;
    for (final col in grid) {
      for (final s in col) {
        if (s == Sym.fish) fish++;
        if (s == Sym.glass) glass++;
      }
    }

    if (fish >= 3) pay += bet * (fish == 3 ? 3 : fish == 4 ? 10 : 30);
    if (glass >= 3) pay += bet * (glass == 3 ? 3 : glass == 4 ? 10 : 30);

    return Outcome(
      grid: grid,
      hits: hits,
      payout: pay,
      fishCount: fish,
      glassCount: glass,
      fishBonus: fish >= 3,
      wheelBonus: glass >= 3,
    );
  }
}
