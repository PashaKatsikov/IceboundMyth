import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

import 'paths.dart';
import 'wallet.dart';

final sfx = Sfx();

class Sfx {
  final _pool = <String, AudioPlayer>{};

  Future<void> load() async {
    for (final p in [
      A.click,
      A.confirm,
      A.fail,
      A.menuOpen,
      A.reward,
      A.victory,
      A.wheelSpin,
      A.wheelResult,
    ]) {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      _pool[p] = player;
    }
  }

  Future<void> play(String asset) async {
    if (!wallet.sound) return;
    final p = _pool[asset];
    if (p == null) return;
    try {
      await p.stop();
      await p.play(AssetSource(asset.replaceFirst('assets/', '')));
    } catch (_) {}
  }

  void tap() => play(A.click);
  void ok() => play(A.confirm);
  void win() => play(A.reward);
  void big() => play(A.victory);
  void lose() => play(A.fail);
  void open() => play(A.menuOpen);
  void spinWheel() => play(A.wheelSpin);
  void wheelDone() => play(A.wheelResult);

  void buzz() {
    if (wallet.haptic) HapticFeedback.mediumImpact();
  }

  void buzzHard() {
    if (wallet.haptic) HapticFeedback.heavyImpact();
  }
}
