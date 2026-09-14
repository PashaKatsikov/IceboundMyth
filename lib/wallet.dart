import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

final wallet = Wallet();

class Wallet extends ChangeNotifier {
  static const startCoins = 25000;
  static const minBet = 50;
  static const bets = [50, 100, 250, 500, 1000, 2500];

  int coins = startCoins;
  int bet = 100;
  bool sound = true;
  bool haptic = true;
  int lastDaily = 0;
  int lastVault = 0;

  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    coins = _p!.getInt('coins') ?? startCoins;
    bet = _p!.getInt('bet') ?? 100;
    sound = _p!.getBool('sound') ?? true;
    haptic = _p!.getBool('haptic') ?? true;
    lastDaily = _p!.getInt('lastDaily') ?? 0;
    lastVault = _p!.getInt('lastVault') ?? 0;
    if (!bets.contains(bet)) bet = 100;
    notifyListeners();
  }

  void _save() {
    final p = _p;
    if (p == null) return;
    p.setInt('coins', coins);
    p.setInt('bet', bet);
    p.setBool('sound', sound);
    p.setBool('haptic', haptic);
    p.setInt('lastDaily', lastDaily);
    p.setInt('lastVault', lastVault);
  }

  void add(int n) {
    coins += n;
    _save();
    notifyListeners();
  }

  bool spend(int n) {
    if (coins < n) return false;
    coins -= n;
    _save();
    notifyListeners();
    return true;
  }

  void setBet(int v) {
    bet = v;
    _save();
    notifyListeners();
  }

  void bumpBet(int dir) {
    final i = bets.indexOf(bet);
    final next = (i + dir).clamp(0, bets.length - 1);
    setBet(bets[next]);
  }

  void setSound(bool v) {
    sound = v;
    _save();
    notifyListeners();
  }

  void setHaptic(bool v) {
    haptic = v;
    _save();
    notifyListeners();
  }

  bool get dailyReady {
    final now = DateTime.now();
    final last = DateTime.fromMillisecondsSinceEpoch(lastDaily);
    return last.year != now.year || last.month != now.month || last.day != now.day;
  }

  int claimDaily() {
    if (!dailyReady) return 0;
    lastDaily = DateTime.now().millisecondsSinceEpoch;
    add(2500);
    return 2500;
  }

  bool get vaultReady {
    if (lastVault == 0) return true;
    return DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastVault)).inMinutes >= 30;
  }

  int claimVault() {
    if (!vaultReady) return 0;
    lastVault = DateTime.now().millisecondsSinceEpoch;
    add(1500);
    return 1500;
  }

  void rescueIfBroke() {
    if (coins < minBet) add(8000);
  }
}
