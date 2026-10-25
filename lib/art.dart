import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn (vector) scenery: a temple tower (gopuram), sun, birds.
/// Drawn by code, so it adds nothing to the APK size and stays sharp on every screen.

/// Draws one gopuram standing on [baseY], centred at [cx], [h] tall.
void drawGopuram(Canvas canvas, double cx, double baseY, double h, Color color) {
  final w0 = h * 0.78;
  var path = Path();
  final windows = Path();

  // platform
  path.addRect(Rect.fromLTWH(cx - w0 * 0.62, baseY - h * 0.06, w0 * 1.24, h * 0.06));
  var y = baseY - h * 0.06;

  const tiers = 7;
  final th = h * 0.105;
  for (var i = 0; i < tiers; i++) {
    final t = i / (tiers - 1);
    final w = w0 * (1.0 - 0.62 * t);
    // tier body
    path.addRect(Rect.fromLTWH(cx - w / 2, y - th, w, th));
    // overhanging ledge
    path.addRect(Rect.fromLTWH(cx - w * 0.54, y - th - h * 0.014, w * 1.08, h * 0.014));
    // little windows
    final n = math.max(1, (w / (h * 0.11)).floor());
    final gap = w / (n + 1);
    for (var k = 1; k <= n; k++) {
      final wx = cx - w / 2 + gap * k;
      windows.addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(wx, y - th * 0.52), width: h * 0.035, height: th * 0.5),
          Radius.circular(h * 0.018)));
    }
    y -= th + h * 0.014;
  }

  // barrel roof
  final topW = w0 * 0.38;
  final roof = Path()
    ..moveTo(cx - topW * 0.5, y)
    ..quadraticBezierTo(cx - topW * 0.5, y - h * 0.11, cx, y - h * 0.11)
    ..quadraticBezierTo(cx + topW * 0.5, y - h * 0.11, cx + topW * 0.5, y)
    ..close();
  path = Path.combine(PathOperation.union, path, roof);

  // kalasam (golden pots) on the roof
  final kTop = y - h * 0.11;
  for (var k = -1; k <= 1; k++) {
    final kx = cx + k * topW * 0.28;
    final kh = k == 0 ? h * 0.075 : h * 0.05;
    path.addOval(Rect.fromCenter(center: Offset(kx, kTop - kh * 0.4), width: h * 0.028, height: kh));
    path.addRect(Rect.fromLTWH(kx - h * 0.003, kTop - kh * 1.0, h * 0.006, kh * 0.5));
  }

  final cut = Path.combine(PathOperation.difference, path, windows);
  canvas.drawPath(cut, Paint()..color = color);
}

void _birds(Canvas canvas, Size s, Color color) {
  final p = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  void bird(double x, double y, double r) {
    final path = Path()
      ..moveTo(x - r, y)
      ..quadraticBezierTo(x - r * 0.5, y - r * 0.7, x, y)
      ..quadraticBezierTo(x + r * 0.5, y - r * 0.7, x + r, y);
    canvas.drawPath(path, p);
  }

  bird(s.width * 0.56, s.height * 0.24, 7);
  bird(s.width * 0.64, s.height * 0.16, 5);
  bird(s.width * 0.50, s.height * 0.14, 4.5);
}

/// Dawn sky + sun + temple towers. Fills whatever box it is given.
class TempleScenePainter extends CustomPainter {
  const TempleScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF5A1620), Color(0xFFB8321C), Color(0xFFF07A1A), Color(0xFFFFC15A)],
          stops: [0.0, 0.42, 0.78, 1.0],
        ).createShader(rect),
    );
    // sun with a soft glow
    final sun = Offset(size.width * 0.70, size.height * 0.40);
    canvas.drawCircle(
      sun,
      size.height * 0.62,
      Paint()
        ..shader = RadialGradient(colors: [const Color(0x66FFE9A8), const Color(0x00FFE9A8)])
            .createShader(Rect.fromCircle(center: sun, radius: size.height * 0.62)),
    );
    canvas.drawCircle(sun, size.height * 0.14, Paint()..color = const Color(0xFFFFE3A0));

    _birds(canvas, size, const Color(0xCCFFE9C8));

    final base = size.height + 1;
    // far, lighter tower
    drawGopuram(canvas, size.width * 0.66, base, size.height * 0.5, const Color(0x66410F14));
    // main tower
    drawGopuram(canvas, size.width * 0.86, base, size.height * 0.78, const Color(0xFF3A0D12));
    // low wall / trees line
    final ground = Path()..moveTo(0, size.height);
    for (var x = 0.0; x <= size.width; x += 24) {
      ground.quadraticBezierTo(x + 6, size.height - 10 - 6 * math.sin(x / 40), x + 12, size.height - 6);
      ground.lineTo(x + 24, size.height - 2);
    }
    ground.lineTo(size.width, size.height);
    ground.close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF2B0A0E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Rounded dawn-temple banner. [child] (text) is placed on the left.
class TempleBanner extends StatelessWidget {
  final double height;
  final Widget? child;
  final double radius;

  const TempleBanner({super.key, this.height = 170, this.child, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: TempleScenePainter()),
            if (child != null) Padding(padding: const EdgeInsets.fromLTRB(20, 16, 110, 16), child: child),
          ],
        ),
      ),
    );
  }
}

/// A faint skyline for the top of screens. Use as `foregroundDecoration: const SkylineDecoration()`.
class SkylineDecoration extends Decoration {
  final Color color;
  final Color farColor;

  const SkylineDecoration({this.color = const Color(0x26FFFFFF), this.farColor = const Color(0x14FFFFFF)});

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _SkylinePainter(color, farColor);
}

class _SkylinePainter extends BoxPainter {
  final Color color;
  final Color farColor;

  _SkylinePainter(this.color, this.farColor);

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final h = math.min(size.height * 0.8, 130.0);
    drawGopuram(canvas, size.width - 62, size.height - 14, h, color);
    drawGopuram(canvas, size.width - 150, size.height - 14, h * 0.62, farColor);
    canvas.restore();
  }
}
