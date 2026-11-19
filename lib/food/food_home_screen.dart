import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';
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
  final String emoji;
  final Color tint;
  final String key; // words searched in the hotel's name / cuisine, split by |

  const _Cuisine(this.en, this.ta, this.emoji, this.tint, this.key);
}

const List<_Cuisine> _kCuisines = [
  _Cuisine('All', 'அனைத்து', '🍽️', Color(0xFFE6F0FF), ''),
  _Cuisine('Tiffin', 'டிபன்', '🥞', Color(0xFFFFF0D2), 'tiffin|டிபன்|idli|dosa|இட்லி|தோசை'),
  _Cuisine('Meals', 'சாப்பாடு', '🍛', Color(0xFFE2F5E9), 'meals|mess|சாப்பாடு|மெஸ்'),
  _Cuisine('Biriyani', 'பிரியாணி', '🍗', Color(0xFFFFE5DE), 'biriyani|biryani|பிரியாணி'),
  _Cuisine('Snacks', 'ஸ்நாக்ஸ்', '🥪', Color(0xFFF1E7FF), 'snack|chat|bakery|ஸ்நாக்ஸ்|பேக்கரி'),
  _Cuisine('Tea & Juice', 'டீ / ஜூஸ்', '🧃', Color(0xFFE3F4F6), 'tea|coffee|juice|டீ|காபி|ஜூஸ்'),
  _Cuisine('Sweets', 'இனிப்பு', '🍰', Color(0xFFFFE4EF), 'sweet|இனிப்பு|ஸ்வீட்'),
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

  Widget _roundBtn(IconData i, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Color(0x1A2A7DE1), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Icon(i, size: 22, color: kInk),
        ),
      );

  Widget _top() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _roundBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.tr('Delivering to', 'டெலிவரி இடம்'), style: ts(11.5, color: kMuted)),
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 16, color: kBrand),
                  const SizedBox(width: 3),
                  Flexible(child: Text(app.tr('Aruppukottai', 'அருப்புக்கோட்டை'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, weight: FontWeight.w700))),
                ]),
              ]),
            ),
            const LangToggle(onDark: false),
          ]),
          const SizedBox(height: 22),
          Text(
            app.tr('What would you like\nto eat today?', 'இன்று என்ன\nசாப்பிடலாம்?'),
            style: ts(29, weight: FontWeight.w700, height: 1.18),
          ),
          const SizedBox(height: 16),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x1F2A7DE1), blurRadius: 18, offset: Offset(0, 8))],
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
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: const Icon(Icons.search_rounded, color: kBrand),
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: kMuted), onPressed: () => setState(_q.clear)),
                hintText: app.tr('Search hotel or food…', 'ஹோட்டல் / உணவு தேடுங்கள்…'),
                hintStyle: ts(14, color: kMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuisineRow() {
    return SizedBox(
      height: 100,
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
              width: 76,
              color: Colors.transparent,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cu.tint,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(color: on ? kBrand : Colors.transparent, width: 2.2),
                    boxShadow: on ? const [BoxShadow(color: kBrandShadow, blurRadius: 14, offset: Offset(0, 6))] : null,
                  ),
                  child: Text(cu.emoji, style: const TextStyle(fontSize: 29)),
                ),
                const SizedBox(height: 6),
                Text(app.tr(cu.en, cu.ta), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? kBrandDark : kInk)),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? kInk : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: on ? kInk : kLine),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: on ? Colors.white : kBrand),
          const SizedBox(width: 6),
          Text(label, style: ts(12.5, weight: FontWeight.w600, color: on ? Colors.white : kInk)),
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
          _pill(app.tr('Open now', 'திறந்துள்ளது'), Icons.schedule_rounded, _open, () => setState(() => _open = !_open)),
          const SizedBox(width: 8),
          _pill(app.tr('Home delivery', 'வீட்டு டெலிவரி'), Icons.delivery_dining_rounded, _delivery, () => setState(() => _delivery = !_delivery)),
        ],
      ),
    );
  }

  Widget _title(String t, String? trailing) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Row(children: [
          Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(19, weight: FontWeight.w700))),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(10)),
              child: Text(trailing, style: ts(12.5, weight: FontWeight.w700, color: kBrandDark)),
            ),
        ]),
      );

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withAlpha(48), borderRadius: BorderRadius.circular(11), border: Border.all(color: Colors.white.withAlpha(60))),
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
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          height: 232,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x2E1B4F9C), blurRadius: 26, offset: Offset(0, 14))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                HotelCover(hotel: h, gray: closed),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0x00000000), Color(0xE6081A33)], begin: Alignment(0, -0.1), end: Alignment.bottomCenter),
                  ),
                ),
                if (closed) Container(color: const Color(0x55000000)),
                Positioned(
                  left: 14,
                  right: 14,
                  top: 14,
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (h.pureVeg)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.eco_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(app.tr('PURE VEG', 'சைவம்'), style: ts(10.5, weight: FontWeight.w700, color: Colors.white)),
                        ]),
                      ),
                    if (closed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(10)),
                        child: Text(h.openNow ? app.tr('NOT TAKING ORDERS', 'ஆர்டர் இல்லை') : app.tr('CLOSED NOW', 'மூடப்பட்டுள்ளது'), style: ts(10.5, weight: FontWeight.w700, color: Colors.white)),
                      )
                    else if (offer != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_offer_rounded, size: 13, color: kBrand),
                          const SizedBox(width: 4),
                          Flexible(child: Text(offer, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, weight: FontWeight.w700, color: kBrandDark))),
                        ]),
                      ),
                  ]),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(23, weight: FontWeight.w700, color: Colors.white)),
                      if (h.cuisine.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(h.cuisine, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, color: Colors.white.withAlpha(215))),
                      ],
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(h.ratingCount > 0 ? Icons.star_rounded : Icons.auto_awesome_rounded, size: 15, color: const Color(0xFFFFC53D)),
                          const SizedBox(width: 4),
                          Text(h.ratingCount > 0 ? h.rating.toStringAsFixed(1) : app.tr('New', 'புதிது'), style: ts(12, weight: FontWeight.w700, color: Colors.white)),
                        ])),
                        _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('${h.prepMinutes}-${h.prepMinutes + 10} ${app.tr('min', 'நிமி')}', style: ts(12, weight: FontWeight.w600, color: Colors.white)),
                        ])),
                        _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.delivery_dining_rounded, size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(h.canDeliver ? (h.deliveryFee <= 0 ? app.tr('Free', 'இலவசம்') : rupee(h.deliveryFee)) : app.tr('Pickup', 'நேரில்'), style: ts(12, weight: FontWeight.w600, color: Colors.white)),
                        ])),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
        Text(title, textAlign: TextAlign.center, style: ts(18, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: ts(13.5, color: kMuted, height: 1.4)),
        if (retry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(app.tr('Try again', 'மீண்டும் முயற்சி'))),
        ],
      ]),
    );
  }

  Widget _skeleton() => const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 18), child: PulseBox(height: 232, radius: 28));

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
          body = _state(Icons.wifi_off_rounded, app.tr('Could not load hotels', 'ஹோட்டல்களை ஏற்ற முடியவில்லை'), food.error!, retry: () => food.loadHotels(force: true));
        } else if (food.hotels.isEmpty) {
          body = _state(Icons.storefront_rounded, app.tr('Hotels are coming soon', 'ஹோட்டல்கள் விரைவில்'),
              app.tr('We are adding Aruppukottai hotels. Check back soon!', 'அருப்புக்கோட்டை ஹோட்டல்களை சேர்த்து வருகிறோம். விரைவில் வாருங்கள்!'));
        } else if (list.isEmpty) {
          body = _state(Icons.search_off_rounded, app.tr('No match', 'எதுவும் கிடைக்கவில்லை'), app.tr('Try another name or remove a filter.', 'வேறு பெயர் அல்லது filter-ஐ நீக்கி பாருங்கள்.'));
        } else {
          body = Column(children: [for (var i = 0; i < list.length; i++) _card(list[i], i)]);
        }
        return foodScale(
          context,
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              backgroundColor: kBg,
              body: RefreshIndicator(
                edgeOffset: 80,
                onRefresh: () => food.loadHotels(force: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: cart.isEmpty ? 24 : 100),
                  children: [
                    _top(),
                    const SizedBox(height: 18),
                    _cuisineRow(),
                    const SizedBox(height: 6),
                    _filters(),
                    _title(app.tr('Hotels near you', 'உங்கள் அருகில்'), food.loadedOnce ? '${list.length}' : null),
                    body,
                  ],
                ),
              ),
              bottomNavigationBar: cart.isEmpty ? null : const CartBar(),
            ),
          ),
        );
      },
    );
  }
}

/// Floating bar at the bottom: "2 items · ₹240  ·  View cart".
class CartBar extends StatelessWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context) {
    final h = cart.hotel;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
          child: Container(
            height: 64,
            padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0F2A4D), Color(0xFF1B5FC2)], begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x660F2A4D), blurRadius: 20, offset: Offset(0, 8))],
            ),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.white.withAlpha(34), shape: BoxShape.circle),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: Text('${cart.count}', key: ValueKey<int>(cart.count), style: ts(16, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rupee(cart.itemsTotal), style: ts(17, weight: FontWeight.w700, color: Colors.white)),
                    Text(
                      h == null ? '' : '${h.name} · ${h.prepMinutes + 10}-${h.prepMinutes + 20} ${app.tr('min', 'நிமி')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(11.5, color: Colors.white.withAlpha(200)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(app.tr('View cart', 'கார்ட்'), style: ts(13.5, weight: FontWeight.w700, color: kBrandDark)),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: kBrandDark),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
