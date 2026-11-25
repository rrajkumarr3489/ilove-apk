import 'package:flutter/material.dart';

/// Soft flat illustration of Aruppukottai (temple tower, bus, buildings, hills) drawn in code,
/// so it needs no picture file and looks sharp on every phone.
class HomeScenePainter extends CustomPainter {
  const HomeScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const dw = 400.0, dh = 300.0;
    final s = size.width / dw > size.height / dh ? size.width / dw : size.height / dh;
    // sky first (fills everything)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD6E9FB), Color(0xFFEAF4FD)]).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.translate((size.width - dw * s) / 2, size.height - dh * s);
    canvas.scale(s);

    Paint p(int c, [double o = 1]) => Paint()..color = Color(c).withAlpha((o * 255).round());
    void rect(double x, double y, double w, double h, int c, {double r = 0, double o = 1}) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p(c, o));
    void oval(double cx, double cy, double rx, double ry, int c, double o) =>
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), p(c, o));

    // clouds
    oval(70, 70, 38, 10, 0xFFFFFFFF, .7);
    oval(98, 62, 24, 10, 0xFFFFFFFF, .7);
    oval(320, 120, 34, 9, 0xFFFFFFFF, .6);

    // far hill
    canvas.drawPath(
      Path()
        ..moveTo(0, 190)
        ..cubicTo(60, 160, 120, 165, 190, 185)
        ..cubicTo(260, 205, 330, 190, 400, 165)
        ..lineTo(400, 300)
        ..lineTo(0, 300)
        ..close(),
      p(0xFFD9E8F6),
    );

    // buildings
    rect(6, 150, 46, 70, 0xFFC9DDF3);
    for (final dx in [12.0, 26.0, 40.0]) {
      for (final dy in [158.0, 176.0]) {
        rect(dx, dy, 8, 8, 0xFFEAF4FD);
      }
    }
    rect(56, 178, 34, 50, 0xFFBFD9C4);
    rect(330, 140, 40, 86, 0xFFC9DDF3);
    rect(372, 170, 28, 60, 0xFFF5D9DD);
    for (final dx in [337.0, 352.0]) {
      for (final dy in [150.0, 168.0]) {
        rect(dx, dy, 8, 8, 0xFFEAF4FD);
      }
    }

    // mid and near grass
    canvas.drawPath(
      Path()
        ..moveTo(0, 225)
        ..cubicTo(70, 200, 150, 205, 220, 220)
        ..cubicTo(290, 235, 350, 232, 400, 210)
        ..lineTo(400, 300)
        ..lineTo(0, 300)
        ..close(),
      p(0xFFDCEBC9),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 255)
        ..cubicTo(90, 235, 190, 250, 290, 245)
        ..cubicTo(340, 242, 370, 240, 400, 236)
        ..lineTo(400, 300)
        ..lineTo(0, 300)
        ..close(),
      p(0xFFCFE3B3),
    );

    // temple tower
    const tx = 150.0, ty = 118.0;
    rect(tx + 14, ty + 88, 72, 26, 0xFF7FC8C0);
    rect(tx + 22, ty + 66, 56, 22, 0xFF7FC8C0);
    rect(tx + 30, ty + 48, 40, 18, 0xFF7FC8C0);
    rect(tx + 38, ty + 32, 24, 16, 0xFF7FC8C0);
    rect(tx + 45, ty + 20, 10, 12, 0xFF7FC8C0);
    rect(tx + 48, ty + 8, 4, 12, 0xFF7FC8C0);
    rect(tx + 14, ty + 88, 72, 4, 0xFF5FB0A8);
    rect(tx + 22, ty + 66, 56, 4, 0xFF5FB0A8);
    rect(tx + 30, ty + 48, 40, 4, 0xFF5FB0A8);
    rect(tx + 38, ty + 32, 24, 4, 0xFF5FB0A8);
    rect(tx + 42, ty + 96, 16, 18, 0xFFEAF4FD, r: 8);

    // trees
    canvas.drawCircle(const Offset(120, 214), 9, p(0xFF9CC98A));
    rect(118, 214, 4, 14, 0xFF8DB57D);
    canvas.drawCircle(const Offset(270, 206), 10, p(0xFF9CC98A));
    rect(268, 206, 4, 16, 0xFF8DB57D);

    // bus
    const bx = 228.0, by = 192.0;
    rect(bx, by, 86, 34, 0xFF1A73E8, r: 7);
    for (final dx in [8.0, 26.0, 44.0]) {
      rect(bx + dx, by + 6, 14, 12, 0xFFEAF4FD, r: 2);
    }
    rect(bx + 62, by + 6, 16, 12, 0xFFEAF4FD, r: 2);
    rect(bx, by + 22, 86, 3, 0xFFFFFFFF, o: .6);
    for (final dx in [20.0, 66.0]) {
      canvas.drawCircle(Offset(bx + dx, by + 36), 7, p(0xFF3C4043));
      canvas.drawCircle(Offset(bx + dx, by + 36), 3, p(0xFFE8EAED));
    }
    canvas.drawCircle(const Offset(352, 214), 9, p(0xFFE8A9B2));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HomeScenePainter old) => false;
}

/// Food page scene: hotel with an awning, delivery scooter, trees and hills.
class FoodScenePainter extends CustomPainter {
  const FoodScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const dw = 400.0, dh = 300.0;
    final s = size.width / dw > size.height / dh ? size.width / dw : size.height / dh;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFDCEAFB), Color(0xFFEEF5FD)]).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.translate((size.width - dw * s) / 2, size.height - dh * s);
    canvas.scale(s);

    Paint p(int c, [double o = 1]) => Paint()..color = Color(c).withAlpha((o * 255).round());
    void rect(double x, double y, double w, double h, int c, {double r = 0, double o = 1}) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)), p(c, o));
    void oval(double cx, double cy, double rx, double ry, int c, double o) =>
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2), p(c, o));
    void hill(List<double> v, int c) {
      canvas.drawPath(
        Path()
          ..moveTo(v[0], v[1])
          ..cubicTo(v[2], v[3], v[4], v[5], v[6], v[7])
          ..cubicTo(v[8], v[9], v[10], v[11], v[12], v[13])
          ..lineTo(400, 300)
          ..lineTo(0, 300)
          ..close(),
        p(c),
      );
    }

    oval(300, 70, 36, 10, 0xFFFFFFFF, .7);
    oval(326, 62, 22, 9, 0xFFFFFFFF, .7);
    oval(60, 110, 30, 8, 0xFFFFFFFF, .6);
    hill([0, 195, 70, 170, 140, 172, 210, 190, 280, 208, 330, 192, 400, 172], 0xFFD9E8F6);
    rect(8, 150, 44, 76, 0xFFC9DDF3);
    rect(350, 146, 42, 80, 0xFFC9DDF3);
    for (final o in [const Offset(14, 158), const Offset(30, 158), const Offset(14, 176), const Offset(30, 176), const Offset(358, 154), const Offset(374, 154)]) {
      rect(o.dx, o.dy, 8, 8, 0xFFEEF5FD);
    }
    hill([0, 228, 70, 206, 150, 210, 220, 224, 290, 238, 350, 234, 400, 214], 0xFFDCEBC9);
    hill([0, 258, 90, 240, 190, 254, 290, 249, 340, 246, 370, 244, 400, 240], 0xFFCFE3B3);

    // hotel
    const hx = 80.0, hy = 128.0;
    rect(hx, hy + 30, 150, 76, 0xFFFCE3D6);
    rect(hx, hy + 30, 150, 8, 0xFFF4B79C);
    canvas.drawPath(
      Path()
        ..moveTo(hx - 6, hy + 38)
        ..lineTo(hx + 156, hy + 38)
        ..lineTo(hx + 146, hy + 60)
        ..lineTo(hx + 4, hy + 60)
        ..close(),
      p(0xFFEA4335),
    );
    for (final dx in [4.0, 38.0, 72.0, 106.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(hx + dx + 5, hy + 38)
          ..lineTo(hx + dx + 17, hy + 38)
          ..lineTo(hx + dx + 14, hy + 60)
          ..lineTo(hx + dx + 2, hy + 60)
          ..close(),
        p(0xFFFFFFFF),
      );
    }
    rect(hx + 14, hy + 70, 46, 36, 0xFFFFFFFF, r: 3);
    rect(hx + 72, hy + 72, 30, 34, 0xFF8AB4F8, r: 3);
    canvas.drawCircle(Offset(hx + 125, hy + 86), 14, p(0xFFFFFFFF));
    rect(hx + 118, hy + 85, 14, 3, 0xFFEA4335, r: 1.5);
    rect(hx + 120, hy + 80, 10, 3, 0xFFEA4335, r: 1.5);
    rect(hx + 52, hy + 8, 46, 20, 0xFF1A73E8, r: 6);
    rect(hx + 62, hy + 16, 26, 3, 0xFFFFFFFF, r: 1.5);

    // delivery scooter
    const sx = 250.0, sy = 196.0;
    rect(sx - 2, sy + 2, 36, 26, 0xFFFBBC04, r: 4);
    rect(sx + 6, sy + 13, 20, 3, 0xFFFFFFFF, r: 1.5);
    final line = Paint()
      ..color = const Color(0xFF1A73E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(sx + 14, sy + 32)
        ..lineTo(sx + 32, sy + 32)
        ..lineTo(sx + 42, sy + 18)
        ..lineTo(sx + 62, sy + 18)
        ..lineTo(sx + 66, sy + 32),
      line,
    );
    canvas.drawCircle(Offset(sx + 50, sy + 6), 6, p(0xFFE8A9B2));
    rect(sx + 46, sy + 12, 10, 12, 0xFF188038, r: 2);
    for (final dx in [14.0, 66.0]) {
      canvas.drawCircle(Offset(sx + dx, sy + 32), 9, p(0xFF3C4043));
      canvas.drawCircle(Offset(sx + dx, sy + 32), 4, p(0xFFE8EAED));
    }

    // trees
    canvas.drawCircle(const Offset(40, 218), 10, p(0xFF9CC98A));
    rect(38, 218, 4, 14, 0xFF8DB57D);
    canvas.drawCircle(const Offset(360, 226), 9, p(0xFF9CC98A));
    rect(358, 226, 4, 14, 0xFF8DB57D);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FoodScenePainter old) => false;
}
