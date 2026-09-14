import 'package:flutter/material.dart';

class C {
  static const burgundy = Color(0xFF2A0408);
  static const velvet = Color(0xFF4A0A12);
  static const crimson = Color(0xFF9B1B2E);
  static const hot = Color(0xFFE23A4A);
  static const blush = Color(0xFFFF8A93);

  static const goldPale = Color(0xFFFFF1C2);
  static const gold = Color(0xFFE6C25A);
  static const goldDeep = Color(0xFFB8860B);
  static const bronze = Color(0xFF6B4308);

  static const ink = Color(0xFF140204);
  static const cream = Color(0xFFFFF6E4);

  static const navy = Color(0xFF041526);
  static const ice = Color(0xFF14507A);
  static const frost = Color(0xFF7ED0F0);
  static const snow = Color(0xFFE8F7FF);
}

double topCutout(BuildContext context) {
  final cut = MediaQueryData.fromView(View.of(context));
  final top = cut.viewPadding.top > cut.padding.top ? cut.viewPadding.top : cut.padding.top;
  return top < 48 ? 48 : top;
}

String money(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  if (n < 0) buf.write('-');
  for (var i = 0; i < s.length; i++) {
    if (i != 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

TextStyle deco({
  double size = 22,
  Color color = C.goldPale,
  FontWeight w = FontWeight.w700,
  double ls = 1.2,
  List<Shadow>? shadows,
}) {
  return TextStyle(
    fontFamily: 'CinzelDeco',
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: ls,
    height: 1.05,
    shadows: shadows ??
        const [
          Shadow(color: Color(0xAA000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
  );
}

TextStyle cinzel({
  double size = 16,
  Color color = C.goldPale,
  FontWeight w = FontWeight.w600,
  double ls = 0.8,
}) {
  return TextStyle(
    fontFamily: 'Cinzel',
    fontSize: size,
    fontWeight: w,
    color: color,
    letterSpacing: ls,
    height: 1.15,
    shadows: const [
      Shadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 1)),
    ],
  );
}

Route<T> fadeTo<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondary) => page,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
