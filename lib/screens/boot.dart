import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../paths.dart';
import '../theme.dart';
import '../widgets/look.dart';
import 'menu.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with SingleTickerProviderStateMixin {
  var _t = 0.0;
  late final AnimationController _shine;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final started = DateTime.now();
    final imgs = A.images;
    for (var i = 0; i < imgs.length; i++) {
      if (!mounted) return;
      try {
        await precacheImage(AssetImage(imgs[i]), context);
      } catch (_) {}
      setState(() => _t = (i + 1) / imgs.length);
    }
    final wait = const Duration(milliseconds: 1700) - DateTime.now().difference(started);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(fadeTo(const MenuScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewPadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: OrientationBuilder(
          builder: (context, o) {
            final land = o == Orientation.landscape;
            return SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: Image.asset(land ? A.loadingH : A.loadingV, fit: BoxFit.cover),
                  ),
                  AnimatedBuilder(
                    animation: _shine,
                    builder: (context, child) => Align(
                      alignment: land ? const Alignment(0, 0.86) : const Alignment(0, 0.90),
                      child: LoadBar(t: _t, wide: land),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
