import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../bus/bus_repo.dart';
import '../theme.dart';
import 'food_models.dart';

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

const List<List<Color>> kCoverGradients = [
  [Color(0xFF1B4F9C), Color(0xFF4DA3FF)],
  [Color(0xFFB4232C), Color(0xFFFF7A59)],
  [Color(0xFF0F7B6C), Color(0xFF3CCB9A)],
  [Color(0xFF6A3DB8), Color(0xFFB07CFF)],
  [Color(0xFFC2570C), Color(0xFFFFB347)],
  [Color(0xFF0F2A4D), Color(0xFF2F7FE0)],
];

const List<IconData> _kPatternIcons = [
  Icons.ramen_dining_rounded,
  Icons.rice_bowl_rounded,
  Icons.local_pizza_rounded,
  Icons.bakery_dining_rounded,
  Icons.lunch_dining_rounded,
  Icons.set_meal_rounded,
];

/// Cover for a hotel: its photo when there is one, otherwise a rich coloured gradient with a
/// soft food pattern and the hotel's first letter. Fills the space it is given.
class HotelCover extends StatelessWidget {
  final FoodHotel hotel;
  final bool gray;

  const HotelCover({super.key, required this.hotel, this.gray = false});

  @override
  Widget build(BuildContext context) {
    final g = kCoverGradients[hotel.id.abs() % kCoverGradients.length];
    final hasPhoto = hotel.picture != null && hotel.picture!.isNotEmpty && repo.mediaUrl(hotel.picture!) != null;
    final letter = hotel.nameEn.isEmpty ? '?' : String.fromCharCode(hotel.nameEn.runes.first).toUpperCase();
    Widget base;
    if (hasPhoto) {
      base = LayoutBuilder(
        builder: (c, box) => FoodPhoto(file: hotel.picture, width: box.maxWidth, height: box.maxHeight, radius: 0),
      );
    } else {
      base = Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          ),
          for (var i = 0; i < 6; i++)
            Positioned(
              left: i.isEven ? -10.0 + i * 52 : null,
              right: i.isOdd ? -8.0 + i * 20 : null,
              top: i < 3 ? -6.0 + i * 12 : null,
              bottom: i >= 3 ? -8.0 + (i - 3) * 10 : null,
              child: Transform.rotate(
                angle: (i - 2) * 0.35,
                child: Icon(_kPatternIcons[(i + hotel.id) % _kPatternIcons.length], size: 64 + (i % 3) * 14, color: Colors.white.withAlpha(26)),
              ),
            ),
          Center(
            child: Container(
              width: 74,
              height: 74,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(46),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(110), width: 2),
              ),
              child: Text(letter, style: ts(34, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      );
    }
    if (gray) {
      base = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: base,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color(0x33000000), Color(0x00000000), Color(0x99000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, 0.45, 1]),
          ),
        ),
      ],
    );
  }
}

/// Square thumbnail for a menu item: its photo, or a tinted tile with a food icon.
class FoodThumb extends StatelessWidget {
  final FoodItem item;
  final double size;
  final bool gray;

  const FoodThumb({super.key, required this.item, this.size = 100, this.gray = false});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = item.picture != null && item.picture!.isNotEmpty && repo.mediaUrl(item.picture!) != null;
    if (hasPhoto) return FoodPhoto(file: item.picture, width: size, height: size, radius: 18, gray: gray);
    final g = item.veg ? const [Color(0xFFE3F6EC), Color(0xFFC4EBD6)] : const [Color(0xFFFDE8E6), Color(0xFFF9C9C4)];
    final c = item.veg ? kGreen : kRed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(item.veg ? Icons.rice_bowl_rounded : Icons.lunch_dining_rounded, size: size * 0.42, color: c.withAlpha(150)),
    );
  }
}

/// Fades and slides its child in; later items start a little later.
class FadeSlide extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlide({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + (index > 6 ? 6 : index) * 70),
      curve: Curves.easeOutCubic,
      builder: (c, v, w) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: w)),
      child: child,
    );
  }
}

/// Pulsing grey block shown while the list loads.
class PulseBox extends StatefulWidget {
  final double height;
  final double radius;

  const PulseBox({super.key, required this.height, this.radius = 22});

  @override
  State<PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<PulseBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}
