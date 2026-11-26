import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Height of the header on every screen (below the status bar). Change it here and all screens follow.
const double kScreenHeaderH = 148;

/// One entry per kind of screen. To add a new screen: add a value here, a colour set in [_look] and a painter in [_art].
enum HeaderKind { bus, news, jobs, inbox, report, services, favorites, settings, myReports }

class _Look {
  final Color top;
  final Color bottom;
  final Color title;
  final Color sub;
  const _Look(this.top, this.bottom, this.title, this.sub);
}

_Look _look(HeaderKind k) {
  switch (k) {
    case HeaderKind.bus:
      return const _Look(Color(0xFFD2E2FB), Color(0xFFEBF3FF), Color(0xFF173F94), Color(0xFF28509F));
    case HeaderKind.news:
      return const _Look(Color(0xFFD3EDDA), Color(0xFFEFF9F1), Color(0xFF166A2E), Color(0xFF1D5B2E));
    case HeaderKind.jobs:
      return const _Look(Color(0xFFD7DAF8), Color(0xFFEFF0FE), Color(0xFF2E3A94), Color(0xFF2E3A94));
    case HeaderKind.inbox:
      return const _Look(Color(0xFFFBE7B8), Color(0xFFFFF7E3), Color(0xFF7A4B00), Color(0xFF8A5A0A));
    case HeaderKind.report:
      return const _Look(Color(0xFFFCDDD3), Color(0xFFFFF1EC), Color(0xFF9A2A12), Color(0xFFA23A22));
    case HeaderKind.services:
      return const _Look(Color(0xFFD2E2FB), Color(0xFFEBF3FF), Color(0xFF173F94), Color(0xFF28509F));
    case HeaderKind.favorites:
      return const _Look(Color(0xFFFBD9E5), Color(0xFFFFF1F5), Color(0xFF8E1B4A), Color(0xFF9C2C5A));
    case HeaderKind.settings:
      return const _Look(Color(0xFFD5EEEB), Color(0xFFF0FAF9), Color(0xFF0B5F5A), Color(0xFF14706A));
    case HeaderKind.myReports:
      return const _Look(Color(0xFFE3DAF8), Color(0xFFF5F1FD), Color(0xFF3E2A8C), Color(0xFF4A3A98));
  }
}

/// Round white button used in the header (list, share, favourite...).
class HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;

  const HeaderButton({super.key, required this.icon, required this.onTap, this.tooltip, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(24), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: color ?? kInk, size: 22),
        ),
      ),
    );
  }
}

/// Same header on every service screen: back button, language/extra buttons, big title + one line, and a moving picture.
class ScreenHeader extends StatefulWidget {
  final HeaderKind kind;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final bool showBack;

  const ScreenHeader({super.key, required this.kind, required this.title, this.subtitle, this.trailing = const [], this.showBack = true});

  @override
  State<ScreenHeader> createState() => _ScreenHeaderState();
}

class _ScreenHeaderState extends State<ScreenHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Picks font sizes so the title + subtitle always fit in [avail] height and never reach the back button.
  (double, double) _fit(String title, String sub, double width, double avail) {
    double h(String t, double size, FontWeight w, int lines) {
      if (t.isEmpty) return 0;
      final tp = TextPainter(text: TextSpan(text: t, style: ts(size, weight: w, height: 1.3)), maxLines: lines, textDirection: TextDirection.ltr)..layout(maxWidth: width);
      return tp.didExceedMaxLines ? 9999 : tp.height;
    }

    for (var t = 20.0; t >= 13; t -= 1) {
      final th = h(title, t, FontWeight.w700, 2);
      if (th > avail) continue;
      for (var s = 12.0; s >= 10; s -= 0.5) {
        final sh = sub.isEmpty ? 0 : h(sub, s, FontWeight.w500, 2);
        if (th + (sub.isEmpty ? 0 : 3) + sh <= avail) return (t, s);
      }
    }
    return (13, 10);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final h = top + kScreenHeaderH;
    final look = _look(widget.kind);
    final w = MediaQuery.of(context).size.width;
    final textW = widget.kind == HeaderKind.bus ? w * 0.56 : w * 0.54;
    final bottom = widget.kind == HeaderKind.bus ? 32.0 : 16.0;
    // back button occupies the top 56px; the text block lives strictly below it
    final avail = kScreenHeaderH - 58 - bottom;
    final sub = widget.subtitle ?? '';
    final (titleSize, subSize) = _fit(widget.title, sub, textW, avail);
    return SizedBox(
      width: double.infinity,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [look.top, look.bottom])),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _ArtPainter(widget.kind, _c, top)),
            ),
          ),
          if (widget.showBack)
            Positioned(
              left: 16,
              top: top + 10,
              child: HeaderButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
            ),
          Positioned(
            right: 16,
            top: top + 10,
            child: Row(
              children: [
                for (var i = 0; i < widget.trailing.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  widget.trailing[i],
                ],
              ],
            ),
          ),
          Positioned(
            left: 20,
            bottom: bottom,
            width: textW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(titleSize, weight: FontWeight.w700, color: look.title, height: 1.3)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(subSize, color: look.sub, height: 1.3)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final HeaderKind kind;
  final Animation<double> anim;
  final double top;

  _ArtPainter(this.kind, this.anim, this.top) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value; // 0..1 over 24 seconds, every motion below uses a whole number of cycles
    switch (kind) {
      case HeaderKind.bus:
        _bus(canvas, size, t);
        break;
      case HeaderKind.news:
        _ground(canvas, size);
        _news(canvas, size, t);
        break;
      case HeaderKind.jobs:
        _ground(canvas, size);
        _jobs(canvas, size, t);
        break;
      case HeaderKind.inbox:
        _ground(canvas, size);
        _inbox(canvas, size, t);
        break;
      case HeaderKind.report:
        _ground(canvas, size);
        _report(canvas, size, t);
        break;
      case HeaderKind.services:
        _ground(canvas, size);
        _services(canvas, size, t);
        break;
      case HeaderKind.favorites:
        _ground(canvas, size);
        _favorites(canvas, size, t);
        break;
      case HeaderKind.settings:
        _ground(canvas, size);
        _settings(canvas, size, t);
        break;
      case HeaderKind.myReports:
        _ground(canvas, size);
        _myReports(canvas, size, t);
        break;
    }
  }

  void _ground(Canvas canvas, Size s) {
    canvas.drawRect(Rect.fromLTWH(0, s.height - 24, s.width, 24), Paint()..color = Colors.black.withAlpha(14));
  }

  RRect _rr(double x, double y, double w, double h, double r) => RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  // ---------------------------------------------------------------- bus + road (full width, moving)
  void _bus(Canvas canvas, Size s, double t) {
    final w = s.width;
    final h = s.height;
    const roadH = 26.0;
    final base = h - roadH;

    // clouds drift left
    void cloud(double x0, double y, double sc) {
      final span = w + 120;
      final x = ((x0 - t * span) % span + span) % span - 60;
      final p = Paint()..color = Colors.white.withAlpha(200);
      canvas.drawRRect(_rr(x, y + 8 * sc, 44 * sc, 12 * sc, 6 * sc), p);
      canvas.drawCircle(Offset(x + 14 * sc, y + 8 * sc), 9 * sc, p);
      canvas.drawCircle(Offset(x + 26 * sc, y + 4 * sc), 11 * sc, p);
      canvas.drawCircle(Offset(x + 36 * sc, y + 9 * sc), 7 * sc, p);
    }

    cloud(w * 0.15, top + 58, 0.9);
    cloud(w * 0.62, top + 30, 0.7);

    // far city (slow)
    const far = [28.0, 44.0, 34.0, 56.0, 38.0];
    final farP = Paint()..color = const Color(0xFFC3D7F5);
    final off1 = -(t * 260) % 130;
    for (var x = off1 - 130; x < w + 130; x += 130) {
      for (var i = 0; i < far.length; i++) {
        canvas.drawRect(Rect.fromLTWH(x + i * 26.0, base - far[i], 22, far[i]), farP);
      }
    }
    // near bushes (faster)
    final off2 = -(t * 520) % 130;
    final bush = Paint()..color = const Color(0xFFA8D5A2);
    for (var x = off2 - 130; x < w + 130; x += 130) {
      canvas.drawCircle(Offset(x + 20, base - 3), 8, bush);
      canvas.drawCircle(Offset(x + 32, base - 6), 6, bush);
      canvas.drawCircle(Offset(x + 84, base - 3), 9, bush);
      canvas.drawCircle(Offset(x + 98, base - 5), 6, bush);
    }

    // road + moving dashes
    canvas.drawRect(Rect.fromLTWH(0, base, w, roadH), Paint()..color = const Color(0xFF5C6B84));
    final dash = Paint()..color = Colors.white.withAlpha(220);
    final off3 = -(t * 680) % 34;
    for (var x = off3 - 34; x < w + 34; x += 34) {
      canvas.drawRRect(_rr(x, base + roadH * 0.55, 18, 3, 1.5), dash);
    }

    // bus
    const bw = 150.0;
    const bh = 58.0;
    final bx = w - bw - 14;
    final bob = math.sin(t * 2 * math.pi * 24) * 0.9;
    final by = base + 10 - bh + bob;
    canvas.drawOval(Rect.fromLTWH(bx + 6, base + 7, bw - 10, 8), Paint()..color = Colors.black.withAlpha(46));
    final body = _rr(bx, by, bw, bh, 12);
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(Rect.fromLTWH(bx, by, bw, 5), Paint()..color = const Color(0xFF1A73E8));
    canvas.drawRect(Rect.fromLTWH(bx, by + bh * 0.62, bw, 11), Paint()..color = const Color(0xFFFBBC04));
    canvas.restore();
    final glass = Paint()..color = const Color(0xFF8DB8F4);
    for (var k = 0; k < 4; k++) {
      canvas.drawRRect(_rr(bx + 10 + k * 25, by + 12, 21, 18, 3), glass);
    }
    canvas.drawRRect(_rr(bx + bw - 36, by + 12, 27, 22, 4), Paint()..color = const Color(0xFF5F9BEF));
    canvas.drawCircle(Offset(bx + bw - 6, by + 40), 3, Paint()..color = const Color(0xFFFFE082));
    final ang = t * 2 * math.pi * 20;
    for (final wx in [bx + 32, bx + bw - 34]) {
      final c = Offset(wx, by + bh - 1);
      canvas.drawCircle(c, 11, Paint()..color = const Color(0xFF202124));
      canvas.drawCircle(c, 6.5, Paint()..color = Colors.white);
      final sp = Paint()
        ..color = const Color(0xFF202124)
        ..strokeWidth = 1.6;
      for (var i = 0; i < 4; i++) {
        final a = ang + i * math.pi / 2;
        canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 6, sp);
      }
    }
  }

  // ---------------------------------------------------------------- newspaper
  void _news(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    final bob = math.sin(t * 2 * math.pi * 12) * 3;
    canvas.save();
    canvas.translate(ox, oy);

    // back green sheet (tilted)
    canvas.save();
    canvas.translate(124, 80 - bob * 0.6);
    canvas.rotate(0.16 + math.sin(t * 2 * math.pi * 8) * 0.02);
    canvas.drawRRect(_rr(-42, -42, 84, 84, 8), Paint()..color = const Color(0xFF93CDA2));
    canvas.restore();

    // front paper
    canvas.save();
    canvas.translate(0, bob);
    canvas.drawRRect(_rr(32, 30, 116, 96, 9), Paint()..color = Colors.black.withAlpha(18));
    canvas.drawRRect(_rr(30, 26, 116, 96, 9), Paint()..color = Colors.white);
    canvas.drawRRect(_rr(42, 38, 56, 12, 3), Paint()..color = const Color(0xFF1E7D3A));
    canvas.drawRRect(_rr(42, 58, 38, 30, 4), Paint()..color = const Color(0xFFCDE8D4));
    final line = Paint()..color = const Color(0xFFD3D6DB);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(_rr(88, 58 + i * 10, 46, 5, 2.5), line);
    }
    canvas.drawRRect(_rr(42, 98, 92, 5, 2.5), line);
    canvas.drawRRect(_rr(42, 108, 66, 5, 2.5), line);
    canvas.restore();

    // live red dot with ripple
    final ph = (t * 24) % 1;
    const dot = Offset(158, 50);
    canvas.drawCircle(dot, 8 + 12 * ph, Paint()
      ..color = const Color(0xFFE53935).withAlpha((120 * (1 - ph)).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(dot, 7, Paint()..color = const Color(0xFFE53935));
    canvas.restore();
  }

  // ---------------------------------------------------------------- briefcase
  void _jobs(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    final bob = math.sin(t * 2 * math.pi * 12) * 3;
    final bob2 = math.sin(t * 2 * math.pi * 12 + 2.2) * 3;
    canvas.save();
    canvas.translate(ox, oy);

    // paper behind
    canvas.save();
    canvas.translate(94, 44 + bob2 * 0.6);
    canvas.rotate(-0.14);
    canvas.drawRRect(_rr(-36, -26, 72, 52, 6), Paint()..color = Colors.white);
    final line = Paint()..color = const Color(0xFFD7DAF0);
    canvas.drawRRect(_rr(-26, -14, 40, 5, 2.5), line);
    canvas.drawRRect(_rr(-26, -4, 52, 5, 2.5), line);
    canvas.restore();

    // briefcase
    canvas.save();
    canvas.translate(0, bob);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(86, 42, 44, 24), const Radius.circular(8)), Paint()
      ..color = const Color(0xFF2A3590)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7);
    canvas.drawRRect(_rr(54, 60, 108, 70, 11), Paint()..color = const Color(0xFF3F4FB0));
    canvas.drawRect(const Rect.fromLTWH(54, 88, 108, 9), Paint()..color = const Color(0xFF2A3590));
    canvas.drawRRect(_rr(101, 85, 14, 16, 3), Paint()..color = const Color(0xFFFBBC04));
    canvas.restore();

    // ID card
    canvas.save();
    canvas.translate(0, bob2);
    canvas.drawRRect(_rr(6, 82, 66, 40, 6), Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(22, 97), 7, Paint()..color = const Color(0xFFB7BCE8));
    final gl = Paint()..color = const Color(0xFFD3D6DB);
    canvas.drawRRect(_rr(34, 90, 30, 4, 2), gl);
    canvas.drawRRect(_rr(34, 98, 22, 4, 2), gl);
    canvas.drawRRect(_rr(12, 110, 50, 4, 2), gl);
    canvas.restore();

    // location pin (bounces)
    final jump = -(math.sin(t * 2 * math.pi * 12).abs()) * 7;
    canvas.save();
    canvas.translate(172, 46 + jump);
    final pin = Path()
      ..moveTo(0, 26)
      ..cubicTo(-14, 10, -12, -2, 0, -2)
      ..cubicTo(12, -2, 14, 10, 0, 26)
      ..close();
    final pinPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(0, 8), radius: 11))
      ..addPath(pin, Offset.zero);
    canvas.drawPath(pinPath, Paint()..color = const Color(0xFFE53935));
    canvas.drawCircle(const Offset(0, 8), 4, Paint()..color = Colors.white);
    canvas.restore();

    canvas.restore();
  }

  // ---------------------------------------------------------------- bell (notifications)
  void _inbox(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    canvas.save();
    canvas.translate(ox + 96, oy + 22);
    final swing = math.sin(t * 2 * math.pi * 12) * 0.16;
    canvas.save();
    canvas.rotate(swing);
    canvas.translate(0, 40);
    final body = Path()
      ..moveTo(-34, 38)
      ..cubicTo(-34, 22, -28, -32, 0, -32)
      ..cubicTo(28, -32, 34, 22, 34, 38)
      ..close();
    canvas.drawCircle(const Offset(0, -38), 5, Paint()..color = const Color(0xFFE09A0B));
    canvas.drawPath(body, Paint()..color = const Color(0xFFFBBC04));
    canvas.drawRRect(_rr(-40, 34, 80, 11, 5.5), Paint()..color = const Color(0xFFE09A0B));
    canvas.drawCircle(Offset(math.sin(t * 2 * math.pi * 12 + 1.2) * 4, 52), 7, Paint()..color = const Color(0xFF8A5A0A));
    canvas.drawRRect(_rr(-18, -14, 8, 30, 4), Paint()..color = Colors.white.withAlpha(110));
    canvas.restore();
    // sound arcs
    for (var i = 0; i < 2; i++) {
      final ph = ((t * 12) + i * 0.5) % 1;
      final p = Paint()
        ..color = const Color(0xFFE09A0B).withAlpha((150 * (1 - ph)).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final r = 52 + 16 * ph;
      canvas.drawArc(Rect.fromCircle(center: const Offset(0, 60), radius: r), -math.pi * 0.2 - 0.5, 0.5, false, p);
      canvas.drawArc(Rect.fromCircle(center: const Offset(0, 60), radius: r), -math.pi * 0.8, 0.5, false, p);
    }
    // red badge with ripple
    final ph = (t * 24) % 1;
    const dot = Offset(40, 22);
    canvas.drawCircle(dot, 8 + 12 * ph, Paint()
      ..color = const Color(0xFFE53935).withAlpha((120 * (1 - ph)).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(dot, 8, Paint()..color = const Color(0xFFE53935));
    canvas.restore();
  }

  // ---------------------------------------------------------------- warning sign (report an issue)
  void _report(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    final bob = math.sin(t * 2 * math.pi * 12) * 3;
    canvas.save();
    canvas.translate(ox, oy);
    // paper behind
    canvas.save();
    canvas.translate(52, 78 + bob * 0.5);
    canvas.rotate(-0.12);
    canvas.drawRRect(_rr(-40, -48, 80, 96, 8), Paint()..color = Colors.white);
    final line = Paint()..color = const Color(0xFFF2D2C8);
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(_rr(-28, -34 + i * 14, i.isEven ? 56 : 40, 5, 2.5), line);
    }
    canvas.restore();
    // triangle
    final pulse = 1 + math.sin(t * 2 * math.pi * 24) * 0.04;
    canvas.save();
    canvas.translate(116, 76 + bob);
    canvas.scale(pulse);
    final tri = Path()
      ..moveTo(0, -40)
      ..lineTo(44, 34)
      ..lineTo(-44, 34)
      ..close();
    canvas.drawPath(tri, Paint()
      ..color = const Color(0xFFE8710A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(tri, Paint()..color = const Color(0xFFE8710A));
    canvas.drawRRect(_rr(-4, -12, 8, 28, 4), Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(0, 24), 4.5, Paint()..color = Colors.white);
    canvas.restore();
    // red dot with ripple
    final ph = (t * 24) % 1;
    const dot = Offset(172, 40);
    canvas.drawCircle(dot, 7 + 12 * ph, Paint()
      ..color = const Color(0xFFE53935).withAlpha((120 * (1 - ph)).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(dot, 6, Paint()..color = const Color(0xFFE53935));
    canvas.restore();
  }

  // ---------------------------------------------------------------- service tiles (all services, misc)
  void _services(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    canvas.save();
    canvas.translate(ox + 44, oy + 24);
    const cols = [Color(0xFF1A73E8), Color(0xFF34A853), Color(0xFFFBBC04), Color(0xFFEA4335)];
    for (var i = 0; i < 4; i++) {
      final x = (i % 2) * 58.0;
      final y = (i ~/ 2) * 58.0;
      final bob = math.sin(t * 2 * math.pi * 12 + i * 1.3) * 4;
      canvas.drawRRect(_rr(x + 2, y + 4 + bob, 50, 50, 14), Paint()..color = Colors.black.withAlpha(16));
      canvas.drawRRect(_rr(x, y + bob, 50, 50, 14), Paint()..color = cols[i]);
      canvas.drawCircle(Offset(x + 25, y + 25 + bob), 10, Paint()..color = Colors.white.withAlpha(230));
    }
    canvas.restore();
  }

  Path _heart(double sc) => Path()
    ..moveTo(0, 0.9 * sc)
    ..cubicTo(-1.1 * sc, 0.1 * sc, -1.0 * sc, -0.9 * sc, 0, -0.4 * sc)
    ..cubicTo(1.0 * sc, -0.9 * sc, 1.1 * sc, 0.1 * sc, 0, 0.9 * sc)
    ..close();

  // ---------------------------------------------------------------- beating heart (favourites)
  void _favorites(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    final bob = math.sin(t * 2 * math.pi * 12) * 3;
    canvas.save();
    canvas.translate(ox, oy);
    // saved ticket behind
    canvas.save();
    canvas.translate(56, 82 + bob * 0.5);
    canvas.rotate(-0.12);
    canvas.drawRRect(_rr(-38, -46, 76, 92, 8), Paint()..color = Colors.white);
    canvas.drawRRect(_rr(-26, -32, 36, 26, 5), Paint()..color = const Color(0xFFBBD2F5));
    final line = Paint()..color = const Color(0xFFF4C6D6);
    for (var i = 0; i < 3; i++) {
      canvas.drawRRect(_rr(-26, 4 + i * 12, i == 2 ? 34 : 52, 5, 2.5), line);
    }
    canvas.restore();
    // big heart (beats)
    final beat = 1 + math.max(0.0, math.sin(t * 2 * math.pi * 24)) * 0.08;
    canvas.save();
    canvas.translate(126, 76 + bob);
    canvas.scale(beat);
    canvas.drawPath(_heart(46).shift(const Offset(2, 5)), Paint()..color = Colors.black.withAlpha(20));
    canvas.drawPath(
      _heart(46),
      Paint()..shader = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFF8A80), Color(0xFFE53935)]).createShader(const Rect.fromLTWH(-46, -42, 92, 84)),
    );
    canvas.drawCircle(const Offset(-16, -14), 5, Paint()..color = Colors.white.withAlpha(110));
    canvas.restore();
    // little hearts floating up
    for (var i = 0; i < 3; i++) {
      final ph = ((t * 12) + i / 3) % 1;
      canvas.save();
      canvas.translate(150 + (i - 1) * 16 + math.sin(ph * 6) * 4, 46 - ph * 38);
      canvas.drawPath(_heart(6 + i * 2.0), Paint()..color = const Color(0xFFE53935).withAlpha((200 * (1 - ph)).round()));
      canvas.restore();
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- profile + gear (me / settings)
  void _settings(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    final bob = math.sin(t * 2 * math.pi * 12) * 3;
    canvas.save();
    canvas.translate(ox, oy);
    // avatar
    canvas.save();
    canvas.translate(94, 76 + bob);
    final disc = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 46));
    canvas.drawCircle(const Offset(2, 5), 46, Paint()..color = Colors.black.withAlpha(20));
    canvas.drawPath(disc, Paint()..color = const Color(0xFF26A69A));
    canvas.save();
    canvas.clipPath(disc);
    canvas.drawCircle(const Offset(0, -10), 15, Paint()..color = Colors.white);
    canvas.drawOval(const Rect.fromLTWH(-28, 10, 56, 50), Paint()..color = Colors.white);
    canvas.restore();
    canvas.restore();
    // turning gear
    canvas.save();
    canvas.translate(162, 44 - bob * 0.5);
    canvas.rotate(t * 2 * math.pi * 3);
    final gp = Paint()..color = const Color(0xFF0B7A75);
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawRRect(_rr(-4.5, -22, 9, 12, 2), gp);
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 17, gp);
    canvas.drawCircle(Offset.zero, 7, Paint()..color = const Color(0xFFE3F4F2));
    canvas.restore();
    // toggle switch (slides)
    final k = (math.sin(t * 2 * math.pi * 6) + 1) / 2;
    canvas.drawRRect(_rr(140, 100, 46, 24, 12), Paint()..color = Color.lerp(const Color(0xFFB0BEC5), const Color(0xFF26A69A), k)!);
    canvas.drawCircle(Offset(152 + 22 * k, 112), 9, Paint()..color = Colors.white);
    canvas.restore();
  }

  // ---------------------------------------------------------------- clipboard with ticks (my reports)
  void _myReports(Canvas canvas, Size s, double t) {
    final ox = s.width - 196;
    final oy = s.height - 148;
    final bob = math.sin(t * 2 * math.pi * 12) * 3;
    canvas.save();
    canvas.translate(ox, oy + bob);
    canvas.drawRRect(_rr(54, 24, 100, 108, 10), Paint()..color = Colors.black.withAlpha(18));
    canvas.drawRRect(_rr(52, 20, 100, 108, 10), Paint()..color = Colors.white);
    canvas.drawRRect(_rr(86, 12, 32, 16, 6), Paint()..color = const Color(0xFF5E35B1));
    final n = (((t * 12) % 1) * 4).floor(); // 0..3 ticks shown, then starts again
    for (var i = 0; i < 3; i++) {
      final y = 52.0 + i * 28;
      final on = i < n;
      canvas.drawCircle(Offset(72, y), 9, Paint()..color = on ? const Color(0xFF43A047) : const Color(0xFFE3DAF8));
      if (on) {
        final p = Path()
          ..moveTo(67.5, y)
          ..lineTo(71, y + 3.5)
          ..lineTo(77, y - 3.5);
        canvas.drawPath(p, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
      }
      canvas.drawRRect(_rr(90, y - 6, i == 1 ? 44 : 52, 6, 3), Paint()..color = const Color(0xFFD7CDEE));
      canvas.drawRRect(_rr(90, y + 3, 34, 4, 2), Paint()..color = const Color(0xFFEAE4F8));
    }
    // red dot with ripple
    final ph = (t * 24) % 1;
    const dot = Offset(160, 30);
    canvas.drawCircle(dot, 7 + 11 * ph, Paint()
      ..color = const Color(0xFFE53935).withAlpha((110 * (1 - ph)).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(dot, 6, Paint()..color = const Color(0xFFE53935));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind || old.top != top;
}

/// Use as `appBar:` of a Scaffold to get the common header on a screen: `appBar: ScreenAppBar(kind: HeaderKind.news, title: ...)`.
class ScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final HeaderKind kind;
  final String title;
  final String? subtitle;
  final List<Widget> trailing;

  const ScreenAppBar({super.key, required this.kind, required this.title, this.subtitle, this.trailing = const []});

  @override
  Size get preferredSize {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return Size.fromHeight(kScreenHeaderH + view.padding.top / view.devicePixelRatio);
  }

  @override
  Widget build(BuildContext context) => ScreenHeader(kind: kind, title: title, subtitle: subtitle, trailing: trailing);
}

/// Small white pill button (icon + text) for the header, e.g. "Mark all read".
class HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const HeaderPill({super.key, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(24), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: kBrand),
            const SizedBox(width: 6),
            Text(label, style: ts(12.5, weight: FontWeight.w700, color: kBrand)),
          ],
        ),
      ),
    );
  }
}
