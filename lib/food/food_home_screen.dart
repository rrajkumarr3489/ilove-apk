import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';
import 'food_cart.dart';
import 'food_filters.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';
import 'hotel_menu_screen.dart';

class _Cuisine {
  final String en;
  final String ta;
  final String emoji;
  final Color tint;
  final List<String> words;

  const _Cuisine(this.en, this.ta, this.emoji, this.tint, this.words);
}

const List<_Cuisine> _kCuisines = [
  _Cuisine('All', 'அனைத்து', '🍽️', Color(0xFFE6F0FF), <String>[]),
  _Cuisine('Tiffin', 'டிபன்', '🥞', Color(0xFFFFF0D2), <String>['idli', 'dosa', 'இட்லி', 'தோசை', 'tiffin']),
  _Cuisine('Meals', 'சாப்பாடு', '🍛', Color(0xFFE2F5E9), <String>['meals', 'சாப்பாடு']),
  _Cuisine('Biriyani', 'பிரியாணி', '🍗', Color(0xFFFFE5DE), <String>['biriyani', 'biryani', 'பிரியாணி']),
  _Cuisine('Snacks', 'ஸ்நாக்ஸ்', '🥪', Color(0xFFF1E7FF), <String>['snack', 'sandwich', 'ஸ்நாக்ஸ்']),
  _Cuisine('Tea & Juice', 'டீ / ஜூஸ்', '🧃', Color(0xFFE3F4F6), <String>['tea', 'coffee', 'juice', 'டீ', 'ஜூஸ்']),
  _Cuisine('Sweets', 'இனிப்பு', '🍰', Color(0xFFFFE4EF), <String>['sweet', 'cake', 'இனிப்பு']),
];

/// One banner on top: a picture from the admin panel, or (when there is none) an offer made from our own data.
class _Slide {
  final String? image;
  final Color bg;
  final String title;
  final String sub;
  final IconData icon;
  final VoidCallback? onTap;

  _Slide({this.image, required this.bg, this.title = '', this.sub = '', this.icon = Icons.restaurant_rounded, this.onTap});
}

Color _hex(String? s, Color fallback) {
  if (s == null || s.length != 7 || !s.startsWith('#')) return fallback;
  final v = int.tryParse(s.substring(1), radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Food home: tinted top (header, search, banners), food circles, filters, big hotel cards, floating bottom bar.
class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  final TextEditingController _q = TextEditingController();
  final PageController _pc = PageController();
  Timer? _timer;
  int _page = 0;
  int _slideCount = 1;
  int _tab = 0;
  int _cuisine = 0;
  FoodFilters _f = FoodFilters();

  @override
  void initState() {
    super.initState();
    food.restore();
    food.loadHotels(force: true);
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pc.hasClients || _slideCount < 2) return;
      _pc.animateToPage((_page + 1) % _slideCount, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    _q.dispose();
    super.dispose();
  }

  void _openHotel(FoodHotel h) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HotelMenuScreen(hotel: h)));

  // ---------- data ----------
  FoodItem? _featuredDish(FoodHotel h) {
    final m = food.cachedMenu(h.id);
    if (m == null) return null;
    FoodItem? any;
    for (final it in m.items) {
      if (!it.available) continue;
      if (it.bestseller) return it;
      any ??= it;
    }
    return any;
  }

  bool _matchesQuery(FoodHotel h, String q) {
    if (h.searchText.contains(q)) return true;
    final m = food.cachedMenu(h.id);
    if (m == null) return false;
    for (final it in m.items) {
      if ('${it.nameEn} ${it.nameTa ?? ''}'.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  List<FoodHotel> _list() {
    final words = _kCuisines[_cuisine].words;
    final q = _q.text.trim().toLowerCase();
    final base = food.hotels.where((h) {
      if (words.isNotEmpty && !words.any((w) => h.searchText.contains(w))) return false;
      if (q.isNotEmpty && !_matchesQuery(h, q)) return false;
      return true;
    }).toList();
    return _f.apply(base);
  }

  List<_Slide> _slides() {
    final out = <_Slide>[];
    for (final b in food.banners) {
      if (b.image.isEmpty) continue;
      VoidCallback? tap;
      if (b.linkType == 'Hotel') {
        final id = int.tryParse(b.linkValue ?? '');
        FoodHotel? hit;
        for (final h in food.hotels) {
          if (h.id == id) hit = h;
        }
        if (hit != null) {
          final h2 = hit;
          tap = () => _openHotel(h2);
        }
      } else if (b.linkType == 'Filter') {
        final v = b.linkValue;
        tap = () => setState(() {
              _f.clear();
              _cuisine = 0;
              _q.clear();
              if (v == 'veg') _f.veg = true;
              if (v == 'open') _f.open = true;
              if (v == 'free') _f.free = true;
              if (v == 'fast') _f.fast = true;
              if (v == 'top') _f.minRating = 4.0;
              if (v == 'cheap') _f.maxPrice = 100;
            });
      }
      out.add(_Slide(image: b.image, bg: _hex(b.bgColor, kBrandDark), onTap: tap));
    }
    if (out.isNotEmpty) return out;
    // no banner set in the admin panel yet: offers made from the hotels we have
    final hs = food.hotels;
    final free = hs.where((h) => h.canDeliver && h.deliveryFee <= 0).length;
    final open = hs.where((h) => h.openNow && h.acceptsOrders).length;
    if (free > 0) {
      out.add(_Slide(bg: kBrandDark, title: app.tr('Free delivery', 'இலவச டெலிவரி'), sub: app.tr('$free hotels deliver free to you', '$free ஹோட்டல்கள் இலவசமாக கொண்டு வரும்'), icon: Icons.delivery_dining_rounded, onTap: () => setState(() {
            _f.clear();
            _f.free = true;
          })));
    }
    if (open > 0) {
      out.add(_Slide(bg: const Color(0xFF0F2A4D), title: app.tr('Hungry now?', 'இப்போது பசிக்கிறதா?'), sub: app.tr('$open hotels are open and taking orders', '$open ஹோட்டல்கள் திறந்துள்ளன'), icon: Icons.local_fire_department_rounded, onTap: () => setState(() {
            _f.clear();
            _f.open = true;
          })));
    }
    if (out.isEmpty) {
      out.add(_Slide(bg: kBrandDark, title: app.tr('Aruppukottai\'s own food app', 'அருப்புக்கோட்டையின் சொந்த உணவு ஆப்'), sub: app.tr('Order from local hotels, home delivered', 'உள்ளூர் ஹோட்டல்களில் ஆர்டர் செய்யுங்கள்'), icon: Icons.restaurant_rounded));
    }
    return out;
  }

  // ---------- top ----------
  Widget _round(IconData i, VoidCallback f, Color fg, Color bg, {int badge = 0}) => GestureDetector(
        onTap: f,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(i, size: 21, color: fg)),
          if (badge > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFFF4D6D), borderRadius: BorderRadius.circular(9)),
                child: Text('$badge', style: ts(10, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
        ]),
      );

  Widget _top(Color bg, int slides) {
    final dark = bg.computeLuminance() < 0.4;
    final fg = dark ? Colors.white : kInk;
    final sub = dark ? Colors.white70 : kMuted;
    final top = Color.lerp(bg, Colors.white, dark ? 0.0 : 0.25)!;
    final mid = Color.lerp(bg, Colors.white, 0.72)!;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, mid, Colors.white], stops: const [0, 0.62, 1]),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _round(Icons.arrow_back_rounded, () => Navigator.pop(context), fg, Colors.white.withAlpha(dark ? 40 : 190)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.tr('Delivering to', 'டெலிவரி இடம்'), style: ts(11.5, color: sub)),
                Row(children: [
                  Icon(Icons.location_on_rounded, size: 17, color: fg),
                  const SizedBox(width: 3),
                  Flexible(child: Text(app.tr('Aruppukottai', 'அருப்புக்கோட்டை'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(19, weight: FontWeight.w800, color: fg))),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: fg),
                ]),
              ]),
            ),
            LangToggle(onDark: dark),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kLine),
                  boxShadow: const [BoxShadow(color: Color(0x141B4F9C), blurRadius: 12, offset: Offset(0, 5))],
                ),
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  style: ts(15),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    prefixIcon: const Icon(Icons.search_rounded, color: kBrand),
                    suffixIcon: _q.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: kMuted), onPressed: () => setState(_q.clear)),
                    hintText: app.tr('Hotel name or a dish…', 'ஹோட்டல் பெயர் அல்லது உணவு…'),
                    hintStyle: ts(14.5, color: kMuted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            GestureDetector(
              onTap: () => setState(() => _f.veg = !_f.veg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(app.tr('VEG', 'சைவம்'), style: ts(11.5, weight: FontWeight.w800, color: fg)),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 24,
                  padding: const EdgeInsets.all(2.5),
                  alignment: _f.veg ? Alignment.centerRight : Alignment.centerLeft,
                  decoration: BoxDecoration(color: _f.veg ? kGreen : const Color(0xFFB9C3D3), borderRadius: BorderRadius.circular(12)),
                  child: Container(width: 19, height: 19, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3)])),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        _banners(),
      ]),
    );
  }

  Widget _banners() {
    final list = _slides();
    _slideCount = list.length;
    final w = MediaQuery.of(context).size.width;
    final h = (w - 24) * 5 / 9;
    return Column(children: [
      SizedBox(
        height: h,
        child: PageView.builder(
          controller: _pc,
          itemCount: list.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (c, i) {
            final s = list[i];
            return GestureDetector(
              onTap: s.onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: s.bg.withAlpha(80), blurRadius: 18, offset: const Offset(0, 9))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: s.image != null
                      ? Stack(fit: StackFit.expand, children: [Container(color: s.bg), NetImg(file: s.image, cacheWidth: 1100)])
                      : Container(
                          padding: const EdgeInsets.fromLTRB(22, 0, 12, 0),
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [kNavy, s.bg], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                          child: Row(children: [
                            Expanded(
                              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(24, weight: FontWeight.w800, color: Colors.white, height: 1.15)),
                                const SizedBox(height: 6),
                                Text(s.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(13.5, color: Colors.white.withAlpha(225), height: 1.3)),
                              ]),
                            ),
                            Icon(s.icon, size: 84, color: Colors.white.withAlpha(60)),
                          ]),
                        ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      if (list.length > 1)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < list.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _page ? 9 : 6,
              height: i == _page ? 9 : 6,
              decoration: BoxDecoration(color: i == _page ? kNavy : kBrandMid.withAlpha(150), shape: BoxShape.circle),
            )
        ])
      else
        const SizedBox(height: 6),
      const SizedBox(height: 6),
    ]);
  }

  // ---------- circles + filters ----------
  Widget _circles() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: kLine, width: 1.5))),
      child: SizedBox(
        height: 124,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: _kCuisines.length,
          itemBuilder: (c, i) {
            final cu = _kCuisines[i];
            final photo = i == 0 ? null : food.photoFor(cu.words);
            final on = _cuisine == i;
            return GestureDetector(
              onTap: () => setState(() => _cuisine = i),
              child: Container(
                width: 82,
                color: Colors.transparent,
                child: Column(children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 66,
                    height: 66,
                    decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x1A1B4F9C), blurRadius: 10, offset: Offset(0, 5))]),
                    child: ClipOval(
                      child: Stack(fit: StackFit.expand, children: [
                        Container(color: cu.tint, alignment: Alignment.center, child: Text(cu.emoji, style: const TextStyle(fontSize: 29))),
                        if (photo != null) NetImg(file: photo, cacheWidth: 200),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(app.tr(cu.en, cu.ta), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, weight: on ? FontWeight.w700 : FontWeight.w500)),
                  const Spacer(),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: on ? 58 : 0,
                    height: 3.5,
                    decoration: const BoxDecoration(color: kBrand, borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String label, IconData? icon, bool on, VoidCallback tap, {Color? iconColor, bool dropdown = false, int badge = 0}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(tap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: on ? kTint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: on ? kBrand : kLine, width: on ? 1.4 : 1),
            boxShadow: const [BoxShadow(color: Color(0x0F1B4F9C), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 17, color: iconColor ?? (on ? kBrand : kNavy)), const SizedBox(width: 7)],
            Text(label, style: ts(14, weight: FontWeight.w600, color: on ? kBrandDark : kInk)),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(width: 20, height: 20, alignment: Alignment.center, decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle), child: Text('$badge', style: ts(11, weight: FontWeight.w700, color: Colors.white))),
            ],
            if (dropdown) ...[const SizedBox(width: 4), const Icon(Icons.arrow_drop_down_rounded, size: 22, color: kNavy)],
          ]),
        ),
      ),
    );
  }

  Future<void> _openFilters() async {
    final r = await showFoodFilters(context, _f, food.hotels);
    if (r != null && mounted) setState(() => _f = r);
  }

  Widget _filterRow() {
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: _openFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: _f.count > 0 ? kNavy : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _f.count > 0 ? kNavy : kLine),
                  boxShadow: const [BoxShadow(color: Color(0x0F1B4F9C), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.tune_rounded, size: 18, color: _f.count > 0 ? Colors.white : kNavy),
                  const SizedBox(width: 8),
                  Text(app.tr('Filters', 'Filters'), style: ts(14, weight: FontWeight.w700, color: _f.count > 0 ? Colors.white : kInk)),
                  if (_f.count > 0) ...[
                    const SizedBox(width: 6),
                    Container(width: 20, height: 20, alignment: Alignment.center, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Text('${_f.count}', style: ts(11, weight: FontWeight.w800, color: kNavy))),
                  ],
                  Icon(Icons.arrow_drop_down_rounded, size: 22, color: _f.count > 0 ? Colors.white : kNavy),
                ]),
              ),
            ),
          ),
          _chip(app.tr('Near & Fast', 'அருகில் & விரைவு'), Icons.bolt_rounded, _f.fast, () => _f.fast = !_f.fast, iconColor: kGreen),
          _chip(app.tr('Open now', 'திறந்துள்ளது'), Icons.schedule_rounded, _f.open, () => _f.open = !_f.open),
          _chip(app.tr('Rated 4.0+', '4.0+ மதிப்பீடு'), Icons.star_rounded, _f.minRating == 4.0, () => _f.minRating = _f.minRating == 4.0 ? 0 : 4.0, iconColor: kGreen),
          _chip(app.tr('Free delivery', 'இலவச டெலிவரி'), Icons.local_offer_rounded, _f.free, () => _f.free = !_f.free),
          _chip(app.tr('Under ₹100', '₹100-க்குள்'), Icons.currency_rupee_rounded, _f.maxPrice == 100, () => _f.maxPrice = _f.maxPrice == 100 ? null : 100),
        ],
      ),
    );
  }

  Widget _heading(int n) {
    final filtered = _f.count > 0 || _cuisine != 0 || _q.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Row(children: [
        Expanded(
          child: Text(
            app.lang == 'ta' ? '$n ஹோட்டல்கள் உங்களுக்கு டெலிவரி' : '$n ${n == 1 ? 'HOTEL' : 'HOTELS'} ${filtered ? 'FOUND' : 'DELIVERING TO YOU'}',
            maxLines: 2,
            style: ts(13, weight: FontWeight.w600, color: kMuted).copyWith(letterSpacing: app.lang == 'ta' ? 0.2 : 2.0),
          ),
        ),
        if (filtered)
          GestureDetector(
            onTap: () => setState(() {
              _f.clear();
              _cuisine = 0;
              _q.clear();
            }),
            child: Text(app.tr('Clear', 'அழி'), style: ts(13.5, weight: FontWeight.w700, color: kBrand)),
          ),
      ]),
    );
  }

  // ---------- hotel card ----------
  Widget _card(FoodHotel h, int index) {
    final dish = _featuredDish(h);
    final closed = !h.openNow || !h.acceptsOrders;
    final time = '${h.prepMinutes}-${h.prepMinutes + 10} ${app.tr('mins', 'நிமி')}';
    return FadeSlide(
      index: index,
      child: GestureDetector(
        onTap: () => _openHotel(h),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: kLine),
            boxShadow: const [BoxShadow(color: Color(0x141B4F9C), blurRadius: 18, offset: Offset(0, 8))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              child: SizedBox(
                height: 232,
                child: Stack(fit: StackFit.expand, children: [
                  HotelCover(hotel: h, gray: closed, scrim: false),
                  if (closed) Container(color: const Color(0x66000000)),
                  if (dish != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      right: 64,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xCC1A2233), borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white24)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            VegDot(veg: dish.veg, size: 15),
                            const SizedBox(width: 7),
                            Flexible(child: Text('${dish.name} · ${dish.hasVariants ? rupee(dish.fromPrice) : rupee(dish.price)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, weight: FontWeight.w600, color: Colors.white))),
                          ]),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => food.toggleFav(h.id),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(food.isFav(h.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, size: 34, color: Colors.white.withAlpha(245)),
                      ),
                    ),
                  ),
                  if (closed)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(9)),
                        child: Text(h.openNow ? app.tr('NOT TAKING ORDERS', 'ஆர்டர் இல்லை') : app.tr('CLOSED NOW', 'மூடப்பட்டுள்ளது'), style: ts(10.5, weight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(21, weight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Row(children: [
                      const Icon(Icons.bolt_rounded, size: 18, color: kGreen),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '$time  |  ${h.canDeliver ? (h.deliveryFee <= 0 ? app.tr('Free delivery', 'இலவச டெலிவரி') : '${rupee(h.deliveryFee)} ${app.tr('delivery', 'டெலிவரி')}') : app.tr('Pickup only', 'நேரில் மட்டும்')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(14, weight: FontWeight.w600, color: kGreen),
                        ),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(width: 10),
                RatingBadge(rating: h.rating, count: h.ratingCount),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _state(IconData icon, String title, String sub, {VoidCallback? retry, String? retryLabel}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 20),
      child: Column(children: [
        Container(width: 96, height: 96, decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle), child: Icon(icon, size: 44, color: kBrand)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: ts(18, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub, textAlign: TextAlign.center, style: ts(13.5, color: kMuted, height: 1.4)),
        if (retry != null) ...[
          const SizedBox(height: 16),
          TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(retryLabel ?? app.tr('Try again', 'மீண்டும் முயற்சி'))),
        ],
      ]),
    );
  }

  // ---------- tabs ----------
  Widget _homeTab() {
    final slides = _slides();
    final bg = slides[_page.clamp(0, slides.length - 1).toInt()].bg;
    final list = _list();
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: bg, end: bg),
          duration: const Duration(milliseconds: 450),
          builder: (c, v, _) => _top(v ?? bg, slides.length),
        ),
      ),
      SliverToBoxAdapter(child: _circles()),
      SliverToBoxAdapter(child: _filterRow()),
    ];
    if (food.loading && !food.loadedOnce && food.hotels.isEmpty) {
      slivers.add(const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 0), child: Column(children: [PulseBox(height: 300, radius: 26), SizedBox(height: 20), PulseBox(height: 300, radius: 26)]))));
    } else if (food.error != null && food.hotels.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _state(Icons.wifi_off_rounded, app.tr('Could not load hotels', 'ஹோட்டல்களை ஏற்ற முடியவில்லை'), food.error!, retry: () => food.loadHotels(force: true))));
    } else if (food.hotels.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _state(Icons.storefront_rounded, app.tr('Hotels are coming soon', 'ஹோட்டல்கள் விரைவில்'), app.tr('We are adding Aruppukottai hotels. Check back soon!', 'அருப்புக்கோட்டை ஹோட்டல்களை சேர்த்து வருகிறோம். விரைவில் வாருங்கள்!'))));
    } else if (list.isEmpty) {
      slivers.add(SliverToBoxAdapter(
          child: _state(Icons.search_off_rounded, app.tr('No hotels match', 'எதுவும் கிடைக்கவில்லை'), app.tr('Try removing a filter or another word.', 'ஒரு filter-ஐ நீக்கி அல்லது வேறு வார்த்தை முயற்சிக்கவும்.'),
              retry: () => setState(() {
                    _f.clear();
                    _cuisine = 0;
                    _q.clear();
                  }),
              retryLabel: app.tr('Clear filters', 'filter நீக்கு'))));
    } else {
      slivers.add(SliverToBoxAdapter(child: _heading(list.length)));
      slivers.add(SliverList(delegate: SliverChildBuilderDelegate((c, i) => _card(list[i], i), childCount: list.length)));
    }
    if (food.offline && food.hotels.isNotEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFFFF4DB), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: kAmber),
            const SizedBox(width: 8),
            Expanded(child: Text(app.tr('No internet - showing saved hotels', 'இணையம் இல்லை - சேமித்த ஹோட்டல்கள்'), style: ts(12.5, weight: FontWeight.w600))),
          ]),
        ),
      ));
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    return RefreshIndicator(
      edgeOffset: 90,
      onRefresh: () => food.loadHotels(force: true),
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: slivers),
    );
  }

  Widget _savedTab() {
    final saved = food.hotels.where((h) => food.isFav(h.id)).toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 16),
          child: Text(app.tr('Saved hotels', 'சேமித்த ஹோட்டல்கள்'), style: ts(26, weight: FontWeight.w800)),
        ),
      ),
      if (saved.isEmpty)
        SliverToBoxAdapter(child: _state(Icons.bookmark_border_rounded, app.tr('Nothing saved yet', 'இன்னும் எதுவும் சேமிக்கவில்லை'), app.tr('Tap the bookmark on a hotel to keep it here.', 'ஹோட்டலில் bookmark தொட்டால் இங்கே சேமிக்கப்படும்.')))
      else
        SliverList(delegate: SliverChildBuilderDelegate((c, i) => _card(saved[i], i), childCount: saved.length)),
      const SliverToBoxAdapter(child: SizedBox(height: 24)),
    ]);
  }

  // ---------- bottom bar ----------
  Widget _navItem(int i, IconData icon, IconData iconOn, String label, VoidCallback tap, {int badge = 0}) {
    final on = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: on ? 20 : 16, vertical: 12),
        decoration: BoxDecoration(color: on ? kNavy : Colors.transparent, borderRadius: BorderRadius.circular(26)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(on ? iconOn : icon, size: 24, color: on ? Colors.white : kNavy),
            if (badge > 0)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFFF4D6D), borderRadius: BorderRadius.circular(9)),
                  child: Text('$badge', style: ts(10, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ]),
          if (on) ...[const SizedBox(width: 8), Text(label, style: ts(14.5, weight: FontWeight.w700, color: Colors.white))],
        ]),
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: kLine),
            boxShadow: const [BoxShadow(color: Color(0x261B4F9C), blurRadius: 22, offset: Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _navItem(0, Icons.home_outlined, Icons.home_rounded, app.tr('Home', 'முகப்பு'), () => setState(() => _tab = 0)),
            _navItem(1, Icons.bookmark_border_rounded, Icons.bookmark_rounded, app.tr('Saved', 'சேமித்தவை'), () => setState(() => _tab = 1), badge: food.favs.length),
            _navItem(2, Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, app.tr('Cart', 'கார்ட்'),
                () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CartScreen())),
                badge: cart.count),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([food, app, cart]),
      builder: (context, _) {
        return foodScale(
          context,
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              backgroundColor: Colors.white,
              body: IndexedStack(index: _tab, children: [_homeTab(), _savedTab()]),
              bottomNavigationBar: _bottomBar(),
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
