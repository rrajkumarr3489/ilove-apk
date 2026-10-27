import 'package:flutter/material.dart';

import 'bus/bus_repo.dart';

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
      icon: Icons.directions_bus,
      color: Color(0xFFE8590C),
      live: true),
  TileInfo(
      key: 'news',
      title: 'News',
      titleTa: 'செய்திகள்',
      icon: Icons.newspaper,
      color: Color(0xFF1E88E5),
      live: true),
  TileInfo(
      key: 'train',
      title: 'Train Timings',
      titleTa: 'ரயில் நேரங்கள்',
      icon: Icons.train,
      color: Color(0xFF5E35B1)),
  TileInfo(
      key: 'services',
      title: 'Home Services',
      titleTa: 'உதவி சேவைகள்',
      icon: Icons.build,
      color: Color(0xFF00897B)),
  TileInfo(
      key: 'parcel',
      title: 'Parcel Service',
      titleTa: 'பார்சல் சேவை',
      icon: Icons.local_shipping,
      color: Color(0xFFD81B60)),
  TileInfo(
      key: 'shops',
      title: 'Shops',
      titleTa: 'கடைகள்',
      icon: Icons.storefront,
      color: Color(0xFFF9A825)),
  TileInfo(
      key: 'food',
      title: 'Food & Hotels',
      titleTa: 'உணவகங்கள்',
      icon: Icons.restaurant,
      color: Color(0xFFE53935)),
  TileInfo(
      key: 'temples',
      title: 'Temples',
      titleTa: 'கோயில்கள்',
      icon: Icons.temple_hindu,
      color: Color(0xFF8D5524)),
  TileInfo(
      key: 'report',
      title: 'Report a Problem',
      titleTa: 'பிரச்சனை தெரிவிக்க',
      icon: Icons.campaign,
      color: Color(0xFF6A1B9A)),
  TileInfo(
      key: 'ai',
      title: 'AI Assistant',
      titleTa: 'AI உதவியாளர்',
      icon: Icons.smart_toy,
      color: Color(0xFF1565C0)),
];

IconData _iconFor(String name) {
  switch (name) {
    case 'article':
      return Icons.newspaper;
    case 'directions_bus':
      return Icons.directions_bus;
    case 'train':
      return Icons.train;
    case 'build':
      return Icons.build;
    case 'local_shipping':
      return Icons.local_shipping;
    case 'store':
      return Icons.storefront;
    case 'restaurant':
      return Icons.restaurant;
    case 'temple_hindu':
      return Icons.temple_hindu;
    case 'report_problem':
      return Icons.campaign;
    case 'smart_toy':
      return Icons.smart_toy;
    default:
      return Icons.apps;
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
      color: _colorFor((r['colorHex'] ?? '').toString(), base == null ? const Color(0xFF1B6CA8) : base.color),
      live: (r['isLive'] == true && key == 'bus') || key == 'news',
      tagline: (r['taglineEn'] ?? '').toString(),
      taglineTa: (r['taglineTa'] ?? '').toString(),
    ));
  }
  return list;
}
