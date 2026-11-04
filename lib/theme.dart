import 'package:flutter/material.dart';

// ===== THEME PALETTE =====
// Every screen uses these names, so the whole look of the app is changed from this one block.
// (Old orange theme: replace this file with theme_orange_BACKUP.dart.)

// Brand (primary) colours
const Color kBrand = Color(0xFF2A7DE1);
const Color kBrandLight = Color(0xFF4DA3FF);
const Color kBrandDark = Color(0xFF1B5FC2);
const Color kBrandMid = Color(0xFF8DBBF2);
const Color kBrandShadow = Color(0x552A7DE1);

// Soft tints and text on tints
const Color kTint = Color(0xFFE8F2FF);
const Color kTintSoft = Color(0xFFF3F8FF);
const Color kOnBrandSoft = Color(0xFFD9EAFF);
const Color kChipText = Color(0xFF174A99);

// Page, text and lines
const Color kBg = Color(0xFFF4F8FE);
const Color kInk = Color(0xFF172033);
const Color kMuted = Color(0xFF5F6B7E);
const Color kLine = Color(0xFFDDE8F5);
const Color kNavy = Color(0xFF0F2A4D);
const Color kBlue = Color(0xFF1E6FD9);

// Home banner sky (dawn scene)
const Color kSkyTop = Color(0xFF1B4F9C);
const Color kSkyMid = Color(0xFF2F7FE0);
const Color kSkyLow = Color(0xFF74B8FF);
const Color kSkyHorizon = Color(0xFFCFE8FF);
const Color kSun = Color(0xFFFFF4C9);
const Color kSunGlow = Color(0x66FFF4C9);
const Color kBirds = Color(0xCCFFFFFF);
const Color kTowerFar = Color(0x660F2E5C);
const Color kTowerMain = Color(0xFF0F2E5C);
const Color kGround = Color(0xFF0B2347);

// Home service tile colours
const Color kTileBus = Color(0xFF2A7DE1);
const Color kTileNews = Color(0xFF0EA5E9);
const Color kTileTrain = Color(0xFF6366F1);
const Color kTileServices = Color(0xFF14B8A6);
const Color kTileParcel = Color(0xFFE0559A);
const Color kTileShops = Color(0xFFF59E0B);
const Color kTileFood = Color(0xFFEF4444);
const Color kTileJobs = Color(0xFF1D4ED8);
const Color kTileReport = Color(0xFF8B5CF6);
const Color kTileAi = Color(0xFF0891B2);
const Color kGreen = Color(0xFF1E8E5A);
const Color kRed = Color(0xFFD32F2F);
const Color kAmber = Color(0xFFF9A825);

/// Header / button gradient used on every screen.
const LinearGradient kHeaderGradient = LinearGradient(
  colors: [kBrandLight, kBrand, kBrandDark],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const LinearGradient kButtonGradient = LinearGradient(colors: [kBrandLight, kBrand]);

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
