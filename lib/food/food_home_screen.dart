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

class _Cuisine {
  final String en;
  final String ta;
  final IconData icon;
  final String key; // words searched in the hotel's name / cuisine, split by |

  const _Cuisine(this.en, this.ta, this.icon, this.key);
}

const List<_Cuisine> _kCuisines = [
  _Cuisine('All', 'அனைத்தும்', Icons.apps_rounded, ''),
  _Cuisine('Tiffin', 'டிபன்', Icons.breakfast_dining_rounded, 'tiffin|டிபன்|idli|dosa|இட்லி|தோசை'),
  _Cuisine('Meals', 'சாப்பாடு', Icons.rice_bowl_rounded, 'meals|mess|சாப்பாடு|மெஸ்'),
  _Cuisine('Biriyani', 'பிரியாணி', Icons.dinner_dining_rounded, 'biriyani|biryani|பிரியாணி'),
  _Cuisine('Snacks', 'ஸ்நாக்ஸ்', Icons.bakery_dining_rounded, 'snack|chat|bakery|ஸ்நாக்ஸ்|பேக்கரி'),
  _Cuisine('Tea & Juice', 'டீ / ஜூஸ்', Icons.local_cafe_rounded, 'tea|coffee|juice|டீ|காபி|ஜூஸ்'),
  _Cuisine('Sweets', 'இனிப்பு', Icons.cake_rounded, 'sweet|இனிப்பு|ஸ்வீட்'),
];

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
  int _cuisine = 0;

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
    final words = _kCuisines[_cuisine].key.isEmpty ? <String>[] : _kCuisines[_cuisine].key.split('|');
    return food.hotels.where((h) {
      if (_veg && !h.pureVeg) return false;
      if (_open && !(h.openNow && h.acceptsOrders)) return false;
      if (_delivery && !h.canDeliver) return false;
      if (q.isNotEmpty && !h.searchText.contains(q)) return false;
      if (words.isNotEmpty && !words.any((w) => h.searchText.contains(w))) return false;
      return true;
    }).toList();
  }

  Widget _header() {
    return AppHeader(
      bubbles: false,
      radius: 30,
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 18),
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
                    Row(children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: kOnBrandSoft),
                      const SizedBox(width: 3),
                      Text(app.tr('Delivering in', 'டெலிவரி'), style: ts(11.5, color: kOnBrandSoft)),
                    ]),
                    Text(app.tr('Aruppukottai', 'அருப்புக்கோட்டை'), style: ts(19, weight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
              const LangToggle(onDark: true),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x330B2347), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                style: ts(14.5),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  prefixIcon: const Icon(Icons.search_rounded, color: kBrand),
                  suffixIcon: _q.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20, color: kMuted),
                          onPressed: () => setState(_q.clear),
                        ),
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

  Widget _banner() {
    return FadeSlide(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        height: 118,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F2A4D), Color(0xFF2F7FE0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x332A7DE1), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Stack(
          children: [
            Positioned(right: -18, bottom: -22, child: Icon(Icons.ramen_dining_rounded, size: 150, color: Colors.white.withAlpha(30))),
            Positioned(right: 70, top: -20, child: Icon(Icons.local_pizza_rounded, size: 80, color: Colors.white.withAlpha(22))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 120, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(36), borderRadius: BorderRadius.circular(8)),
                    child: Text(app.tr('OUR TOWN · OUR FOOD', 'நம் ஊர் · நம் உணவு'), style: ts(10, weight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 8),
                  Text(app.tr('Hot food, right at your door', 'சுடச்சுட உணவு, உங்கள் வீட்டு வாசலில்'),
                      style: ts(18, weight: FontWeight.w800, color: Colors.white, height: 1.2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuisineRow() {
    return SizedBox(
      height: 92,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _kCuisines.length,
        itemBuilder: (c, i) {
          final cu = _kCuisines[i];
          final on = _cuisine == i;
          return GestureDetector(
            onTap: () => setState(() => _cuisine = i),
            child: Container(
              width: 74,
              color: Colors.transparent,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: on ? kHeaderGradient : null,
                    color: on ? null : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: on ? kBrandShadow : const Color(0x142A7DE1), blurRadius: on ? 14 : 8, offset: const Offset(0, 4))],
                  ),
                  child: Icon(cu.icon, size: 26, color: on ? Colors.white : kBrand),
                ),
                const SizedBox(height: 6),
                Text(app.tr(cu.en, cu.ta), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, weight: on ? FontWeight.w800 : FontWeight.w600, color: on ? kBrandDark : kInk)),
              ]),
            ),
          );
        },
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
      height: 38,
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

  Widget _title(String t, {String? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(t, style: ts(18, weight: FontWeight.w800)),
          const Spacer(),
          if (trailing != null) Text(trailing, style: ts(13, weight: FontWeight.w700, color: kMuted)),
        ]),
      );

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.black.withAlpha(110), borderRadius: BorderRadius.circular(10)),
        child: child,
      );

  Widget _card(FoodHotel h, int index) {
    final closed = !h.openNow || !h.acceptsOrders;
    final offer = (h.canDeliver && h.freeAbove != null && h.freeAbove! > 0 && h.deliveryFee > 0)
        ? app.tr('Free delivery above ${rupee(h.freeAbove!)}', '${rupee(h.freeAbove!)}-க்கு மேல் இலவச டெலிவரி')
        : (h.canDeliver && h.deliveryFee <= 0 ? app.tr('Free delivery', 'இலவச டெலிவரி') : null);
    return FadeSlide(
      index: index,
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HotelMenuScreen(hotel: h))),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [BoxShadow(color: Color(0x1A2A7DE1), blurRadius: 22, offset: Offset(0, 10))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                child: SizedBox(
                  height: 176,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      HotelCover(hotel: h, gray: closed),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Row(children: [
                          if (h.pureVeg)
                            _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.eco_rounded, size: 13, color: Color(0xFF7BE0A8)),
                              const SizedBox(width: 4),
                              Text(app.tr('PURE VEG', 'சைவம்'), style: ts(10.5, weight: FontWeight.w800, color: Colors.white)),
                            ])),
                        ]),
                      ),
                      if (closed)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(10)),
                            child: Text(h.openNow ? app.tr('NOT TAKING ORDERS', 'ஆர்டர் இல்லை') : app.tr('CLOSED', 'மூடப்பட்டது'),
                                style: ts(10.5, weight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      if (offer != null)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.local_offer_rounded, size: 14, color: kBrand),
                              const SizedBox(width: 5),
                              Text(offer, style: ts(11.5, weight: FontWeight.w800, color: kBrandDark)),
                            ]),
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${h.prepMinutes}-${h.prepMinutes + 10} ${app.tr('min', 'நிமி')}', style: ts(12, weight: FontWeight.w800, color: Colors.white)),
                        ])),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(19, weight: FontWeight.w800))),
                      const SizedBox(width: 8),
                      RatingBadge(rating: h.rating, count: h.ratingCount),
                    ]),
                    if (h.cuisine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(h.cuisine, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, color: kMuted)),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(color: kTintSoft, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _info(Icons.delivery_dining_rounded, h.deliveryText),
                          if (h.minOrder > 0) _info(Icons.shopping_basket_outlined, app.tr('Min ${rupee(h.minOrder)}', 'குறைந்தது ${rupee(h.minOrder)}')),
                          if (h.priceFrom != null) _info(Icons.currency_rupee_rounded, app.tr('From ${rupee(h.priceFrom!)}', '${rupee(h.priceFrom!)} முதல்')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 15, color: kBrand),
        const SizedBox(width: 4),
        Text(t, style: ts(12, weight: FontWeight.w700, color: kChipText)),
      ]);

  Widget _state(IconData icon, String title, String sub, {VoidCallback? retry}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
      child: Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle),
          child: Icon(icon, size: 44, color: kBrand),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: ts(18, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: ts(13.5, color: kMuted, height: 1.4)),
        if (retry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(app.tr('Try again', 'மீண்டும் முயற்சி'))),
        ],
      ]),
    );
  }

  Widget _skeleton() => const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 20), child: PulseBox(height: 270, radius: 26));

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
          body = Column(children: [for (var i = 0; i < list.length; i++) _card(list[i], i)]);
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
                    padding: EdgeInsets.only(top: 18, bottom: cart.isEmpty ? 24 : 96),
                    children: [
                      _banner(),
                      _cuisineRow(),
                      const SizedBox(height: 10),
                      _filters(),
                      _title(app.tr('Hotels near you', 'உங்கள் அருகில் உள்ள ஹோட்டல்கள்'), trailing: food.loadedOnce ? '${list.length}' : null),
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
