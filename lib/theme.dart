import 'package:flutter/material.dart';

const Color kBrand = Color(0xFFE8590C);
// kNavy / kBlue keep their old names so every screen compiles, but they are warm now (no blue anywhere).
const Color kNavy = Color(0xFF3D2314);
const Color kBlue = Color(0xFFD9480F);
const Color kBg = Color(0xFFFFF6EC);
const Color kInk = Color(0xFF1C1B1F);
const Color kMuted = Color(0xFF6B6B76);
const Color kLine = Color(0xFFEFE3D3);
const Color kGreen = Color(0xFF1E8E5A);
const Color kRed = Color(0xFFD32F2F);
const Color kAmber = Color(0xFFF9A825);

/// Orange header / button gradient used on every screen.
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [Color(0xFFFF8A2B), kBrand, Color(0xFFD9480F)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kButtonGradient = LinearGradient(colors: [Color(0xFFFF7A1A), kBrand]);

const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 5)),
];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrand,
    brightness: Brightness.light,
  ).copyWith(primary: kBrand);
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
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kBrand,
        side: BorderSide(color: kBrand.withAlpha(110), width: 1.4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kBrand, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kBrand),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kNavy,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

TextStyle ts(double size,
    {FontWeight weight = FontWeight.w500, Color color = kInk, double? height}) {
  return TextStyle(
      fontSize: size, fontWeight: weight, color: color, height: height);
}

/// White rounded card with a soft shadow; tappable when [onTap] is given.
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
    final radius = BorderRadius.circular(20);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: kSoftShadow,
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
