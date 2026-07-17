// One-off launcher-icon renderer. Not named *_test.dart on purpose - it
// writes files, so it must never run in a normal `flutter test` sweep.
//
// The app's logo only exists as vector code (_LogoPainter in
// lib/widgets/app_header.dart); the paths below are copied from it 1:1.
// Run manually whenever the logo changes, then re-run the generator:
//
//   flutter test test/tools/render_app_icon.dart
//   dart run flutter_launcher_icons
//
// Outputs (consumed by the flutter_launcher_icons config in pubspec.yaml):
//   assets/icon/app_icon.png            1024px, #0A0A0A bg (iOS + legacy Android)
//   assets/icon/app_icon_foreground.png 1024px, transparent (Android adaptive)

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Path _logoPath(double w, double h) {
  final aPath = Path()
    ..moveTo(w * 0.42, h * 0.18)
    ..lineTo(w * 0.58, h * 0.14)
    ..lineTo(w * 0.74, h * 0.8)
    ..lineTo(w * 0.62, h * 0.84)
    ..lineTo(w * 0.57, h * 0.62)
    ..lineTo(w * 0.38, h * 0.68)
    ..lineTo(w * 0.28, h * 0.88)
    ..lineTo(w * 0.14, h * 0.82)
    ..close();

  final slashPath = Path()
    ..moveTo(w * 0.25, h * 0.43)
    ..quadraticBezierTo(w * 0.48, h * 0.5, w * 0.78, h * 0.33)
    ..lineTo(w * 0.83, h * 0.42)
    ..quadraticBezierTo(w * 0.52, h * 0.62, w * 0.18, h * 0.53)
    ..close();

  final starPath = Path()
    ..moveTo(w * 0.2, h * 0.37)
    ..lineTo(w * 0.28, h * 0.46)
    ..lineTo(w * 0.18, h * 0.54)
    ..lineTo(w * 0.12, h * 0.43)
    ..lineTo(w * 0.02, h * 0.4)
    ..lineTo(w * 0.13, h * 0.34)
    ..lineTo(w * 0.17, h * 0.22)
    ..close();

  return Path()
    ..addPath(aPath, Offset.zero)
    ..addPath(slashPath, Offset.zero)
    ..addPath(starPath, Offset.zero);
}

Future<void> _render({
  required String outFile,
  required int canvasSize,
  required double logoFraction,
  Color? background,
}) async {
  final size = canvasSize.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (background != null) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size, size),
      Paint()..color = background,
    );
  }

  // The painter's unit square isn't visually centered (the drawn shapes span
  // roughly x 0.02-0.83), so center by the path's real bounds, not the square.
  final logoSide = size * logoFraction;
  final path = _logoPath(logoSide, logoSide);
  final bounds = path.getBounds();
  canvas.translate(
    size / 2 - bounds.center.dx,
    size / 2 - bounds.center.dy,
  );
  canvas.drawPath(path, Paint()..color = Colors.white);

  final image = await recorder.endRecording().toImage(canvasSize, canvasSize);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(outFile)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render launcher icon PNGs from the in-app logo', () async {
    // Full icon: logo at ~62% of the canvas leaves the padding a launcher
    // tile expects. Background matches AppTheme.black (#0A0A0A).
    await _render(
      outFile: 'assets/icon/app_icon.png',
      canvasSize: 1024,
      logoFraction: 0.62,
      background: const Color(0xFF0A0A0A),
    );

    // Adaptive foreground: Android may mask everything outside the central
    // 66/108 (~61%) safe zone, so keep the logo within ~52% of the canvas.
    await _render(
      outFile: 'assets/icon/app_icon_foreground.png',
      canvasSize: 1024,
      logoFraction: 0.52,
    );

    expect(File('assets/icon/app_icon.png').existsSync(), isTrue);
    expect(File('assets/icon/app_icon_foreground.png').existsSync(), isTrue);
  });
}
