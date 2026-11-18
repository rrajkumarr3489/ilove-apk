import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../bus/bus_repo.dart';
import '../theme.dart';

/// Server picture with a soft placeholder (food icon) while loading / when there is none.
class FoodPhoto extends StatelessWidget {
  final String? file;
  final double? width;
  final double? height;
  final double radius;
  final bool gray;

  const FoodPhoto({super.key, this.file, this.width, this.height, this.radius = 16, this.gray = false});

  Widget _ph() => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kTint, kTintSoft], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Center(child: Icon(Icons.restaurant_rounded, color: kBrandMid, size: 34)),
      );

  @override
  Widget build(BuildContext context) {
    final url = (file == null || file!.isEmpty) ? null : repo.mediaUrl(file!);
    Widget w = url == null
        ? _ph()
        : CachedNetworkImage(
            imageUrl: url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            placeholder: (c, u) => _ph(),
            errorWidget: (c, u, e) => _ph(),
          );
    if (gray) {
      w = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: w,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: w);
  }
}

/// The small green / red square used on menus.
class VegDot extends StatelessWidget {
  final bool veg;
  final double size;

  const VegDot({super.key, required this.veg, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final c = veg ? kGreen : kRed;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.22),
      decoration: BoxDecoration(border: Border.all(color: c, width: 1.6), borderRadius: BorderRadius.circular(3)),
      child: DecoratedBox(decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    );
  }
}

/// "- 2 +" control.
class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool compact;

  const QtyStepper({super.key, required this.qty, required this.onMinus, required this.onPlus, this.compact = false});

  Widget _btn(IconData i, VoidCallback f) => InkWell(
        onTap: f,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: compact ? 32 : 38, height: compact ? 32 : 38, child: Icon(i, size: 19, color: Colors.white)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 24,
            child: Text('$qty', textAlign: TextAlign.center, style: ts(15, weight: FontWeight.w800, color: Colors.white)),
          ),
          _btn(Icons.add_rounded, onPlus),
        ],
      ),
    );
  }
}

/// Small rounded rating badge.
class RatingBadge extends StatelessWidget {
  final double rating;
  final int count;

  const RatingBadge({super.key, required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(8)),
        child: Text('NEW', style: ts(11, weight: FontWeight.w800, color: kBrandDark)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(rating.toStringAsFixed(1), style: ts(12, weight: FontWeight.w800, color: Colors.white)),
        const SizedBox(width: 2),
        const Icon(Icons.star_rounded, size: 13, color: Colors.white),
      ]),
    );
  }
}
