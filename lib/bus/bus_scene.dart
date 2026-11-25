import 'package:flutter/material.dart';

/// Colour of the road / the band under the scene. The header below the picture uses the same colour.
const Color kBusBand = Color(0xFF0B57D0);

/// Flat bus-town picture for the bus screens: sky, sun, clouds, city, trees, road and a bus.
class BusScenePainter extends CustomPainter {
  const BusScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final road = 30.0;
    final base = h - road; // top of the road

    // sky
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1A73E8), Color(0xFF7DB4F7)]).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // sun
    final sun = Offset(w * 0.8, h * 0.34);
    canvas.drawCircle(sun, 44, Paint()..color = Colors.white.withAlpha(36));
    canvas.drawCircle(sun, 26, Paint()..color = Colors.white.withAlpha(70));

    // clouds
    void cloud(double x, double y, double s) {
      final p = Paint()..color = Colors.white.withAlpha(200);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y + 8 * s, 46 * s, 12 * s), Radius.circular(6 * s)), p);
      canvas.drawCircle(Offset(x + 14 * s, y + 8 * s), 9 * s, p);
      canvas.drawCircle(Offset(x + 26 * s, y + 4 * s), 11 * s, p);
      canvas.drawCircle(Offset(x + 37 * s, y + 9 * s), 7 * s, p);
    }

    cloud(w * 0.34, h * 0.5, 0.8);
    cloud(w * 0.62, h * 0.44, 0.6);
    cloud(w * 0.02, h * 0.46, 0.55);

    // far city
    final far = Paint()..color = const Color(0xFF5FA2F4);
    const farH = [34.0, 52.0, 40.0, 64.0, 44.0, 36.0, 58.0, 42.0, 70.0, 38.0, 50.0, 34.0, 60.0, 40.0, 46.0];
    var x = 0.0;
    var i = 0;
    while (x < w) {
      final bw = 24.0 + (i % 3) * 6;
      final bh = farH[i % farH.length] * (h / 150).clamp(0.8, 1.3);
      canvas.drawRect(Rect.fromLTWH(x, base - bh, bw, bh), far);
      x += bw + 3;
      i++;
    }
    // near city (darker, lower, with windows)
    final near = Paint()..color = const Color(0xFF3D88EE);
    final win = Paint()..color = Colors.white.withAlpha(90);
    const nearH = [22.0, 30.0, 26.0, 36.0, 24.0, 32.0];
    x = 6;
    i = 0;
    while (x < w) {
      final bw = 30.0 + (i % 2) * 10;
      final bh = nearH[i % nearH.length];
      canvas.drawRect(Rect.fromLTWH(x, base - bh, bw, bh), near);
      for (var wy = base - bh + 5; wy < base - 5; wy += 8) {
        canvas.drawRect(Rect.fromLTWH(x + 6, wy, 4, 3), win);
        canvas.drawRect(Rect.fromLTWH(x + bw - 11, wy, 4, 3), win);
      }
      x += bw + 14;
      i++;
    }

    // trees
    void tree(double tx, double s) {
      canvas.drawRect(Rect.fromLTWH(tx - 1.5 * s, base - 10 * s, 3 * s, 10 * s), Paint()..color = const Color(0xFF6D4C41));
      canvas.drawCircle(Offset(tx, base - 16 * s), 9 * s, Paint()..color = const Color(0xFF34A853));
      canvas.drawCircle(Offset(tx + 6 * s, base - 12 * s), 6 * s, Paint()..color = const Color(0xFF2E9A4B));
    }

    tree(w * 0.2, 1.0);
    tree(w * 0.52, 0.8);

    // road
    canvas.drawRect(Rect.fromLTWH(0, base, w, road), Paint()..color = kBusBand);
    final dash = Paint()..color = Colors.white.withAlpha(170);
    for (var dx = 8.0; dx < w; dx += 30) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(dx, base + road * 0.58, 16, 3), const Radius.circular(2)), dash);
    }

    // bus (faces right)
    final bw = 132.0;
    final bh = 54.0;
    final bx = w - bw - 14;
    final by = base + road * 0.42 - bh; // wheels touch the road
    canvas.drawOval(Rect.fromLTWH(bx + 6, by + bh - 3, bw - 8, 9), Paint()..color = Colors.black.withAlpha(50));
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(11));
    canvas.drawRRect(body, Paint()..color = Colors.white);
    // lower colour stripe
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(Rect.fromLTWH(bx, by + bh * 0.66, bw, bh * 0.2), Paint()..color = const Color(0xFFFBBC04));
    canvas.drawRect(Rect.fromLTWH(bx, by + bh * 0.86, bw, bh * 0.14), Paint()..color = const Color(0xFF1A73E8));
    canvas.restore();
    // windows
    final glass = Paint()..color = const Color(0xFF9CC7FA);
    for (var k = 0; k < 4; k++) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx + 10 + k * 22, by + 8, 18, 17), const Radius.circular(3)), glass);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx + bw - 34, by + 8, 25, 22), const Radius.circular(4)), glass);
    // door
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx + 98, by + 8, 1.5, 28), const Radius.circular(1)), Paint()..color = const Color(0xFFBDC1C6));
    // headlight + bumper
    canvas.drawCircle(Offset(bx + bw - 7, by + bh * 0.58), 3.2, Paint()..color = const Color(0xFFFFE082));
    // wheels
    for (final wx in [bx + 26, bx + bw - 30]) {
      canvas.drawCircle(Offset(wx, by + bh - 2), 9.5, Paint()..color = const Color(0xFF202124));
      canvas.drawCircle(Offset(wx, by + bh - 2), 4, Paint()..color = const Color(0xFFDADCE0));
    }
  }

  @override
  bool shouldRepaint(covariant BusScenePainter old) => false;
}
