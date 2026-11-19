import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'food_models.dart';
import 'food_widgets.dart';

enum FoodSort { relevance, rating, time, priceLow, priceHigh, name }

/// What the customer chose in "Filters and sorting". Also used by the quick chips on the home screen.
class FoodFilters {
  FoodSort sort = FoodSort.relevance;
  bool veg = false;
  bool open = false;
  bool fast = false;
  double minRating = 0; // 0, 3.5, 4.0 or 4.5
  bool free = false;
  bool delivery = false;
  bool pickup = false;
  double? maxPrice; // hotel's lowest dish price must be at or below this

  FoodFilters copy() => FoodFilters()
    ..sort = sort
    ..veg = veg
    ..open = open
    ..fast = fast
    ..minRating = minRating
    ..free = free
    ..delivery = delivery
    ..pickup = pickup
    ..maxPrice = maxPrice;

  void clear() {
    sort = FoodSort.relevance;
    veg = open = fast = free = delivery = pickup = false;
    minRating = 0;
    maxPrice = null;
  }

  /// Number of things switched on (sorting counts as one).
  int get count => [veg, open, fast, free, delivery, pickup, minRating > 0, maxPrice != null, sort != FoodSort.relevance].where((e) => e).length;

  bool allows(FoodHotel h) {
    if (veg && !h.pureVeg) return false;
    if (open && !(h.openNow && h.acceptsOrders)) return false;
    if (fast && h.prepMinutes > 20) return false;
    if (minRating > 0 && !(h.ratingCount > 0 && h.rating >= minRating)) return false;
    if (free && !(h.canDeliver && (h.deliveryFee <= 0 || (h.freeAbove != null && h.freeAbove! > 0)))) return false;
    if (delivery && !h.canDeliver) return false;
    if (pickup && !h.canPickup) return false;
    if (maxPrice != null && !(h.priceFrom != null && h.priceFrom! <= maxPrice!)) return false;
    return true;
  }

  List<FoodHotel> apply(List<FoodHotel> all) {
    final list = all.where(allows).toList();
    bool isOpen(FoodHotel h) => h.openNow && h.acceptsOrders;
    switch (sort) {
      case FoodSort.relevance:
        list.sort((a, b) {
          if (isOpen(a) != isOpen(b)) return isOpen(a) ? -1 : 1;
          return b.rating.compareTo(a.rating);
        });
        break;
      case FoodSort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case FoodSort.time:
        list.sort((a, b) => a.prepMinutes.compareTo(b.prepMinutes));
        break;
      case FoodSort.priceLow:
        list.sort((a, b) => (a.priceFrom ?? 1e9).compareTo(b.priceFrom ?? 1e9));
        break;
      case FoodSort.priceHigh:
        list.sort((a, b) => (b.priceFrom ?? -1).compareTo(a.priceFrom ?? -1));
        break;
      case FoodSort.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
    }
    return list;
  }
}

String _sortLabel(FoodSort s) {
  switch (s) {
    case FoodSort.relevance:
      return app.tr('Relevance', 'பொருத்தம்');
    case FoodSort.rating:
      return app.tr('Rating: High to Low', 'மதிப்பீடு: அதிகம் → குறைவு');
    case FoodSort.time:
      return app.tr('Delivery Time: Low to High', 'நேரம்: குறைவு → அதிகம்');
    case FoodSort.priceLow:
      return app.tr('Cost: Low to High', 'விலை: குறைவு → அதிகம்');
    case FoodSort.priceHigh:
      return app.tr('Cost: High to Low', 'விலை: அதிகம் → குறைவு');
    case FoodSort.name:
      return app.tr('Name: A to Z', 'பெயர்: A → Z');
  }
}

/// Opens the Zomato-style sheet. [hotels] is the full list (used for the "Show N" count). Returns the new filters, or null if closed.
Future<FoodFilters?> showFoodFilters(BuildContext context, FoodFilters current, List<FoodHotel> hotels) {
  return showModalBottomSheet<FoodFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x99081A33),
    builder: (c) => foodScale(c, _FilterSheet(start: current.copy(), hotels: hotels)),
  );
}

class _FilterSheet extends StatefulWidget {
  final FoodFilters start;
  final List<FoodHotel> hotels;

  const _FilterSheet({required this.start, required this.hotels});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late FoodFilters f = widget.start;
  int _tab = 0;

  static const _tabs = <List<Object>>[
    ['Sort By', 'வரிசை', Icons.swap_vert_rounded],
    ['Time', 'நேரம்', Icons.timer_outlined],
    ['Rating', 'மதிப்பீடு', Icons.star_border_rounded],
    ['Offers', 'சலுகை', Icons.local_offer_outlined],
    ['Dish Price', 'விலை', Icons.currency_rupee_rounded],
    ['Type', 'வகை', Icons.restaurant_menu_rounded],
  ];

  int get _results => widget.hotels.where(f.allows).length;

  Widget _tile(String label, IconData icon, bool on, VoidCallback tap, {Color? iconColor}) {
    return GestureDetector(
      onTap: () => setState(tap),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: on ? kTint : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? kBrand : Colors.transparent, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x141B4F9C), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 24, color: iconColor ?? (on ? kBrand : kNavy)),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: ts(13.5, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? kBrandDark : kInk)),
        ]),
      ),
    );
  }

  Widget _grid(List<Widget> tiles) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Row(children: [
        Expanded(child: tiles[i]),
        const SizedBox(width: 12),
        Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink()),
      ]));
      rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  Widget _card(String title, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: ts(17, weight: FontWeight.w700)),
          const SizedBox(height: 14),
          child,
        ]),
      );

  Widget _sortCard() {
    return _card(
      app.tr('Sort by', 'வரிசைப்படுத்து'),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(children: [
          for (var i = 0; i < FoodSort.values.length; i++) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => f.sort = FoodSort.values[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: f.sort == FoodSort.values[i] ? kTint : Colors.transparent,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(i == 0 ? 16 : 0), bottom: Radius.circular(i == FoodSort.values.length - 1 ? 16 : 0)),
                ),
                child: Row(children: [
                  Expanded(child: Text(_sortLabel(FoodSort.values[i]), style: ts(15, weight: f.sort == FoodSort.values[i] ? FontWeight.w700 : FontWeight.w500))),
                  Icon(f.sort == FoodSort.values[i] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: f.sort == FoodSort.values[i] ? kBrand : kMuted),
                ]),
              ),
            ),
            if (i != FoodSort.values.length - 1) const Divider(height: 1, color: kLine),
          ],
        ]),
      ),
    );
  }

  Widget _content() {
    switch (_tab) {
      case 0:
        return _sortCard();
      case 1:
        return _card(
          app.tr('Time', 'நேரம்'),
          _grid([
            _tile(app.tr('Near & Fast', 'அருகில் & விரைவு'), Icons.bolt_rounded, f.fast, () => f.fast = !f.fast, iconColor: kGreen),
            _tile(app.tr('Open now', 'திறந்துள்ளது'), Icons.schedule_rounded, f.open, () => f.open = !f.open),
          ]),
        );
      case 2:
        return _card(
          app.tr('Hotel Rating', 'ஹோட்டல் மதிப்பீடு'),
          _grid([
            _tile(app.tr('Rated 3.5+', '3.5+ மதிப்பீடு'), Icons.star_rounded, f.minRating == 3.5, () => f.minRating = f.minRating == 3.5 ? 0 : 3.5, iconColor: kGreen),
            _tile(app.tr('Rated 4.0+', '4.0+ மதிப்பீடு'), Icons.star_rounded, f.minRating == 4.0, () => f.minRating = f.minRating == 4.0 ? 0 : 4.0, iconColor: kGreen),
            _tile(app.tr('Rated 4.5+', '4.5+ மதிப்பீடு'), Icons.star_rounded, f.minRating == 4.5, () => f.minRating = f.minRating == 4.5 ? 0 : 4.5, iconColor: kGreen),
          ]),
        );
      case 3:
        return _card(
          app.tr('Offers', 'சலுகைகள்'),
          _grid([
            _tile(app.tr('Free delivery', 'இலவச டெலிவரி'), Icons.local_offer_rounded, f.free, () => f.free = !f.free),
          ]),
        );
      case 4:
        return _card(
          app.tr('Dish Price', 'உணவு விலை'),
          _grid([
            _tile(app.tr('Under ₹100', '₹100-க்குள்'), Icons.currency_rupee_rounded, f.maxPrice == 100, () => f.maxPrice = f.maxPrice == 100 ? null : 100),
            _tile(app.tr('Under ₹200', '₹200-க்குள்'), Icons.currency_rupee_rounded, f.maxPrice == 200, () => f.maxPrice = f.maxPrice == 200 ? null : 200),
          ]),
        );
      default:
        return _card(
          app.tr('Type', 'வகை'),
          _grid([
            _tile(app.tr('Pure Veg', 'சைவம்'), Icons.eco_rounded, f.veg, () => f.veg = !f.veg, iconColor: kGreen),
            _tile(app.tr('Home delivery', 'வீட்டு டெலிவரி'), Icons.delivery_dining_rounded, f.delivery, () => f.delivery = !f.delivery),
            _tile(app.tr('Pickup', 'நேரில் எடுக்க'), Icons.storefront_rounded, f.pickup, () => f.pickup = !f.pickup),
          ]),
        );
    }
  }

  Widget _railItem(int i) {
    final on = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        decoration: BoxDecoration(
          color: on ? kTint : Colors.transparent,
          border: Border(left: BorderSide(color: on ? kBrand : Colors.transparent, width: 4)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_tabs[i][2] as IconData, size: 24, color: on ? kBrand : kMuted),
          const SizedBox(height: 6),
          Text(app.tr(_tabs[i][0] as String, _tabs[i][1] as String), textAlign: TextAlign.center, style: ts(12, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? kInk : kMuted)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final n = _results;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 46,
          height: 46,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: const BoxDecoration(color: Color(0xFF1A2233), shape: BoxShape.circle),
          child: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
      Container(
        height: h * 0.74,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(children: [
              Expanded(child: Text(app.tr('Filters and sorting', 'Filter & வரிசை'), style: ts(20, weight: FontWeight.w700))),
              GestureDetector(
                onTap: () => setState(() => f.clear()),
                child: Text(app.tr('Clear all', 'அனைத்தும் அழி'), style: ts(14.5, weight: FontWeight.w600, color: f.count > 0 ? kBrand : kMuted)),
              ),
            ]),
          ),
          const Divider(height: 1, color: kLine),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 92,
                decoration: const BoxDecoration(border: Border(right: BorderSide(color: kLine))),
                child: SingleChildScrollView(child: Column(children: [for (var i = 0; i < _tabs.length; i++) _railItem(i)])),
              ),
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(14), child: _content())),
            ]),
          ),
          const Divider(height: 1, color: kLine),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(app.tr('Close', 'மூடு'), style: ts(16, weight: FontWeight.w600, color: kMuted)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: n == 0 ? null : () => Navigator.pop(context, f),
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: n == 0 ? null : const LinearGradient(colors: [kNavy, kBrandDark]),
                        color: n == 0 ? kLine : null,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        n == 0 ? app.tr('No hotels match', 'எதுவும் இல்லை') : (f.count == 0 ? app.tr('Show results', 'முடிவுகள்') : app.tr('Show $n hotels', '$n ஹோட்டல்கள் காட்டு')),
                        style: ts(16, weight: FontWeight.w700, color: n == 0 ? kMuted : Colors.white),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}
