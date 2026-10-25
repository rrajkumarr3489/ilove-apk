import 'package:flutter/material.dart';

const Color kBrand = Color(0xFFE8590C);
const Color kNavy = Color(0xFF0F2A43);
const Color kBlue = Color(0xFF1B6CA8);
const Color kBg = Color(0xFFF6F4F0);
const Color kInk = Color(0xFF1C1B1F);
const Color kMuted = Color(0xFF6B6B76);
const Color kLine = Color(0xFFE6E2DA);
const Color kGreen = Color(0xFF1E8E5A);
const Color kRed = Color(0xFFD32F2F);
const Color kAmber = Color(0xFFF9A825);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: kBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBg,
      foregroundColor: kInk,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}

TextStyle ts(double size,
    {FontWeight weight = FontWeight.w500, Color color = kInk, double? height}) {
  return TextStyle(
      fontSize: size, fontWeight: weight, color: color, height: height);
}

/// White rounded card with a soft border; tappable when [onTap] is given.
class SoftCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color color;

  const SoftCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.margin = EdgeInsets.zero,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: kLine),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
