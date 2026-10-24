import 'package:flutter/material.dart';

import 'common.dart';

/// The Power Couple mark: two chunky hearts leaning into each other with a
/// lightning bolt across them. Drawn on a 1024×1024 grid and scaled, so the
/// same painter renders the app icon (tool/render_logo.dart) and in-app logo.
class LogoPainter extends CustomPainter {
  const LogoPainter({this.background = true, this.inset = 0});

  /// Paint the purple square behind the mark (off for adaptive-icon layers).
  final bool background;

  /// Shrinks the mark toward the centre, as a fraction of the size
  /// (Android adaptive icons need the mark inside the middle ~66%).
  final double inset;

  static const _bg = Vivid.grape;
  static const _bgGlow = Color(0xFFAA74FA);
  static const _left = Vivid.berry;
  static const _right = Vivid.sun;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 1024;
    canvas.save();
    canvas.scale(s);

    if (background) {
      canvas.drawRect(const Rect.fromLTWH(0, 0, 1024, 1024), Paint()..color = _bg);
      canvas.drawCircle(const Offset(300, 260), 560, Paint()..color = _bgGlow.withValues(alpha: 0.55));
      canvas.drawCircle(const Offset(300, 260), 340, Paint()..color = _bgGlow.withValues(alpha: 0.45));
    }

    if (inset > 0) {
      canvas.translate(512, 512);
      canvas.scale(1 - inset);
      canvas.translate(-512, -512);
    }

    _heart(canvas, center: const Offset(374, 520), size: 450, angle: -0.22, color: _left);
    _heart(canvas, center: const Offset(650, 520), size: 450, angle: 0.22, color: _right);
    _bolt(canvas, center: const Offset(512, 540), height: 500);

    canvas.restore();
  }

  /// Heart in a unit box, point at the bottom.
  static Path _heartPath() => Path()
    ..moveTo(0.5, 0.95)
    ..cubicTo(0.30, 0.80, 0.02, 0.60, 0.02, 0.34)
    ..cubicTo(0.02, 0.15, 0.17, 0.03, 0.32, 0.03)
    ..cubicTo(0.41, 0.03, 0.47, 0.08, 0.5, 0.15)
    ..cubicTo(0.53, 0.08, 0.59, 0.03, 0.68, 0.03)
    ..cubicTo(0.83, 0.03, 0.98, 0.15, 0.98, 0.34)
    ..cubicTo(0.98, 0.60, 0.70, 0.80, 0.5, 0.95)
    ..close();

  void _heart(Canvas canvas, {required Offset center, required double size, required double angle, required Color color}) {
    final unit = _heartPath();
    Path placed(double dy) {
      final m = Matrix4.identity()
        ..translateByDouble(center.dx, center.dy + dy, 0, 1)
        ..rotateZ(angle)
        ..scaleByDouble(size, size * 1.12, 1, 1)
        ..translateByDouble(-0.5, -0.5, 0, 1);
      return unit.transform(m.storage);
    }

    // Soft drop shadow, darker edge, then the face.
    canvas.drawPath(placed(46), Paint()..color = Colors.black.withValues(alpha: 0.14));
    canvas.drawPath(placed(26), Paint()..color = Vivid.shadeOf(color));
    canvas.drawPath(placed(0), Paint()..color = color);

    // Glossy highlight on the outer upper lobe.
    final side = angle < 0 ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final hl = Paint()..color = Colors.white.withValues(alpha: 0.38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(side * size * 0.25, -size * 0.25), width: size * 0.17, height: size * 0.09),
          Radius.circular(size * 0.05)),
      hl,
    );
    canvas.drawCircle(Offset(side * size * 0.36, -size * 0.15), size * 0.035, hl);
    canvas.restore();
  }

  void _bolt(Canvas canvas, {required Offset center, required double height}) {
    const pts = [
      Offset(0.64, 0.00),
      Offset(0.14, 0.58),
      Offset(0.46, 0.58),
      Offset(0.34, 1.00),
      Offset(0.88, 0.38),
      Offset(0.55, 0.38),
      Offset(0.72, 0.00),
    ];
    final w = height * 0.74;
    Path at(double dy) => Path()
      ..addPolygon([
        for (final p in pts) Offset(center.dx - w / 2 + p.dx * w, center.dy - height / 2 + p.dy * height + dy),
      ], true);

    final join = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 28;
    // Purple outline ties the bolt to the background, then edge and face.
    canvas.drawPath(at(24), Paint()..color = Colors.black.withValues(alpha: 0.14));
    canvas.drawPath(at(18), join..color = Vivid.grapeShade);
    canvas.drawPath(at(18), Paint()..color = Vivid.grapeShade);
    canvas.drawPath(at(0), join..color = Vivid.grapeShade);
    canvas.drawPath(at(0), Paint()..color = Colors.white);
    // Inner light strip for a bit of shine.
    canvas.save();
    canvas.clipPath(at(0));
    canvas.drawRect(
      Rect.fromLTWH(center.dx - w / 2, center.dy - height / 2, w * 0.42, height),
      Paint()..color = const Color(0xFFF1ECFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.background != background || old.inset != inset;
}

/// The logo as a widget, with iOS-style rounded corners.
class PowerCoupleLogo extends StatelessWidget {
  const PowerCoupleLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.23),
          boxShadow: [
            BoxShadow(color: Vivid.grapeShade, offset: Offset(0, size * 0.05)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.23),
          child: CustomPaint(painter: const LogoPainter(), size: Size.square(size)),
        ),
      );
}
