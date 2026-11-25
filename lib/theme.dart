import 'package:flutter/material.dart';

// ===== THEME PALETTE =====
// Clean "GPay" look: white pages, grey surfaces, Google-blue accent, a little Google red / green / yellow in icons only.
// Every screen uses these names, so the whole look of the app is changed from this one block.
// (Old orange theme: replace this file with theme_orange_BACKUP.dart.)

// Brand (primary) colours
const Color kBrand = Color(0xFF1A73E8);
const Color kBrandLight = Color(0xFF4F9CF9);
const Color kBrandDark = Color(0xFF1557B0);
const Color kBrandMid = Color(0xFF8AB4F8);
const Color kBrandShadow = Color(0x331A73E8);

// Soft tints and text on tints
const Color kTint = Color(0xFFE8F0FE);
const Color kTintSoft = Color(0xFFF1F3F4);
const Color kOnBrandSoft = Color(0xFFD2E3FC);
const Color kChipText = Color(0xFF174EA6);

// Page, text and lines
const Color kBg = Color(0xFFFFFFFF);
const Color kInk = Color(0xFF202124);
const Color kMuted = Color(0xFF5F6368);
const Color kLine = Color(0xFFE8EAED);
const Color kNavy = Color(0xFF202124);
const Color kRose = Color(0xFFEA4335);
const Color kBlue = Color(0xFF1A73E8);

// Home banner fallback scene
const Color kSkyTop = Color(0xFF1557B0);
const Color kSkyMid = Color(0xFF1A73E8);
const Color kSkyLow = Color(0xFF8AB4F8);
const Color kSkyHorizon = Color(0xFFE8F0FE);
const Color kSun = Color(0xFFFDE293);
const Color kSunGlow = Color(0x66FDE293);
const Color kBirds = Color(0xCCFFFFFF);
const Color kTowerFar = Color(0x661557B0);
const Color kTowerMain = Color(0xFF1557B0);
const Color kGround = Color(0xFF0D3B7A);

// Home service icon colours (Google blue / green / yellow / red / purple)
const Color kTileBus = Color(0xFF1A73E8);
const Color kTileNews = Color(0xFF188038);
const Color kTileTrain = Color(0xFF1A73E8);
const Color kTileServices = Color(0xFFE37400);
const Color kTileParcel = Color(0xFF188038);
const Color kTileShops = Color(0xFFD93025);
const Color kTileFood = Color(0xFFE37400);
const Color kTileJobs = Color(0xFF1A73E8);
const Color kTileReport = Color(0xFFD93025);
const Color kTileAi = Color(0xFF9334E6);
const Color kGreen = Color(0xFF188038);
const Color kRed = Color(0xFFD93025); // only for errors / delete / closed
const Color kAmber = Color(0xFFF9AB00);

/// Header / button gradient used on every screen.
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [kBrandDark, kBrand],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Flat brand blue (a "gradient" of one colour so every old use keeps working).
const LinearGradient kButtonGradient = LinearGradient(colors: [kBrand, kBrand]);

const List<BoxShadow> kSoftShadow = [
  BoxShadow(color: Color(0x14202124), blurRadius: 12, offset: Offset(0, 3)),
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
      backgroundColor: Colors.white,
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
