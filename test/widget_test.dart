import 'package:flutter_test/flutter_test.dart';
import 'package:iceboundmythgame/slot/engine.dart';
import 'package:iceboundmythgame/slot/symbols.dart';

void main() {
  test('five wilds on a line pays the wild jackpot', () {
    final grid = List.generate(5, (_) => [Sym.cherry, Sym.wild, Sym.lemon]);
    final out = Engine().judge(grid, 100);
    expect(out.payout, greaterThanOrEqualTo(100 * 250));
    expect(out.hits, isNotEmpty);
  });

  test('three fish trip the crash bonus', () {
    final grid = [
      [Sym.fish, Sym.cherry, Sym.lemon],
      [Sym.banana, Sym.fish, Sym.bar],
      [Sym.gem, Sym.crown, Sym.fish],
      [Sym.bells, Sym.lolly, Sym.melon],
      [Sym.grapes, Sym.bar, Sym.cherry],
    ];
    final out = Engine().judge(grid, 100);
    expect(out.fishBonus, isTrue);
    expect(out.wheelBonus, isFalse);
  });
}
