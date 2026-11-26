import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Height of the header on every screen (below the status bar). Change it here and all screens follow.
const double kScreenHeaderH = 148;

/// One entry per kind of screen. To add a new screen: add a value here, a colour set in [_look] and a painter in [_art].
enum HeaderKind { bus, news, jobs }

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

  const ScreenHeader({super.key, required this.kind, required this.title, this.subtitle, this.trailing = const []});

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

  /// Biggest font size (from [max] down to [min]) that keeps [text] inside [lines] lines of [width].
  double _fit(String text, double width, double max, double min, int lines, FontWeight w) {
    for (var s = max; s > min; s -= 1) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: ts(s, weight: w, height: 1.15)),
        maxLines: lines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      if (!tp.didExceedMaxLines) return s;
    }
    return min;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final h = top + kScreenHeaderH;
    final look = _look(widget.kind);
    final w = MediaQuery.of(context).size.width;
    final textW = widget.kind == HeaderKind.bus ? w * 0.56 : w * 0.54;
    final titleSize = _fit(widget.title, textW, 27, 15, 2, FontWeight.w800);
    final sub = widget.subtitle ?? '';
    final subSize = sub.isEmpty ? 12.0 : _fit(sub, textW, 13, 10, 2, FontWeight.w500);
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
            bottom: widget.kind == HeaderKind.bus ? 40 : 20,
            width: textW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(titleSize, weight: FontWeight.w800, color: look.title, height: 1.15)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(subSize, color: look.sub, height: 1.25)),
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

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind || old.top != top;
}
