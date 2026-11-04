import 'package:flutter/material.dart';

import 'bus/bus_repo.dart';
import 'theme.dart';

/// A tile on the home screen. Only tiles with [live] = true open a working module.
class TileInfo {
  final String key;
  final String title;
  final String titleTa;
  final IconData icon;
  final Color color;
  final bool live;
  final String tagline;
  final String taglineTa;

  const TileInfo({
    required this.key,
    required this.title,
    required this.titleTa,
    required this.icon,
    required this.color,
    this.live = false,
    this.tagline = '',
    this.taglineTa = '',
  });
}

const List<TileInfo> kTiles = [
  TileInfo(
      key: 'bus',
      title: 'Bus Timings',
      titleTa: 'பேருந்து நேரங்கள்',
      icon: Icons.directions_bus_rounded,
      color: kTileBus,
      live: true),
  TileInfo(
      key: 'news',
      title: 'News',
      titleTa: 'செய்திகள்',
      icon: Icons.newspaper_rounded,
      color: kTileNews,
      live: true),
  TileInfo(
      key: 'train',
      title: 'Train Timings',
      titleTa: 'ரயில் நேரங்கள்',
      icon: Icons.train_rounded,
      color: kTileTrain),
  TileInfo(
      key: 'services',
      title: 'Home Services',
      titleTa: 'உதவி சேவைகள்',
      icon: Icons.build_rounded,
      color: kTileServices),
  TileInfo(
      key: 'parcel',
      title: 'Parcel Service',
      titleTa: 'பார்சல் சேவை',
      icon: Icons.local_shipping_rounded,
      color: kTileParcel),
  TileInfo(
      key: 'shops',
      title: 'Shops',
      titleTa: 'கடைகள்',
      icon: Icons.storefront_rounded,
      color: kTileShops),
  TileInfo(
      key: 'food',
      title: 'Food & Hotels',
      titleTa: 'உணவகங்கள்',
      icon: Icons.restaurant_rounded,
      color: kTileFood),
  TileInfo(
      key: 'classifieds',
      title: 'Jobs',
      titleTa: 'வேலை வாய்ப்புகள்',
      icon: Icons.work_outline_rounded,
      color: kTileJobs,
      live: true,
      tagline: 'Jobs near Aruppukottai',
      taglineTa: 'அருப்புக்கோட்டை அருகில் வேலைகள்'),
  TileInfo(
      key: 'report',
      title: 'Report a Problem',
      titleTa: 'பிரச்சனை தெரிவிக்க',
      icon: Icons.campaign_rounded,
      color: kTileReport,
      live: true,
      tagline: 'Tell us about any problem',
      taglineTa: 'எந்த சிக்கலையும் தெரிவியுங்கள்'),
  TileInfo(
      key: 'ai',
      title: 'AI Assistant',
      titleTa: 'AI உதவியாளர்',
      icon: Icons.smart_toy_rounded,
      color: kTileAi),
];

IconData _iconFor(String name) {
  switch (name) {
    case 'article':
      return Icons.newspaper_rounded;
    case 'directions_bus':
      return Icons.directions_bus_rounded;
    case 'train':
      return Icons.train_rounded;
    case 'build':
      return Icons.build_rounded;
    case 'local_shipping':
      return Icons.local_shipping_rounded;
    case 'store':
      return Icons.storefront_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'temple_hindu':
      return Icons.temple_hindu_rounded;
    case 'work':
      return Icons.work_outline_rounded;
    case 'report_problem':
      return Icons.campaign_rounded;
    case 'smart_toy':
      return Icons.smart_toy_rounded;
    default:
      return Icons.apps_rounded;
  }
}

Color _colorFor(String hex, Color fallback) {
  if (hex.length != 7 || !hex.startsWith('#')) return fallback;
  final v = int.tryParse(hex.substring(1), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// The home-screen sections. They come from the server (names, taglines, colours, which are live),
/// so they can be changed without a new APK. If the server list has not been downloaded yet, the built-in list is used.
List<TileInfo> currentTiles() {
  if (repo.sections.isEmpty) return kTiles;
  final list = <TileInfo>[];
  final rows = List<Map<String, dynamic>>.of(repo.sections);
  rows.sort((a, b) => ((a['sortOrder'] as num?) ?? 0).compareTo((b['sortOrder'] as num?) ?? 0));
  for (final r in rows) {
    final key = (r['sectionKey'] ?? '').toString();
    final fallback = kTiles.where((t) => t.key == key).toList();
    final base = fallback.isEmpty ? null : fallback.first;
    list.add(TileInfo(
      key: key,
      title: (r['nameEn'] ?? '').toString(),
      titleTa: (r['nameTa'] ?? '').toString(),
      icon: _iconFor((r['iconName'] ?? '').toString()),
      color: _colorFor((r['colorHex'] ?? '').toString(), base == null ? kBlue : base.color),
      live: (r['isLive'] == true && key == 'bus') || key == 'news' || key == 'classifieds' || key == 'report',
      tagline: (r['taglineEn'] ?? '').toString(),
      taglineTa: (r['taglineTa'] ?? '').toString(),
    ));
  }
  return list;
}
