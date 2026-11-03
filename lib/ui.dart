import 'package:flutter/material.dart';

import 'art.dart';
import 'theme.dart';

/// Orange header with soft bubbles and a rounded bottom. Put the screen's top row in [child].
/// The status-bar height is added automatically.
class AppHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool skyline;

  const AppHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 16, 20),
    this.radius = 32,
    this.skyline = false,
  });

  Widget _bubble(double size, int alpha) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white.withAlpha(alpha), shape: BoxShape.circle));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: skyline ? const SkylineDecoration() : null,
      decoration: BoxDecoration(
        gradient: kHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
        boxShadow: const [BoxShadow(color: Color(0x55E8590C), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(right: -40, top: -30, child: _bubble(150, 26)),
          Positioned(left: -50, bottom: 30, child: _bubble(120, 20)),
          Positioned(right: 70, bottom: -50, child: _bubble(100, 18)),
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, top + padding.top, padding.right, padding.bottom),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Orange gradient button with a soft shadow.
class GradButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final double height;

  const GradButton({super.key, required this.label, this.icon, this.onTap, this.busy = false, this.height = 54});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: (onTap == null && !busy) ? 0.55 : 1,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: kButtonGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: kBrand.withAlpha(90), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Center(
              child: busy
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 8)],
                        Text(label, style: ts(16.5, weight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round tinted icon.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBubble(this.icon, {super.key, this.color = kBrand, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Selectable rounded pill used for dates, filters and trip times on light backgrounds.
class ChoicePill extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;

  const ChoicePill(this.label, {super.key, required this.on, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: on ? kBrand : const Color(0xFFFFF4E6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: on ? kBrand : kBrand.withAlpha(60)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon ?? (on ? Icons.check_rounded : Icons.circle_outlined), size: 17, color: on ? Colors.white : kBrand),
          const SizedBox(width: 6),
          Text(label, style: ts(13.5, weight: FontWeight.w800, color: on ? Colors.white : const Color(0xFF7A3A0A))),
        ]),
      ),
    );
  }
}
