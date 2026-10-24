// Renders the app icon PNGs from LogoPainter. Run after changing the logo:
//
//   flutter test tool/render_logo_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:power_couple/ui/logo.dart';

Future<void> _render(LogoPainter painter, String path) async {
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size.square(1024));
  final image = await recorder.endRecording().toImage(1024, 1024);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('render app icons', () async {
    // Full icon (iOS, legacy Android, web).
    await _render(const LogoPainter(), 'assets/icon/icon.png');
    // Android adaptive foreground: transparent, mark kept in the safe zone.
    await _render(const LogoPainter(background: false, inset: 0.3), 'assets/icon/foreground.png');
  });
}
