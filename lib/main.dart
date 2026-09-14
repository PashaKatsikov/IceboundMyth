import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'screens/boot.dart';
import 'theme.dart';
import 'wallet.dart';

void hideChrome() {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  hideChrome();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await wallet.load();
  await sfx.load();
  runApp(const IceboundApp());
}

class IceboundApp extends StatefulWidget {
  const IceboundApp({super.key});

  @override
  State<IceboundApp> createState() => _IceboundAppState();
}

class _IceboundAppState extends State<IceboundApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    hideChrome();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) hideChrome();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Icebound Myth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.burgundy,
        fontFamily: 'Cinzel',
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const BootScreen(),
    );
  }
}
