enum Sym {
  cherry,
  lemon,
  banana,
  grapes,
  melon,
  lolly,
  bells,
  bar,
  gem,
  crown,
  wild,
  fish,
  glass,
}

class SymInfo {
  final String file;
  final String title;
  final int weight;
  final List<int> pay; // 3 / 4 / 5 of a kind, times bet
  final bool wild;
  final String? bonus;

  const SymInfo({
    required this.file,
    required this.title,
    required this.weight,
    required this.pay,
    this.wild = false,
    this.bonus,
  });
}

const book = {
  Sym.cherry: SymInfo(file: 'assets/symbols/cherry.webp', title: 'Cherry', weight: 16, pay: [2, 6, 18]),
  Sym.lemon: SymInfo(file: 'assets/symbols/lemon.webp', title: 'Lemon', weight: 15, pay: [2, 7, 20]),
  Sym.banana: SymInfo(file: 'assets/symbols/banana.webp', title: 'Banana', weight: 14, pay: [3, 8, 22]),
  Sym.grapes: SymInfo(file: 'assets/symbols/grapes.webp', title: 'Grapes', weight: 13, pay: [3, 9, 25]),
  Sym.melon: SymInfo(file: 'assets/symbols/watermelon.webp', title: 'Melon', weight: 12, pay: [4, 12, 30]),
  Sym.lolly: SymInfo(file: 'assets/symbols/lollipop.webp', title: 'Lollipop', weight: 10, pay: [5, 15, 40]),
  Sym.bells: SymInfo(file: 'assets/symbols/bells.webp', title: 'Bells', weight: 9, pay: [6, 18, 50]),
  Sym.bar: SymInfo(file: 'assets/symbols/bar.webp', title: 'BAR', weight: 8, pay: [8, 25, 70]),
  Sym.gem: SymInfo(file: 'assets/symbols/gem_red.webp', title: 'Ruby', weight: 6, pay: [10, 35, 100]),
  Sym.crown: SymInfo(file: 'assets/symbols/crown.webp', title: 'Crown', weight: 5, pay: [15, 50, 150]),
  Sym.wild: SymInfo(file: 'assets/symbols/joker_head.webp', title: 'Joker Wild', weight: 4, pay: [25, 80, 250], wild: true),
  Sym.fish: SymInfo(file: 'assets/symbols/fish_red.webp', title: 'Myth Fish', weight: 5, pay: [0, 0, 0], bonus: 'fish'),
  Sym.glass: SymInfo(file: 'assets/symbols/hourglass.webp', title: 'Fate Glass', weight: 5, pay: [0, 0, 0], bonus: 'wheel'),
};

extension SymX on Sym {
  SymInfo get info => book[this]!;
  String get art => info.file;
  bool get isWild => info.wild;
  bool get isScatter => info.bonus != null;
}

const lines = [
  [1, 1, 1, 1, 1],
  [0, 0, 0, 0, 0],
  [2, 2, 2, 2, 2],
  [0, 1, 2, 1, 0],
  [2, 1, 0, 1, 2],
];
