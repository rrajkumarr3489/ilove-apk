import 'package:flutter/material.dart';

/// A tile on the home screen. Only tiles with [live] = true open a working module.
class TileInfo {
  final String key;
  final String title;
  final String titleTa;
  final IconData icon;
  final Color color;
  final bool live;

  const TileInfo({
    required this.key,
    required this.title,
    required this.titleTa,
    required this.icon,
    required this.color,
    this.live = false,
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
      title: 'Local News',
      titleTa: 'உள்ளூர் செய்திகள்',
      icon: Icons.newspaper,
      color: Color(0xFF1E88E5)),
  TileInfo(
      key: 'train',
      title: 'Train Timings',
      titleTa: 'ரயில் நேரங்கள்',
      icon: Icons.train,
      color: Color(0xFF5E35B1)),
  TileInfo(
      key: 'services',
      title: 'Local Services',
      titleTa: 'உள்ளூர் சேவைகள்',
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
      title: 'Local Shops',
      titleTa: 'உள்ளூர் கடைகள்',
      icon: Icons.storefront,
      color: Color(0xFFF9A825)),
  TileInfo(
      key: 'food',
      title: 'Local Food',
      titleTa: 'உள்ளூர் உணவு',
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
