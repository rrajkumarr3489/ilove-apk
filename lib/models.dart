import 'package:flutter/material.dart';

/// One entry in any section (a bus route, a temple, a shop, a news item...).
class Item {
  final String id;
  String title;
  String titleTa;
  String subtitle;
  String details;
  String phone;

  /// File name inside the app's local images folder ('' = no image).
  String image;

  Item({
    required this.id,
    this.title = '',
    this.titleTa = '',
    this.subtitle = '',
    this.details = '',
    this.phone = '',
    this.image = '',
  });

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id']?.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: j['title']?.toString() ?? '',
        titleTa: j['titleTa']?.toString() ?? '',
        subtitle: j['subtitle']?.toString() ?? '',
        details: j['details']?.toString() ?? '',
        phone: j['phone']?.toString() ?? '',
        image: j['image']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'titleTa': titleTa,
        'subtitle': subtitle,
        'details': details,
        'phone': phone,
        'image': image,
      };
}

/// A tile on the home screen.
class TileInfo {
  final String key;
  final String title;
  final String titleTa;
  final IconData icon;
  final Color color;

  /// true = has a working list screen; false = "coming soon" for now.
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
      key: 'news',
      title: 'Local News',
      titleTa: 'உள்ளூர் செய்திகள்',
      icon: Icons.newspaper,
      color: Color(0xFFF57C00),
      live: true),
  TileInfo(
      key: 'bus',
      title: 'Bus Timings',
      titleTa: 'பேருந்து நேரங்கள்',
      icon: Icons.directions_bus,
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
      title: 'Local Services',
      titleTa: 'எலக்ட்ரீசியன், பிளம்பர் மற்றும் பல',
      icon: Icons.build,
      color: Color(0xFF2E9E6B)),
  TileInfo(
      key: 'parcel',
      title: 'Parcel Service',
      titleTa: 'பார்சல் சேவை',
      icon: Icons.inventory_2,
      color: Color(0xFFE53950)),
  TileInfo(
      key: 'shops',
      title: 'Local Shops',
      titleTa: 'உள்ளூர் கடைகள்',
      icon: Icons.shopping_bag,
      color: Color(0xFFFFA000),
      live: true),
  TileInfo(
      key: 'food',
      title: 'Local Food',
      titleTa: 'உணவகம் & ஸ்பெஷல்',
      icon: Icons.restaurant,
      color: Color(0xFFEC407A)),
  TileInfo(
      key: 'temples',
      title: 'Temples',
      titleTa: 'கோவில்கள்',
      icon: Icons.temple_hindu,
      color: Color(0xFF8D5524),
      live: true),
  TileInfo(
      key: 'report',
      title: 'Report a Problem',
      titleTa: 'பிரச்சினைகளைத் தெரிவிக்க',
      icon: Icons.campaign,
      color: Color(0xFF5B3FD0)),
  TileInfo(
      key: 'ai',
      title: 'AI Assistant',
      titleTa: 'தமிழில் உதவி பெற',
      icon: Icons.smart_toy,
      color: Color(0xFF1565C0)),
];
