import 'dart:io';

import 'package:image/image.dart' as img;

/// Builds 1024×1024 launcher assets from `assets/brand/icon2.jpg`.
///
/// Adaptive canvas is 108 dp. Foreground inset of 16 % leaves
/// 108 × (1 − 0.32) ≈ 73.4 dp of artwork — the requested 74 dp.
/// This script only prepares full-bleed source PNGs; the inset is
/// applied later by `flutter_launcher_icons`.
void main() {
  final File srcFile = File('assets/brand/icon2.jpg');
  if (!srcFile.existsSync()) {
    stderr.writeln('missing ${srcFile.path}');
    exit(1);
  }
  final img.Image? decoded = img.decodeImage(srcFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('could not decode ${srcFile.path}');
    exit(1);
  }

  const int canvas = 1024;
  final int side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final img.Image square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final img.Image full = img.copyResize(
    square,
    width: canvas,
    height: canvas,
    interpolation: img.Interpolation.cubic,
  );

  File('assets/brand/app_icon.png').writeAsBytesSync(img.encodePng(full));
  File('assets/brand/app_icon_background.png').writeAsBytesSync(img.encodePng(full));
  stdout.writeln('wrote assets/brand/app_icon.png and app_icon_background.png');
}
