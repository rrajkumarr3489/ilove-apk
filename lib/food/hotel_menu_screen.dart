import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../bus/bus_api.dart';
import '../theme.dart';
import 'dish_sheet.dart';
import 'food_cart.dart';
import 'food_home_screen.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';

const Color _kPage = Color(0xFFF8FAFD);
const Color _kSlate = Color(0xFF0F172A);

/// One section of the menu (Recommended, a category, Others).
class _Sec {
  final String key;
  final String title;
  final List<FoodItem> items;
  _Sec(this.key, this.title, this.items);
}

/// Hotel storefront + item-wise menu (SkyBite design): top nav with Delivery/Pickup pill, hotel quick-switch bar,
/// cover with floating info card, sticky search + chips, grouped dishes, floating "Menu" jump button.
class HotelMenuScreen extends StatefulWidget {
  final FoodHotel hotel;
  final int? openItemId; // opens this dish's sheet as soon as the menu is ready

  const HotelMenuScreen({super.key, required this.hotel, this.openItemId});

  @override
  State<HotelMenuScreen> createState() => _HotelMenuScreenState();
}

class _HotelMenuScreenState extends State<HotelMenuScreen> {
  late FoodHotel _hotel;
  HotelMenu? _menu;
  String? _error;
  String _q = '';
  bool _fVeg = false;
  bool _fBest = false;
  bool _fSpicy = false;
  bool _jump = false;
  bool _autoOpened = false;
  int _token = 0;
  final TextEditingController _searchC = TextEditingController();
  final ScrollController _sc = ScrollController();
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _hotel = widget.hotel;
    _menu = food.cachedMenu(_hotel.id);
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    _sc.dispose();
    super.dispose();
  }

  FoodHotel get _h => _menu?.hotel ?? _hotel;
  bool get _canOrder => _h.openNow && _h.acceptsOrders;
  bool get _pickup => cart.fulfil == 'Pickup';

  Future<void> _load() async {
    final my = ++_token;
    final id = _hotel.id;
    try {
      final m = await food.loadMenu(id);
      if (!mounted || my != _token) return;
      setState(() {
        _menu = m;
        _error = null;
      });
      final oid = widget.openItemId;
      if (oid != null && !_autoOpened) {
        _autoOpened = true;
        for (final it in m.items) {
          if (it.id == oid && it.available) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showDish(it);
            });
            break;
          }
        }
      }
    } catch (e) {
      if (!mounted || my != _token) return;
      setState(() => _error = BusApi.friendly(e));
    }
  }

  void _msg(String t) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
  }

  /// Quick-switch to another hotel without leaving the screen.
  void _switchTo(FoodHotel h) {
    if (h.id == _h.id) return;
    setState(() {
      _hotel = h;
      _menu = food.cachedMenu(h.id);
      _error = null;
      _q = '';
      _fVeg = false;
      _fBest = false;
      _fSpicy = false;
      _jump = false;
      _autoOpened = true;
      _keys.clear();
    });
    _searchC.clear();
    if (_sc.hasClients) _sc.jumpTo(0);
    _load();
  }

  void _toggleMode() {
    final next = _pickup ? 'Delivery' : 'Pickup';
    if (next == 'Pickup' && !_h.canPickup) {
      _msg(app.tr('This hotel does not offer self-pickup.', 'இந்த ஹோட்டலில் நேரில் எடுத்துக்கொள்ளும் வசதி இல்லை.'));
      return;
    }
    if (next == 'Delivery' && !_h.canDeliver) {
      _msg(app.tr('This hotel does not deliver.', 'இந்த ஹோட்டல் டெலிவரி செய்வதில்லை.'));
      return;
    }
    cart.setFulfil(next);
  }

  /// Same behaviour as Home: nothing to choose = straight into the bag, portion options = the sheet.
  Future<void> _add(FoodItem item) => foodQuickAdd(context, _h, item, spices: _menu?.spiceLevels ?? const <FoodSpice>[]);

  void _showDish(FoodItem item) => showDishSheet(context, _h, item, spices: _menu?.spiceLevels ?? const <FoodSpice>[]);

  // ---------- sections ----------
  List<_Sec> _sections() {
    final m = _menu;
    if (m == null) return const <_Sec>[];
    final q = _q.trim().toLowerCase();
    bool ok(FoodItem d) {
      if (q.isNotEmpty && !('${d.nameEn} ${d.nameTa ?? ''} ${d.descEn ?? ''} ${d.descTa ?? ''}'.toLowerCase().contains(q))) return false;
      if (_fVeg && !d.veg) return false;
      if (_fBest && !d.bestseller) return false;
      if (_fSpicy && !d.spicy) return false;
      return true;
    }

    final out = <_Sec>[];
    final best = m.items.where((i) => i.bestseller && i.available && ok(i)).toList();
    if (best.isNotEmpty) out.add(_Sec('rec', app.tr('Recommended', 'பரிந்துரை'), best));
    for (final c in m.categories) {
      final its = m.itemsIn(c.id).where(ok).toList();
      if (its.isNotEmpty) out.add(_Sec('c${c.id}', c.name, its));
    }
    final loose = m.items.where((i) => i.categoryId == null && ok(i)).toList();
    if (loose.isNotEmpty) out.add(_Sec('other', app.tr('Others', 'மற்றவை'), loose));
    return out;
  }

  void _scrollTo(String key) {
    setState(() => _jump = false);
    final k = _keys[key];
    if (k == null || k.currentContext == null || !_sc.hasClients) return;
    final ro = k.currentContext!.findRenderObject();
    if (ro == null) return;
    final vp = RenderAbstractViewport.of(ro);
    final off = vp.getOffsetToReveal(ro, 0.0).offset - 104;
    _sc.animateTo(off.clamp(_sc.position.minScrollExtent, _sc.position.maxScrollExtent).toDouble(), duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  // ---------- top ----------
  String _etaLine(FoodHotel h, {bool nav = false}) {
    final dist = h.distanceKm != null ? ' • ${h.distanceKm!.toStringAsFixed(1)} km ${app.tr('away', 'தொலைவு')}' : '';
    if (_pickup) {
      final base = app.tr('Ready in ${h.prepMinutes} mins', '${h.prepMinutes} நிமிடத்தில் தயார்');
      return nav ? '🛍️ $base${h.area != null ? ' • ${h.area}' : ''}' : '🛍️ ${app.tr('Self-Pickup', 'நேரில் எடுக்க')} $base$dist';
    }
    final base = app.tr('${h.shownEta} mins', '${h.shownEta} நிமிடம்');
    return nav ? '🛵 $base${h.area != null ? ' • ${h.area}' : ''}' : '🛵 ${app.tr('Express Delivery in', 'விரைவு டெலிவரி')} $base$dist';
  }

  Widget _nav() {
    final h = _h;
    return Container(
      padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 10),
      decoration: const BoxDecoration(color: Color(0xF2FFFFFF), border: Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine), boxShadow: kSoftShadow), child: const Icon(Icons.arrow_back_rounded, size: 19, color: kInk)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, weight: FontWeight.w800)),
            Text(_etaLine(h, nav: true), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, weight: FontWeight.w600, color: kBrand)),
          ]),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _toggleMode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBrandMid)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_pickup ? '🛍️' : '🛵', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(_pickup ? app.tr('Self-Pickup', 'நேரில்') : app.tr('Delivery', 'டெலிவரி'), style: ts(11, weight: FontWeight.w800, color: kBrand)),
              const SizedBox(width: 4),
              const Icon(Icons.repeat_rounded, size: 12, color: kBrand),
            ]),
          ),
        ),
      ]),
    );
  }

  String _short(FoodHotel h) {
    final n = h.name;
    if (n.length <= 16) return n;
    final w = n.split(' ');
    return w.length > 2 ? w.sublist(w.length - 2).join(' ') : n;
  }

  Widget _switcher() {
    final list = food.hotels.isEmpty ? <FoodHotel>[_h] : food.hotels;
    return Container(
      height: 42,
      decoration: const BoxDecoration(color: Color(0xBFE8F0FE), border: Border(bottom: BorderSide(color: kLine))),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        children: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text(app.tr('HOTELS:', 'ஹோட்டல்கள்:'), style: ts(10.5, weight: FontWeight.w800, color: kBrand)))),
          for (final x in list)
            GestureDetector(
              onTap: () => _switchTo(x),
              child: Container(
                margin: const EdgeInsets.only(right: 7),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: x.id == _h.id ? kBrand : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: x.id == _h.id ? kBrand : kBrandMid),
                  boxShadow: x.id == _h.id ? const [BoxShadow(color: kBrandShadow, blurRadius: 8, offset: Offset(0, 3))] : null,
                ),
                child: Text(_short(x), style: ts(11.5, weight: FontWeight.w700, color: x.id == _h.id ? Colors.white : kInk)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String t, Color bg, Color fg, Color bd, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: bd)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
          Text(t, style: ts(10.5, weight: FontWeight.w800, color: fg)),
        ]),
      );

  Widget _hero() {
    final h = _h;
    final cuisine = [h.cuisine, h.area ?? ''].where((e) => e.isNotEmpty).join(' • ');
    String? offerCode;
    if (_menu != null && _menu!.offers.isNotEmpty) {
      offerCode = _menu!.offers.first.code;
    } else {
      offerCode = h.offerCode;
    }
    final rated = h.ratingCount > 0;
    return Stack(clipBehavior: Clip.none, children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 160,
        child: Stack(fit: StackFit.expand, children: [
          Container(color: kTint, child: NetImg(file: h.picture, cacheWidth: 900)),
          const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [_kPage, Color(0x400F172A), Color(0x00000000)], stops: [0, 0.55, 1]))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 112, 14, 0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xF2FFFFFF), borderRadius: BorderRadius.circular(24), border: Border.all(color: kLine), boxShadow: const [BoxShadow(color: Color(0x1A1A73E8), blurRadius: 22, offset: Offset(0, 10))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (food.flag('Food.ShowHygieneBadge', true)) _badge(app.tr('5★ Hygiene', '5★ சுகாதாரம்'), kTintSoft, kBrand, kBrandMid, icon: Icons.shield_outlined),
                    if (h.pureVeg) _badge(app.tr('100% Pure Veg', '100% சைவம்'), const Color(0xFFE6F4EA), kGreen, const Color(0xFFB7E1C1)),
                    if (!_canOrder) _badge(h.openNow ? app.tr('Not taking orders', 'ஆர்டர் இல்லை') : app.tr('Closed now', 'இப்போது மூடப்பட்டுள்ளது'), const Color(0xFFFCE8E6), kRed, const Color(0xFFF6C0BB)),
                  ]),
                  const SizedBox(height: 6),
                  Text(h.name, style: ts(20, weight: FontWeight.w800, height: 1.15)),
                  if (cuisine.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(cuisine, style: ts(12.5, color: kMuted))),
                ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Text('${(rated ? h.rating : 3.0).toStringAsFixed(1)} ★', style: ts(13.5, weight: FontWeight.w800, color: Colors.white)),
                  Text(rated ? app.tr('${h.ratingCount} ratings', '${h.ratingCount} மதிப்பீடு') : app.tr('New', 'புதியது'), style: ts(9.5, color: const Color(0xFFD7F0DD))),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: kTintSoft))),
              child: Row(children: [
                Expanded(child: Text(_etaLine(h), style: ts(11.5, weight: FontWeight.w800, color: kBrand))),
                if (offerCode != null && offerCode.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFB7E1C1))),
                    child: Text('$offerCode ${app.tr('Eligible', 'பெறலாம்')}', style: ts(10.5, weight: FontWeight.w800, color: kGreen)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }

  // ---------- sticky search + chips ----------
  Widget _chip(String label, bool on, VoidCallback f, {Widget? lead}) => GestureDetector(
        onTap: f,
        child: Container(
          margin: const EdgeInsets.only(right: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: on ? kBrand : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? kBrand : kLine)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (lead != null) ...[lead, const SizedBox(width: 6)],
            Text(label, style: ts(11.5, weight: FontWeight.w700, color: on ? Colors.white : kInk)),
          ]),
        ),
      );

  Widget _stickyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: const BoxDecoration(color: Color(0xF2F8FAFD), border: Border(bottom: BorderSide(color: kLine))),
      child: Column(children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBrandMid), boxShadow: kSoftShadow),
          child: Row(children: [
            const Icon(Icons.search_rounded, size: 18, color: kBrand),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey<String>('menuSearch'),
                controller: _searchC,
                onChanged: (v) => setState(() => _q = v),
                style: ts(13),
                decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: app.tr('Search dishes inside this menu...', 'இந்த மெனுவில் தேடுங்கள்...'), hintStyle: ts(12.5, color: kMuted)),
              ),
            ),
            if (_q.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchC.clear();
                  setState(() => _q = '');
                },
                child: const Icon(Icons.close_rounded, size: 17, color: kMuted),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _chip(app.tr('Veg Only', 'சைவம் மட்டும்'), _fVeg, () => setState(() => _fVeg = !_fVeg), lead: VegDot(veg: true, size: 12)),
            _chip(app.tr('⭐ Bestseller', '⭐ அதிகம் விற்பனை'), _fBest, () => setState(() => _fBest = !_fBest)),
            _chip(app.tr('🌶️ Spicy', '🌶️ காரம்'), _fSpicy, () => setState(() => _fSpicy = !_fSpicy)),
          ]),
        ),
      ]),
    );
  }

  // ---------- dishes ----------
  Widget _addButton(FoodItem item) {
    if (!item.available) {
      return Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
        child: Text(app.tr('Sold out', 'தீர்ந்தது'), style: ts(11.5, weight: FontWeight.w700, color: kMuted)),
      );
    }
    final q = cart.qtyOfItem(item.id);
    if (q == 0) {
      return GestureDetector(
        onTap: () => _add(item),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBrandMid), boxShadow: const [BoxShadow(color: Color(0x261A73E8), blurRadius: 10, offset: Offset(0, 4))]),
          child: Text('+ ${app.tr('ADD', 'சேர்')}', style: ts(12.5, weight: FontWeight.w800, color: kBrand)),
        ),
      );
    }
    return Container(
      height: 32,
      decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: kBrandShadow, blurRadius: 10, offset: Offset(0, 4))]),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => cart.decItem(item.id), child: const SizedBox(width: 32, height: 32, child: Icon(Icons.remove_rounded, size: 17, color: Colors.white))),
        Text('$q', style: ts(13, weight: FontWeight.w800, color: Colors.white)),
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _add(item), child: const SizedBox(width: 32, height: 32, child: Icon(Icons.add_rounded, size: 17, color: Colors.white))),
      ]),
    );
  }

  Widget _dish(FoodItem item) {
    final dim = !item.available;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showDish(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kLine), boxShadow: kSoftShadow),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Opacity(
              opacity: dim ? 0.55 : 1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  VegDot(veg: item.veg, size: 14),
                  if (item.bestseller) _badge(app.tr('★ BESTSELLER', '★ அதிகம் விற்பனை'), const Color(0xFFFFF3D6), const Color(0xFFB26A00), const Color(0xFFF3D590)),
                  if (item.spicy) const Text('🌶️', style: TextStyle(fontSize: 11)),
                ]),
                const SizedBox(height: 5),
                Text(item.name, style: ts(14.5, weight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 4),
                Wrap(spacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(item.hasVariants ? app.tr('From ${rupee(item.fromPrice)}', '${rupee(item.fromPrice)} முதல்') : rupee(item.price), style: ts(13, weight: FontWeight.w800)),
                  if (item.oldPrice != null && item.oldPrice! > item.fromPrice) Text(rupee(item.oldPrice!), style: ts(11.5, color: kMuted).copyWith(decoration: TextDecoration.lineThrough)),
                  if (item.itemRating > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(6)),
                      child: Text('${item.itemRating.toStringAsFixed(1)} ★', style: ts(10.5, weight: FontWeight.w800, color: kGreen)),
                    ),
                ]),
                if (item.desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(item.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11.5, color: kMuted, height: 1.4))),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: Column(children: [
              SizedBox(
                height: 112,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 96,
                    child: Container(
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                      child: FoodPhoto(file: item.picture, width: 112, height: 96, radius: 16, gray: dim),
                    ),
                  ),
                  Positioned(left: 8, right: 8, bottom: 0, child: _addButton(item)),
                ]),
              ),
              if (item.hasVariants)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(app.tr('Customisable • ${item.variants.take(2).map((v) => v.name).join(' / ')}', 'தேர்வுகள் • ${item.variants.take(2).map((v) => v.name).join(' / ')}'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(9.5, weight: FontWeight.w700, color: kBrand)),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _section(_Sec s) {
    final k = _keys.putIfAbsent(s.key, () => GlobalKey());
    return Container(
      key: k,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(child: Text(s.title, style: ts(15, weight: FontWeight.w800))),
            Text(app.tr('${s.items.length} items', '${s.items.length} பொருட்கள்'), style: ts(11.5, weight: FontWeight.w600, color: kMuted)),
          ]),
        ),
        for (final it in s.items) _dish(it),
      ]),
    );
  }

  Widget _list(List<_Sec> secs) {
    final m = _menu;
    if (m == null) {
      if (_error != null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 50, 32, 20),
          child: Column(children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: kBrandMid),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: ts(14, color: kMuted)),
            TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: Text(app.tr('Try again', 'மீண்டும் முயற்சி'))),
          ]),
        );
      }
      return const Padding(padding: EdgeInsets.fromLTRB(14, 16, 14, 0), child: PulseBox(height: 300));
    }
    if (secs.isEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(14, 16, 14, 0),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kLine)),
        child: Column(children: [
          Text(app.tr('No dishes match your filter', 'பொருத்தமான உணவு இல்லை'), style: ts(14, weight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(app.tr('Clear search or filter chips to see all ${m.items.length} items', 'தேடல் / வடிகட்டியை நீக்கினால் ${m.items.length} பொருட்களும் தெரியும்'), textAlign: TextAlign.center, style: ts(12, color: kMuted)),
        ]),
      );
    }
    return Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final s in secs) _section(s)]));
  }

  // ---------- floating Menu button + jump popover ----------
  Widget _jumpButton(List<_Sec> secs) {
    return Positioned(
      right: 16,
      bottom: 18,
      child: GestureDetector(
        onTap: () => setState(() => _jump = !_jump),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(color: _kSlate, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF334155)), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.menu_book_rounded, size: 15, color: kBrandMid),
            const SizedBox(width: 7),
            Text(app.tr('Menu', 'மெனு'), style: ts(12.5, weight: FontWeight.w800, color: Colors.white)),
          ]),
        ),
      ),
    );
  }

  Widget _jumpPopover(List<_Sec> secs) {
    return Positioned(
      right: 16,
      bottom: 66,
      child: Container(
        width: 232,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: kLine), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, 12))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Text(app.tr('Jump to Section', 'பிரிவுக்குச் செல்'), style: ts(12.5, weight: FontWeight.w800))),
              GestureDetector(onTap: () => setState(() => _jump = false), child: const Icon(Icons.close_rounded, size: 17, color: kMuted)),
            ]),
          ),
          const Divider(height: 1, color: kTintSoft),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 6),
              children: [
                for (final s in secs)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _scrollTo(s.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
                      child: Row(children: [
                        Expanded(child: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, weight: FontWeight.w700))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(10)), child: Text('${s.items.length}', style: ts(10.5, weight: FontWeight.w800, color: kBrand))),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cart, app, food]),
      builder: (context, _) {
        final secs = _sections();
        return foodScale(
          context,
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
            child: Scaffold(
              backgroundColor: _kPage,
              body: Column(children: [
                _nav(),
                _switcher(),
                Expanded(
                  child: Stack(children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        controller: _sc,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _hero()),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverPersistentHeader(pinned: true, delegate: _Sticky(child: _stickyBar())),
                          SliverToBoxAdapter(child: _list(secs)),
                          SliverToBoxAdapter(child: SizedBox(height: cart.isEmpty ? 90 : 40)),
                        ],
                      ),
                    ),
                    if (_jump) Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _jump = false), child: const SizedBox.expand())),
                    if (secs.isNotEmpty) _jumpButton(secs),
                    if (_jump && secs.isNotEmpty) _jumpPopover(secs),
                  ]),
                ),
              ]),
              bottomNavigationBar: cart.isEmpty ? null : const CartBar(),
            ),
          ),
        );
      },
    );
  }
}

class _Sticky extends SliverPersistentHeaderDelegate {
  final Widget child;

  _Sticky({required this.child});

  @override
  double get minExtent => 104;

  @override
  double get maxExtent => 104;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox(height: 104, child: child);

  @override
  bool shouldRebuild(covariant _Sticky oldDelegate) => true;
}
