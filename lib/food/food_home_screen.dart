import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets.dart';
import 'cart_screen.dart';
import 'food_cart.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';
import 'hotel_menu_screen.dart';

class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  final TextEditingController _q = TextEditingController();
  bool _veg = false;
  bool _open = false;
  bool _delivery = false;

  @override
  void initState() {
    super.initState();
    food.loadHotels(force: true);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<FoodHotel> _filtered() {
    final q = _q.text.trim().toLowerCase();
    return food.hotels.where((h) {
      if (_veg && !h.pureVeg) return false;
      if (_open && !(h.openNow && h.acceptsOrders)) return false;
      if (_delivery && !h.canDeliver) return false;
      if (q.isNotEmpty && !h.searchText.contains(q)) return false;
      return true;
    }).toList();
  }

  Widget _header() {
    return AppHeader(
      bubbles: false,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.tr('Food & Hotels', 'உணவகங்கள்'), style: ts(20, weight: FontWeight.w800, color: Colors.white)),
                    Text(app.tr('Hot food from Aruppukottai hotels', 'அருப்புக்கோட்டை ஹோட்டல்களில் இருந்து சுடச்சுட'),
                        style: ts(12, color: kOnBrandSoft)),
                  ],
                ),
              ),
              const LangToggle(onDark: true),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              height: 46,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                style: ts(14),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: kBrand),
                  hintText: app.tr('Search hotel or food…', 'ஹோட்டல் / உணவு தேடுங்கள்…'),
                  hintStyle: ts(14, color: kMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, bool on, VoidCallback f) {
    return GestureDetector(
      onTap: f,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: on ? kBrand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? kBrand : kLine),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: on ? Colors.white : kBrand),
          const SizedBox(width: 5),
          Text(label, style: ts(12.5, weight: FontWeight.w700, color: on ? Colors.white : kChipText)),
        ]),
      ),
    );
  }

  Widget _filters() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _pill(app.tr('Pure Veg', 'சைவம்'), Icons.eco_rounded, _veg, () => setState(() => _veg = !_veg)),
          const SizedBox(width: 8),
          _pill(app.tr('Open now', 'இப்போது திறந்துள்ளது'), Icons.schedule_rounded, _open, () => setState(() => _open = !_open)),
          const SizedBox(width: 8),
          _pill(app.tr('Home delivery', 'வீட்டு டெலிவரி'), Icons.delivery_dining_rounded, _delivery, () => setState(() => _delivery = !_delivery)),
        ],
      ),
    );
  }

  Widget _card(FoodHotel h) {
    final closed = !h.openNow || !h.acceptsOrders;
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelMenuScreen(hotel: h))),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x142A7DE1), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: FoodPhoto(file: h.picture, radius: 22, gray: closed),
                ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Row(children: [
                    if (h.pureVeg)
                      _tag(app.tr('PURE VEG', 'சைவம்'), kGreen),
                    if (closed) ...[
                      if (h.pureVeg) const SizedBox(width: 6),
                      _tag(h.openNow ? app.tr('NOT TAKING ORDERS', 'ஆர்டர் இல்லை') : app.tr('CLOSED NOW', 'மூடப்பட்டுள்ளது'), kNavy),
                    ],
                  ]),
                ),
                Positioned(right: 12, bottom: 12, child: RatingBadge(rating: h.rating, count: h.ratingCount)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(18, weight: FontWeight.w800)),
                  if (h.cuisine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(h.cuisine, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, color: kMuted)),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      _info(Icons.timer_outlined, '${h.prepMinutes}-${h.prepMinutes + 10} ${app.tr('min', 'நிமி')}'),
                      _info(Icons.delivery_dining_rounded, h.deliveryText),
                      if (h.priceFrom != null) _info(Icons.currency_rupee_rounded, app.tr('From ${rupee(h.priceFrom!)}', '${rupee(h.priceFrom!)} முதல்')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: ts(10.5, weight: FontWeight.w800, color: Colors.white)),
      );

  Widget _info(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 15, color: kBrand),
        const SizedBox(width: 4),
        Text(t, style: ts(12.5, weight: FontWeight.w600, color: kChipText)),
      ]);

  Widget _state(IconData icon, String title, String sub, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 20),
      child: Column(children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle),
          child: Icon(icon, size: 40, color: kBrand),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: ts(17, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: ts(13, color: kMuted, height: 1.4)),
        if (retry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(app.tr('Try again', 'மீண்டும் முயற்சி'))),
        ],
      ]),
    );
  }

  Widget _skeleton() => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        height: 250,
        decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(22)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([food, app, cart]),
      builder: (context, _) {
        final list = _filtered();
        Widget body;
        if (food.loading && !food.loadedOnce) {
          body = Column(children: [_skeleton(), _skeleton()]);
        } else if (food.error != null && !food.loadedOnce) {
          body = _state(Icons.wifi_off_rounded, app.tr('Could not load hotels', 'ஹோட்டல்களை ஏற்ற முடியவில்லை'), food.error!,
              retry: () => food.loadHotels(force: true));
        } else if (food.hotels.isEmpty) {
          body = _state(Icons.storefront_rounded, app.tr('Hotels are coming soon', 'ஹோட்டல்கள் விரைவில்'),
              app.tr('We are adding Aruppukottai hotels. Check back soon!', 'அருப்புக்கோட்டை ஹோட்டல்களை சேர்த்து வருகிறோம். விரைவில் வாருங்கள்!'));
        } else if (list.isEmpty) {
          body = _state(Icons.search_off_rounded, app.tr('No match', 'எதுவும் கிடைக்கவில்லை'),
              app.tr('Try another name or remove a filter.', 'வேறு பெயர் அல்லது filter-ஐ நீக்கி பாருங்கள்.'));
        } else {
          body = Column(children: [for (final h in list) _card(h)]);
        }
        return Scaffold(
          backgroundColor: kBg,
          body: Column(
            children: [
              _header(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => food.loadHotels(force: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(top: 14, bottom: cart.isEmpty ? 24 : 96),
                    children: [
                      _filters(),
                      const SizedBox(height: 14),
                      body,
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: cart.isEmpty ? null : const CartBar(),
        );
      },
    );
  }
}

/// Floating blue bar: "2 items · ₹240   View cart".
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: kHeaderGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: kBrandShadow, blurRadius: 16, offset: Offset(0, 6))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cart.count} ${cart.count == 1 ? app.tr('item', 'பொருள்') : app.tr('items', 'பொருட்கள்')} · ${rupee(cart.itemsTotal)}',
                      style: ts(15, weight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(cart.hotel?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, color: kOnBrandSoft)),
                  ],
                ),
              ),
              Text(app.tr('View cart', 'கார்ட் பார்க்க'), style: ts(14, weight: FontWeight.w800, color: Colors.white)),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ]),
          ),
        ),
      ),
    );
  }
}
