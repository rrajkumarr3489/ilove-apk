import 'package:flutter/material.dart';

import 'art.dart';
import 'theme.dart';

/// Flat blue app bar with a straight bottom. Put the screen's top row in [child].
/// The status-bar height is added automatically.
class AppHeader extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool skyline;
  final bool bubbles;
  final IconData? icon;
  final Color? sheet;

  const AppHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 16, 20),
    this.radius = 32,
    this.skyline = false,
    this.bubbles = true,
    this.icon,
    this.sheet,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      foregroundDecoration: skyline ? const SkylineDecoration() : null,
      decoration: const BoxDecoration(gradient: kHeaderGradient),
      padding: EdgeInsets.fromLTRB(padding.left, top + padding.top, padding.right, padding.bottom),
      child: child,
    );
  }
}

/// Blue pill button.
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
          color: on ? kBrand : kTint,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon ?? (on ? Icons.check_rounded : Icons.circle_outlined), size: 17, color: on ? Colors.white : kBrand),
          const SizedBox(width: 6),
          Text(label, style: ts(13.5, weight: FontWeight.w800, color: on ? Colors.white : kChipText)),
        ]),
      ),
    );
  }
}

/// Top row for service pages on a white background: round back button, then your own [trailing] widgets.
class ServiceTopBar extends StatelessWidget {
  final List<Widget> trailing;

  const ServiceTopBar({super.key, this.trailing = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(color: kTintSoft, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_rounded, color: kInk, size: 22),
            ),
          ),
          const Spacer(),
          ...trailing,
        ],
      ),
    );
  }
}

/// Soft coloured card at the top of a service page: icon circle, title, one line, big faint icon behind.
class ServiceHero extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const ServiceHero({super.key, required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Color.alphaBlend(color.withAlpha(30), Colors.white), borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Positioned(
            right: -14,
            bottom: -24,
            child: Transform.rotate(angle: -0.2, child: Icon(icon, size: 130, color: color.withAlpha(36))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(21, weight: FontWeight.w700, color: kInk)),
                      const SizedBox(height: 2),
                      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, color: kMuted, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
