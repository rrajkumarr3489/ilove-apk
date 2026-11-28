import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';
import 'dish_sheet.dart';
import 'food_cart.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';
import 'hotel_menu_screen.dart';

/// One chip in "Explore by Category". Made in the admin panel (Food Categories);
/// the fixed list is only used until the admin adds the first category.
class _Cat {
  final String key;
  final String label;
  final String emoji;
  final String? image;
  final int? catId;
  final List<String> words;

  const _Cat(this.key, this.label, this.emoji, this.image, this.catId, this.words);
}

const List<List<String>> _kFallbackCats = [
  ['Tiffin', 'டிபன்', '🥞', 'tiffin,idli,dosa,dosai,pongal,vada,parotta'],
  ['Meals', 'சாப்பாடு', '🍛', 'meals,sappadu,rice,thali'],
  ['Biriyani', 'பிரியாணி', '🍗', 'biriyani,biryani,briyani'],
  ['Snacks', 'ஸ்நாக்ஸ்', '🥪', 'snacks,bajji,bonda,samosa,sandwich,burger,puff'],
  ['Juice', 'ஜூஸ்', '🥤', 'juice,shake,coffee,tea,kaapi,drinks'],
  ['Sweets', 'இனிப்பு', '🍮', 'sweet,ice cream,cake,bakery'],
];

/// The Food home: sticky header, stories, categories, offer banner, quick drops, hotels.
class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  final TextEditingController _q = TextEditingController();
  final PageController _promoPc = PageController();
  final ValueNotifier<int> _dropSecs = ValueNotifier<int>(14 * 60 + 59);
  Timer? _promoTimer;
  Timer? _clock;
  int _promoPage = 0;
  int _promoCount = 1;
  String _cat = 'all';
  String _filter = 'all'; // all / veg / fast / protein / bestseller

  @override
  void initState() {
    super.initState();
    food.restore();
    food.loadHotels(force: true);
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_promoPc.hasClients || _promoCount < 2) return;
      _promoPc.animateToPage((_promoPage + 1) % _promoCount, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      _dropSecs.value = _dropSecs.value > 0 ? _dropSecs.value - 1 : 899;
    });
  }

  @override
  void dispose() {
    _promoTimer?.cancel();
    _clock?.cancel();
    _promoPc.dispose();
    _dropSecs.dispose();
    _q.dispose();
    super.dispose();
  }

  // ---------- helpers ----------
  bool get _pickup => cart.fulfil == 'Pickup';

  void _toast(String m) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(m)));
  }

  void _soon() => _toast(app.tr('Coming soon to Aruppukottai!', 'விரைவில் அருப்புக்கோட்டையில்!'));

  void _openHotel(FoodHotel h) => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HotelMenuScreen(hotel: h)));

  FoodHotel? _hotelById(int? id) {
    if (id == null) return null;
    for (final h in food.hotels) {
      if (h.id == id) return h;
    }
    return null;
  }

  void _openHotelId(int? id) {
    final h = _hotelById(id);
    if (h != null) _openHotel(h);
  }

  List<_Cat> _cats() {
    final out = <_Cat>[_Cat('all', app.tr('All', 'அனைத்தும்'), '🍽️', null, null, const <String>[])];
    if (food.homeCats.isNotEmpty) {
      for (final c in food.homeCats) {
        out.add(_Cat('c${c.id}', c.name, '🍴', c.image, c.id, const <String>[]));
      }
    } else {
      for (var i = 0; i < _kFallbackCats.length; i++) {
        final c = _kFallbackCats[i];
        out.add(_Cat('w$i', app.tr(c[0], c[1]), c[2], null, null, c[3].split(',')));
      }
    }
    return out;
  }

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
    final cs = _cats();
    final cu = cs.firstWhere((c) => c.key == _cat, orElse: () => cs.first);
    final q = _q.text.trim().toLowerCase();
    return food.hotels.where((h) {
      if (_pickup ? !h.canPickup : !h.canDeliver) return false;
      if (cu.catId != null && !h.categoryIds.contains(cu.catId)) return false;
      if (cu.words.isNotEmpty && !cu.words.any((w) => h.searchText.contains(w))) return false;
      if (q.isNotEmpty && !_matchesQuery(h, q)) return false;
      switch (_filter) {
        case 'veg':
          return h.pureVeg;
        case 'fast':
          return h.shownEta <= 20;
        case 'protein':
          return h.highProtein;
        case 'bestseller':
          return h.bestseller;
      }
      return true;
    }).toList();
  }

  /// "Save ₹40": what the customer saves by picking up (average delivery fee + the platform fee difference).
  int _pickupSave() {
    final ds = food.hotels.where((h) => h.canDeliver && h.canPickup).toList();
    if (ds.isEmpty) return 0;
    final avg = ds.fold<double>(0, (s, h) => s + h.deliveryFee) / ds.length;
    final plat = (double.tryParse(food.cfg('Food.PlatformFee', '0')) ?? 0) - (double.tryParse(food.cfg('Food.PlatformFeePickup', '0')) ?? 0);
    return (avg + (plat > 0 ? plat : 0)).round();
  }

  /// Distance text: km when the phone sent a location, else nothing.
  String? _km(FoodHotel h) => h.distanceKm == null ? null : '${h.distanceKm!.toStringAsFixed(1)} km';

  // ---------- header ----------
  Widget _box(IconData i, VoidCallback f, {double size = 36}) => GestureDetector(
        onTap: f,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBrandMid.withAlpha(120)), boxShadow: kSoftShadow),
          child: Icon(i, size: 18, color: kBrand),
        ),
      );

  Widget _modeBtn(String mode, String emoji, String label, {String? badge}) {
    final on = cart.fulfil == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => cart.setFulfil(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(color: on ? kBrand : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, weight: FontWeight.w800, color: on ? Colors.white : kMuted))),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(10)),
                child: Text(badge, style: ts(9.5, weight: FontWeight.w800, color: kGreen)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, {Widget? lead}) {
    final on = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        decoration: BoxDecoration(color: on ? kBrand : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? kBrand : kLine)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (lead != null) ...[lead, const SizedBox(width: 5)],
          Text(label, style: ts(12, weight: on ? FontWeight.w800 : FontWeight.w600, color: on ? Colors.white : kMuted)),
        ]),
      ),
    );
  }

  Widget _header() {
    final pad = MediaQuery.of(context).padding.top;
    final save = _pickupSave();
    return Container(
      padding: EdgeInsets.fromLTRB(16, pad + 8, 16, 12),
      decoration: BoxDecoration(color: kTint, border: Border(bottom: BorderSide(color: kBrandMid.withAlpha(90)))),
      child: Column(children: [
        Row(children: [
          _box(Icons.arrow_back_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(app.tr('Aruppukottai', 'அருப்புக்கோட்டை'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w800))),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kBrand),
              ]),
              Text(
                _pickup ? app.tr('Self-Pickup • skip the delivery fee', 'நேரில் எடுக்க • டெலிவரி கட்டணம் இல்லை') : app.tr('Home delivery in your town', 'உங்கள் ஊரிலேயே டெலிவரி'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(11.5, color: kMuted),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kBrandMid.withAlpha(120))),
            child: const LangToggle(),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrandMid.withAlpha(120))),
          child: Row(children: [
            _modeBtn('Delivery', '🛵', app.tr('Delivery', 'டெலிவரி')),
            const SizedBox(width: 4),
            _modeBtn('Pickup', '🛍️', app.tr('Self-Pickup', 'நேரில் எடுக்க'), badge: save > 0 ? app.tr('Save ₹$save', '₹$save சேமிப்பு') : null),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrandMid.withAlpha(120)), boxShadow: kSoftShadow),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 19, color: kBrand),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _q,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: ts(13),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      hintText: app.tr('Search biryani, dosa, meals, or hotels...', 'பிரியாணி, தோசை, சாப்பாடு, ஹோட்டல் தேடுங்கள்...'),
                      hintStyle: ts(12.5, color: kMuted),
                    ),
                  ),
                ),
                if (_q.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(_q.clear),
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close_rounded, size: 18, color: kMuted)),
                  )
                else
                  GestureDetector(
                    onTap: _soon,
                    child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.mic_none_rounded, size: 20, color: kMuted)),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          _box(Icons.photo_camera_outlined, _soon, size: 42),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _filterChip('all', app.tr('All Spots', 'அனைத்தும்')),
            _filterChip('veg', app.tr('Pure Veg', 'சைவம்'), lead: const VegDot(veg: true, size: 12)),
            _filterChip('fast', app.tr('Under 20m', '20 நிமிடத்துக்குள்'), lead: const Icon(Icons.bolt_rounded, size: 14, color: kAmber)),
            _filterChip('protein', app.tr('High Protein', 'புரதம் அதிகம்'), lead: const Text('💪', style: TextStyle(fontSize: 12))),
            _filterChip('bestseller', app.tr('Bestseller', 'அதிகம் விற்பனை'), lead: const Text('⭐', style: TextStyle(fontSize: 12))),
          ]),
        ),
      ]),
    );
  }

  Widget _pickupCallout() {
    if (!_pickup) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFB7E1C1))),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(app.tr('Self-Pickup Active • Skip Queue at Counter', 'நேரில் எடுக்கும் முறை • கவுண்டரில் வரிசை இல்லை'), style: ts(12, weight: FontWeight.w800, color: const Color(0xFF0D652D)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB7E1C1))),
          child: Text(app.tr('₹0 Fee', '₹0 கட்டணம்'), style: ts(10.5, weight: FontWeight.w800, color: kGreen)),
        ),
      ]),
    );
  }

  // ---------- section heading ----------
  Widget _head(Widget left, Widget right) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: left), const SizedBox(width: 8), right]),
      );

  // ---------- stories ----------
  Widget _stories() {
    if (!food.flag('Food.ShowStories') || food.stories.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _head(
          Row(children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEA4335), shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Flexible(child: Text(app.tr('Live Kitchen Stories', 'சமையலறை நேரலை'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, weight: FontWeight.w800))),
          ]),
          Text(app.tr('Tap to watch', 'தொட்டுப் பாருங்கள்'), style: ts(11.5, weight: FontWeight.w700, color: kBrand)),
        ),
        SizedBox(
          height: 96,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: food.stories.length,
            itemBuilder: (c, i) {
              final st = food.stories[i];
              return GestureDetector(
                onTap: () => _openStory(st),
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: 66,
                    child: Column(children: [
                      Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kBrandLight, kBrand, Color(0xFF7C4DFF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), color: kTint),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(fit: StackFit.expand, children: [
                            NetImg(file: st.image, cacheWidth: 200),
                            if (i == 0)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(color: const Color(0xB3000000), padding: const EdgeInsets.symmetric(vertical: 1), child: Text('LIVE', textAlign: TextAlign.center, style: ts(8, weight: FontWeight.w800, color: Colors.white))),
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(st.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: ts(11, weight: FontWeight.w600)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  /// Live Kitchen story: full dark screen like the design (progress bar, LIVE KITCHEN badge, tall photo with the dish on a gradient).
  void _openStory(FoodStory st) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (c, a1, a2) => foodScale(
        c,
        Material(
          color: const Color(0xF2020617),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(children: [
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Container(height: 4, width: double.infinity, color: Colors.white24, alignment: Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.75, child: Container(color: const Color(0xFF8AB4F8))))),
                const SizedBox(height: 14),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF43F5E), borderRadius: BorderRadius.circular(5)), child: Text(app.tr('LIVE KITCHEN', 'நேரடி சமையலறை'), style: ts(10, weight: FontWeight.w800, color: Colors.white))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(st.hotelName.isEmpty ? st.label : st.hotelName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, weight: FontWeight.w700, color: const Color(0xFFD2E3FC)))),
                  GestureDetector(
                    onTap: () => Navigator.pop(c),
                    child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, color: Colors.white, size: 18)),
                  ),
                ]),
                const Spacer(),
                AspectRatio(
                  aspectRatio: 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Stack(fit: StackFit.expand, children: [
                      Container(color: const Color(0xFF0F172A), child: NetImg(file: st.image, cacheWidth: 900)),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFF020617), Color(0xCC0F172A), Color(0x000F172A)])),
                          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(st.title, style: ts(19, weight: FontWeight.w800, color: Colors.white, height: 1.2)),
                            if (st.sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(st.sub, style: ts(12.5, color: const Color(0xFFD2E3FC)))),
                            const SizedBox(height: 14),
                            Row(children: [
                              if (st.price != null && st.price! > 0) Text(rupee(st.price!), style: ts(19, weight: FontWeight.w800, color: Colors.white)),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(c);
                                  _quickAdd(st.hotelId, st.itemId, st.titleEn);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                                  decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Color(0x551A73E8), blurRadius: 14, offset: Offset(0, 5))]),
                                  child: Text(app.tr('Order This Dish', 'இதை ஆர்டர் செய்'), style: ts(13, weight: FontWeight.w800, color: Colors.white)),
                                ),
                              ),
                            ]),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
                const Spacer(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- categories ----------
  Widget _categories() {
    final cs = _cats();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _head(
          Text(app.tr('Explore by Category', 'வகைகளை பாருங்கள்'), style: ts(13, weight: FontWeight.w800)),
          Text(app.tr('Tap to filter', 'தொட்டு தேர்வு'), style: ts(11, weight: FontWeight.w600, color: kMuted)),
        ),
        SizedBox(
          height: 46,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cs.length,
            itemBuilder: (c, i) {
              final ct = cs[i];
              final on = _cat == ct.key;
              return GestureDetector(
                onTap: () => setState(() => _cat = ct.key),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
                  decoration: BoxDecoration(color: on ? kBrand : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: on ? kBrand : kLine), boxShadow: on ? const [BoxShadow(color: kBrandShadow, blurRadius: 10, offset: Offset(0, 4))] : null),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: on ? Colors.white.withAlpha(60) : kTint, borderRadius: BorderRadius.circular(10)),
                      clipBehavior: Clip.antiAlias,
                      alignment: Alignment.center,
                      child: (ct.image != null && ct.image!.isNotEmpty) ? NetImg(file: ct.image, cacheWidth: 120) : Text(ct.emoji, style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    Text(ct.label, style: ts(12.5, weight: FontWeight.w800, color: on ? Colors.white : kInk)),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ---------- promo banner (from the offers / banners set in the admin panel) ----------
  Widget _promo() {
    final slides = <Widget>[];
    for (final o in food.offers) {
      slides.add(_promoOffer(o));
    }
    for (final b in food.banners) {
      if (b.image.isEmpty) continue;
      VoidCallback? tap;
      if (b.linkType == 'Hotel') {
        final id = int.tryParse(b.linkValue ?? '');
        tap = () => _openHotelId(id);
      } else if (b.linkType == 'Filter') {
        final v = b.linkValue;
        tap = () => setState(() => _filter = (v == 'veg' || v == 'fast') ? v! : 'all');
      }
      slides.add(GestureDetector(
        onTap: tap,
        child: Container(
          decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: NetImg(file: b.image, cacheWidth: 1100),
        ),
      ));
    }
    _promoCount = slides.isEmpty ? 1 : slides.length;
    if (slides.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(children: [
        SizedBox(
          height: 150,
          child: PageView(
            controller: _promoPc,
            onPageChanged: (i) => setState(() => _promoPage = i),
            children: [for (final s in slides) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: s)],
          ),
        ),
        if (slides.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _promoPage ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(color: i == _promoPage ? kBrand : kLine, borderRadius: BorderRadius.circular(3)),
                ),
            ]),
          ),
      ]),
    );
  }

  Widget _promoOffer(FoodOffer o) {
    String? photo;
    for (final h in food.hotels) {
      if (h.picture != null && h.picture!.isNotEmpty) {
        photo = h.picture;
        break;
      }
    }
    final tag = food.cfg('Food.PromoTag', '').isNotEmpty ? food.cfg('Food.PromoTag') : app.tr('Special Offer', 'சிறப்பு சலுகை');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [kBrandLight, kBrand, Color(0xFF1666D6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: kBrandShadow, blurRadius: 22, offset: Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(right: -34, top: -34, child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(36)))),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
                child: Text(tag.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(9.5, weight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(height: 5),
              Text(o.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(17, weight: FontWeight.w800, color: Colors.white, height: 1.15)),
              const SizedBox(height: 3),
              Text(
                o.minOrder > 0 ? app.tr('Orders above ${rupee(o.minOrder)} • Auto-applied at checkout!', '${rupee(o.minOrder)}-க்கு மேல் • தானாக சேரும்!') : app.tr('Auto-applied at checkout!', 'செக்அவுட்டில் தானாக சேரும்!'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ts(11, color: kOnBrandSoft),
              ),
              const SizedBox(height: 9),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: o.code));
                  _toast(app.tr('Code ${o.code} copied', '${o.code} நகலெடுக்கப்பட்டது'));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: kSoftShadow),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${app.tr('Code', 'கோட்')}: ${o.code}', style: ts(12.5, weight: FontWeight.w800, color: kBrand)),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy_rounded, size: 14, color: kBrand),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 10),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withAlpha(90), width: 4), color: kBrandMid),
            clipBehavior: Clip.antiAlias,
            child: photo != null ? NetImg(file: photo, cacheWidth: 260) : const Icon(Icons.restaurant_rounded, color: Colors.white, size: 34),
          ),
        ]),
      ]),
    );
  }

  // ---------- quick drops ----------
  String _clockText(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _drops() {
    if (!food.flag('Food.ShowDrops') || food.drops.isEmpty) return const SizedBox.shrink();
    final title = food.cfg('Food.DropsTitleEn').isNotEmpty ? app.tr(food.cfg('Food.DropsTitleEn'), food.cfg('Food.DropsTitleTa', food.cfg('Food.DropsTitleEn'))) : app.tr('15-Min Drops', '15 நிமிட டிராப்ஸ்');
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _head(
          Row(children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.bolt_rounded, size: 16, color: kBrand),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, weight: FontWeight.w800)),
                Text(app.tr('Hot tiffin, snacks & kaapi in 15 mins', 'சூடான டிபன், ஸ்நாக்ஸ், காபி 15 நிமிடத்தில்'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, color: kMuted)),
              ]),
            ),
          ]),
          ValueListenableBuilder<int>(
            valueListenable: _dropSecs,
            builder: (c, s, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(8)),
              child: Text(_clockText(s), style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w800, color: kBrand)),
            ),
          ),
        ),
        SizedBox(
          height: 222,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 2, 6, 4),
            itemCount: food.drops.length,
            itemBuilder: (c, i) => _dropCard(food.drops[i]),
          ),
        ),
      ]),
    );
  }

  Widget _dropCard(FoodDrop d) {
    final qty = cart.qtyOfItem(d.itemId);
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine), boxShadow: kSoftShadow),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: () => _openHotelId(d.hotelId),
          behavior: HitTestBehavior.opaque,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 96,
              decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(14)),
              clipBehavior: Clip.antiAlias,
              child: Stack(fit: StackFit.expand, children: [
                if (d.picture != null && d.picture!.isNotEmpty) NetImg(file: d.picture, cacheWidth: 380) else const Icon(Icons.restaurant_rounded, color: kBrand, size: 30),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(240), borderRadius: BorderRadius.circular(8)),
                    child: Text('⚡ ${d.etaMin} ${app.tr('mins', 'நிமி')}', style: ts(9.5, weight: FontWeight.w800, color: kBrand)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 7),
            Row(children: [
              VegDot(veg: d.veg, size: 11),
              const SizedBox(width: 5),
              Expanded(child: Text(d.hotelName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, color: kMuted))),
            ]),
            const SizedBox(height: 2),
            Text(d.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, weight: FontWeight.w800, height: 1.2)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: kTintSoft))),
          child: Row(children: [
            Expanded(
              child: Row(children: [
                Text(rupee(d.price), style: ts(13, weight: FontWeight.w800)),
                if (d.oldPrice != null && d.oldPrice! > d.price) ...[
                  const SizedBox(width: 4),
                  Flexible(child: Text(rupee(d.oldPrice!), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, color: kMuted).copyWith(decoration: TextDecoration.lineThrough))),
                ],
              ]),
            ),
            if (qty == 0)
              GestureDetector(
                onTap: () => _addDrop(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBrandMid)),
                  child: Text('+ ${app.tr('ADD', 'சேர்')}', style: ts(11, weight: FontWeight.w800, color: kBrand)),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(onTap: () => cart.decItem(d.itemId), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: Icon(Icons.remove_rounded, size: 15, color: Colors.white))),
                  Text('$qty', style: ts(12, weight: FontWeight.w800, color: Colors.white)),
                  GestureDetector(onTap: () => _addDrop(d), child: const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3), child: Icon(Icons.add_rounded, size: 15, color: Colors.white))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  /// Adds a dish on THIS page (drops "+ADD", story "Order this dish"). Nothing to choose = straight into the bag.
  /// Portion options = the customize sheet opens over Home. Never opens the hotel page.
  Future<void> _addDrop(FoodDrop d) => _quickAdd(d.hotelId, d.itemId, null);

  Future<void> _quickAdd(int? hotelId, int? itemId, String? nameEn) async {
    final h = _hotelById(hotelId);
    if (h == null) return;
    if (!(h.openNow && h.acceptsOrders)) {
      _toast(h.openNow ? app.tr('This hotel is not taking orders now.', 'இந்த ஹோட்டல் இப்போது ஆர்டர் எடுக்கவில்லை.') : app.tr('This hotel is closed now.', 'இந்த ஹோட்டல் இப்போது மூடப்பட்டுள்ளது.'));
      return;
    }
    HotelMenu? m = food.cachedMenu(h.id);
    if (m == null) {
      try {
        m = await food.loadMenu(h.id);
      } catch (_) {}
    }
    if (!mounted) return;
    FoodItem? item;
    if (m != null) {
      for (final it in m.items) {
        if (itemId != null ? it.id == itemId : (nameEn != null && it.nameEn == nameEn)) item = it;
      }
    }
    if (item == null || !item.available) {
      _toast(app.tr('This dish is not available now.', 'இந்த உணவு இப்போது இல்லை.'));
      return;
    }
    await foodQuickAdd(context, h, item, spices: m?.spiceLevels ?? const <FoodSpice>[]);
  }

  // ---------- hotels ----------
  Widget _hotelsHead(int n) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.tr('Top Restaurants Near You', 'உங்களுக்கு அருகிலுள்ள ஹோட்டல்கள்'), style: ts(16, weight: FontWeight.w800)),
              Text(app.tr('Tap any hotel for full item-wise menu & Half/Full options', 'ஹோட்டலை தொட்டால் முழு மெனு & Half/Full தேர்வுகள்'), style: ts(11, color: kMuted)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine), boxShadow: kSoftShadow),
            child: Text(app.tr('$n Hotels', '$n ஹோட்டல்'), style: ts(11.5, weight: FontWeight.w800, color: kBrand)),
          ),
        ]),
      );

  Widget _hotelCard(FoodHotel h) {
    final closed = !(h.openNow && h.acceptsOrders);
    final pick = _pickup;
    final area = (h.area != null && h.area!.isNotEmpty) ? h.area! : app.tr('Aruppukottai', 'அருப்புக்கோட்டை');
    final km = _km(h);
    final badge = pick ? '🛍️ ${km != null ? '$km ${app.tr('away', 'தொலைவு')} • ' : ''}${app.tr('Zero Delivery Fee', 'டெலிவரி கட்டணம் இல்லை')}' : '✨ $area${km != null ? ' • $km' : ''}';
    String? tag;
    if (pick) {
      tag = app.tr('Skip the Queue • Counter Pickup', 'வரிசை இல்லை • கவுண்டர் பிக்கப்');
    } else if (h.offerCode != null) {
      tag = h.offerText;
    } else if (h.canDeliver && h.deliveryFee <= 0) {
      tag = app.tr('Free delivery', 'இலவச டெலிவரி');
    }
    final dish = _featuredDish(h);
    final m = food.cachedMenu(h.id);
    final dishCount = (m != null && m.items.isNotEmpty) ? m.items.length : h.itemCount;
    final cuisine = h.cuisine.isNotEmpty ? h.cuisine : app.tr('Local hotel', 'உள்ளூர் ஹோட்டல்');
    return GestureDetector(
      onTap: () => _openHotel(h),
      child: Opacity(
        opacity: closed ? 0.78 : 1,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kLine), boxShadow: kSoftShadow),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 176,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: kTint),
                NetImg(file: h.picture, cacheWidth: 900),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0x33000000), Color(0xD9000000)], stops: [0.3, 0.6, 1]))),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withAlpha(242), borderRadius: BorderRadius.circular(20)),
                        child: Text(badge, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, weight: FontWeight.w800, color: pick ? kGreen : kBrand)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(20)),
                      child: Text('${h.rating.toStringAsFixed(1)} ★', style: ts(11.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ]),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        if (closed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: kRed, borderRadius: BorderRadius.circular(7)),
                            child: Text(h.openNow ? app.tr('Not taking orders', 'ஆர்டர் இல்லை') : app.tr('Closed now', 'இப்போது மூடப்பட்டுள்ளது'), style: ts(10, weight: FontWeight.w800, color: Colors.white)),
                          )
                        else if (tag != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: pick ? kGreen : kBrand, borderRadius: BorderRadius.circular(7)),
                            child: Text(tag, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10, weight: FontWeight.w800, color: Colors.white)),
                          ),
                        Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, weight: FontWeight.w800, color: Colors.white, height: 1.15)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text(pick ? app.tr('Ready in ${h.prepMinutes} mins', '${h.prepMinutes} நிமிடத்தில் தயார்') : app.tr('${h.shownEta} mins', '${h.shownEta} நிமி'), style: ts(11.5, weight: FontWeight.w800)),
                    ),
                  ]),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text(cuisine, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, weight: FontWeight.w600, color: kMuted))),
                  if (h.priceForTwo != null && h.priceForTwo! > 0) Text(app.tr('${rupee(h.priceForTwo!)} for two', '${rupee(h.priceForTwo!)} இருவருக்கு'), style: ts(11.5, weight: FontWeight.w700, color: kMuted)),
                ]),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 9, 9),
                  decoration: BoxDecoration(color: kTint.withAlpha(170), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          dishCount > 0 ? app.tr('$dishCount DISHES • HALF / FULL OPTIONS', '$dishCount உணவுகள் • HALF / FULL') : app.tr('FULL MENU • HALF / FULL OPTIONS', 'முழு மெனு • HALF / FULL'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(9, weight: FontWeight.w800, color: kBrand),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dish != null ? '${dish.name} • ${rupee(dish.fromPrice)}' : (h.priceFrom != null ? app.tr('Dishes from ${rupee(h.priceFrom!)}', '${rupee(h.priceFrom!)} முதல்') : app.tr('See what is cooking', 'என்ன சமைக்கிறார்கள் பாருங்கள்')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts(12.5, weight: FontWeight.w700),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                      decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(app.tr('View Menu', 'மெனு'), style: ts(11.5, weight: FontWeight.w800, color: Colors.white)),
                        const Icon(Icons.chevron_right_rounded, size: 15, color: Colors.white),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _state(IconData icon, String title, String sub, {VoidCallback? retry, String? retryLabel}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 20),
      child: Column(children: [
        Container(width: 88, height: 88, decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle), child: Icon(icon, size: 40, color: kBrand)),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: ts(17, weight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(sub, textAlign: TextAlign.center, style: ts(12.5, color: kMuted, height: 1.4)),
        if (retry != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(onPressed: retry, icon: const Icon(Icons.refresh_rounded), label: Text(retryLabel ?? app.tr('Try again', 'மீண்டும் முயற்சி'))),
        ],
      ]),
    );
  }

  Widget _body() {
    final list = _list();
    final slivers = <Widget>[
      SliverToBoxAdapter(child: _pickupCallout()),
      SliverToBoxAdapter(child: _stories()),
      SliverToBoxAdapter(child: _categories()),
      SliverToBoxAdapter(child: _promo()),
      SliverToBoxAdapter(child: _drops()),
    ];
    if (food.loading && !food.loadedOnce && food.hotels.isEmpty) {
      slivers.add(const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 0), child: Column(children: [PulseBox(height: 260, radius: 24), SizedBox(height: 16), PulseBox(height: 260, radius: 24)]))));
    } else if (food.error != null && food.hotels.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _state(Icons.wifi_off_rounded, app.tr('Could not load hotels', 'ஹோட்டல்களை ஏற்ற முடியவில்லை'), food.error!, retry: () => food.loadHotels(force: true))));
    } else if (food.hotels.isEmpty) {
      slivers.add(SliverToBoxAdapter(child: _state(Icons.storefront_rounded, app.tr('Hotels are coming soon', 'ஹோட்டல்கள் விரைவில்'), app.tr('We are adding Aruppukottai hotels. Check back soon!', 'அருப்புக்கோட்டை ஹோட்டல்களை சேர்த்து வருகிறோம். விரைவில் வாருங்கள்!'))));
    } else if (list.isEmpty) {
      slivers.add(SliverToBoxAdapter(
        child: _state(Icons.search_off_rounded, app.tr('No matching restaurants', 'பொருந்தும் ஹோட்டல் இல்லை'), app.tr('Try resetting your search, category, or dietary filter', 'தேடல், வகை அல்லது filter-ஐ மாற்றி முயற்சிக்கவும்'),
            retry: () => setState(() {
                  _filter = 'all';
                  _cat = 'all';
                  _q.clear();
                }),
            retryLabel: app.tr('Show all hotels', 'அனைத்து ஹோட்டல்களும்')),
      ));
    } else {
      slivers.add(SliverToBoxAdapter(child: _hotelsHead(list.length)));
      slivers.add(SliverList(delegate: SliverChildBuilderDelegate((c, i) => _hotelCard(list[i]), childCount: list.length)));
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
    slivers.add(SliverToBoxAdapter(child: SizedBox(height: cart.isEmpty ? 24 : 96)));
    return RefreshIndicator(
      onRefresh: () => food.loadHotels(force: true),
      child: CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: slivers),
    );
  }

  // ---------- bottom navigation (Home / Explore / Bag / Dine-Out) ----------
  Widget _navItem(IconData icon, String label, VoidCallback tap, {bool on = false, int badge = 0}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tap,
      child: SizedBox(
        width: 74,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: on ? kTint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, size: 21, color: on ? kBrand : kMuted),
            ),
            if (badge > 0)
              Positioned(
                right: 6,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(8)),
                  child: Text('$badge', style: ts(9, weight: FontWeight.w800, color: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(height: 2),
          Text(label, style: ts(10.5, weight: on ? FontWeight.w800 : FontWeight.w500, color: on ? kBrand : kMuted)),
        ]),
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _navItem(Icons.home_rounded, app.tr('Home', 'முகப்பு'), () {}, on: true),
        _navItem(Icons.explore_outlined, app.tr('Explore', 'ஆராய்க'), _soon),
        _navItem(Icons.shopping_bag_outlined, app.tr('Bag', 'பை'), () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CartScreen())), badge: cart.count),
        _navItem(Icons.restaurant_rounded, app.tr('Dine-Out', 'டைன்-அவுட்'), _soon),
      ]),
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
              backgroundColor: const Color(0xFFF8FAFD),
              body: Stack(children: [
                Column(children: [
                  _header(),
                  Expanded(child: _body()),
                ]),
                if (!cart.isEmpty) const Positioned(left: 0, right: 0, bottom: 0, child: CartBar(safe: false)),
              ]),
              bottomNavigationBar: _bottomBar(),
            ),
          ),
        );
      },
    );
  }
}

/// Floating bar above the bottom navigation: "2 Items • ₹240  ·  View Cart".
class CartBar extends StatelessWidget {
  final bool safe; // true when it sits at the very bottom of a screen (adds the phone's bottom inset)

  const CartBar({super.key, this.safe = true});

  @override
  Widget build(BuildContext context) {
    // listens by itself: a const CartBar is never rebuilt by its parent, so the count would stay at 1
    return ListenableBuilder(listenable: Listenable.merge([cart, food, app]), builder: (c, _) => _bar(c));
  }

  Widget _bar(BuildContext context) {
    final h = cart.hotel;
    FoodOffer? best; // best unlocked offer
    FoodOffer? next; // nearest offer still to unlock
    for (final o in food.offers) {
      if (o.minOrder <= cart.itemsTotal) {
        if (best == null || o.minOrder > best.minOrder) best = o;
      } else if (next == null || o.minOrder < next.minOrder) {
        next = o;
      }
    }
    String desc(FoodOffer o) => (app.lang == 'ta' && (o.descTa ?? '').isNotEmpty) ? o.descTa! : o.descEn;
    final n = cart.count;
    final String sub;
    if (best != null) {
      sub = app.tr('🎉 ${desc(best)} (${best.code}) unlocked!', '🎉 ${desc(best)} (${best.code}) கிடைத்தது!');
    } else if (next != null) {
      sub = app.tr('Add ₹${(next.minOrder - cart.itemsTotal).ceil()} more for ${desc(next)}', '₹${(next.minOrder - cart.itemsTotal).ceil()} சேர்த்தால் ${desc(next)}');
    } else {
      sub = h == null ? '' : h.name;
    }
    return SafeArea(
      top: false,
      bottom: safe,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const CartScreen())),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kBrand, Color(0xFF1666D6)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: kBrandShadow, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.white.withAlpha(50), borderRadius: BorderRadius.circular(12)),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$n', key: ValueKey<int>(n), style: ts(15, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$n ${n == 1 ? app.tr('Item', 'பொருள்') : app.tr('Items', 'பொருட்கள்')} • ${rupee(cart.itemsTotal)}', style: ts(13, weight: FontWeight.w800, color: Colors.white)),
                if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, color: kOnBrandSoft)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(app.tr('View Cart', 'கார்ட்'), style: ts(12.5, weight: FontWeight.w800, color: kBrand)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: kBrand),
              ]),
            ),
          ]),
        ),
      ),
    ));
  }
}
