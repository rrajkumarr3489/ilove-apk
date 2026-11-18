import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app_state.dart';
import '../bus/bus_api.dart';
import '../theme.dart';
import 'food_cart.dart';
import 'food_home_screen.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';

class HotelMenuScreen extends StatefulWidget {
  final FoodHotel hotel;

  const HotelMenuScreen({super.key, required this.hotel});

  @override
  State<HotelMenuScreen> createState() => _HotelMenuScreenState();
}

class _HotelMenuScreenState extends State<HotelMenuScreen> {
  HotelMenu? _menu;
  String? _error;
  bool _vegOnly = false;
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};
  int _activeCat = -1;
  final ScrollController _sc = ScrollController();

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _menu = food.cachedMenu(widget.hotel.id);
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await food.loadMenu(widget.hotel.id);
      if (!mounted) return;
      setState(() {
        _menu = m;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = BusApi.friendly(e));
    }
  }

  FoodHotel get _h => _menu?.hotel ?? widget.hotel;
  bool get _canOrder => _h.openNow && _h.acceptsOrders;

  void _msg(String t) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
  }

  Future<void> _add(FoodItem item) async {
    if (!_canOrder) {
      _msg(_h.openNow ? app.tr('This hotel is not taking orders now.', 'இந்த ஹோட்டல் இப்போது ஆர்டர் எடுக்கவில்லை.') : app.tr('This hotel is closed now.', 'இந்த ஹோட்டல் இப்போது மூடப்பட்டுள்ளது.'));
      return;
    }
    if (!item.available) return;
    if (cart.hotel != null && cart.hotel!.id != _h.id && !cart.isEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(app.tr('Start a new cart?', 'புதிய கார்ட் தொடங்கவா?'), style: ts(17, weight: FontWeight.w800)),
          content: Text(
            app.tr('Your cart has food from ${cart.hotel!.name}. Adding from ${_h.name} will clear it.',
                'உங்கள் கார்ட்டில் ${cart.hotel!.name} உணவு உள்ளது. ${_h.name} உணவை சேர்த்தால் அது நீக்கப்படும்.'),
            style: ts(14, color: kMuted, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(app.tr('No', 'வேண்டாம்'))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(app.tr('Yes, start new', 'ஆம், புதியது'))),
          ],
        ),
      );
      if (ok != true) return;
      cart.clear();
    }
    if (!mounted) return;
    if (item.hasVariants) {
      _pickVariant(item);
    } else {
      cart.add(_h, item, null);
    }
  }

  void _pickVariant(FoodItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 16),
              Row(children: [
                VegDot(veg: item.veg),
                const SizedBox(width: 8),
                Expanded(child: Text(item.name, style: ts(18, weight: FontWeight.w800))),
              ]),
              const SizedBox(height: 4),
              Text(app.tr('Choose one', 'ஒன்றை தேர்ந்தெடுங்கள்'), style: ts(13, color: kMuted)),
              const SizedBox(height: 10),
              for (final v in item.variants)
                InkWell(
                  onTap: v.available
                      ? () {
                          Navigator.pop(c);
                          cart.add(_h, item, v);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(children: [
                      Expanded(
                        child: Text(v.name, style: ts(15, weight: FontWeight.w600, color: v.available ? kInk : kMuted)),
                      ),
                      Text(v.available ? rupee(v.price) : app.tr('Sold out', 'தீர்ந்தது'), style: ts(15, weight: FontWeight.w800, color: v.available ? kInk : kMuted)),
                      const SizedBox(width: 12),
                      if (v.available)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(10)),
                          child: Text(app.tr('ADD', 'சேர்'), style: ts(12.5, weight: FontWeight.w800, color: kBrandDark)),
                        ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollTo(int catId) {
    final k = _keys[catId];
    if (k == null || k.currentContext == null || !_sc.hasClients) return;
    setState(() => _activeCat = catId);
    final ro = k.currentContext!.findRenderObject();
    if (ro == null) return;
    final vp = RenderAbstractViewport.of(ro);
    final pad = MediaQuery.of(context).padding.top + kToolbarHeight + 52;
    final off = vp.getOffsetToReveal(ro, 0.0).offset - pad;
    _sc.animateTo(off.clamp(_sc.position.minScrollExtent, _sc.position.maxScrollExtent).toDouble(),
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Widget _addButton(FoodItem item) {
    if (!item.available) {
      return Container(
        height: 34,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
        child: Text(app.tr('Sold out', 'தீர்ந்தது'), style: ts(12, weight: FontWeight.w700, color: kMuted)),
      );
    }
    final q = cart.qtyOfItem(item.id);
    if (q > 0 && !item.hasVariants) {
      return QtyStepper(qty: q, compact: true, onMinus: () => cart.decItem(item.id), onPlus: () => _add(item));
    }
    return GestureDetector(
      onTap: () => _add(item),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBrand, width: 1.4),
          boxShadow: const [BoxShadow(color: Color(0x262A7DE1), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (q > 0) Text('$q  ', style: ts(13, weight: FontWeight.w800, color: kBrand)),
          Text(app.tr('ADD', 'சேர்'), style: ts(13.5, weight: FontWeight.w800, color: kBrand)),
          if (item.hasVariants) const Icon(Icons.add_rounded, size: 15, color: kBrand),
        ]),
      ),
    );
  }

  Widget _itemRow(FoodItem item) {
    final dim = !item.available;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Opacity(
              opacity: dim ? 0.55 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    VegDot(veg: item.veg),
                    if (item.bestseller) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFE08A00)),
                          const SizedBox(width: 2),
                          Text(app.tr('Bestseller', 'அதிகம் விற்பனை'), style: ts(10.5, weight: FontWeight.w800, color: const Color(0xFFB26A00))),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(item.name, style: ts(16.5, weight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 4),
                  Text(
                    item.hasVariants ? app.tr('From ${rupee(item.fromPrice)}', '${rupee(item.fromPrice)} முதல்') : rupee(item.price),
                    style: ts(15, weight: FontWeight.w800, color: kBrandDark),
                  ),
                  if (item.desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(item.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12.5, color: kMuted, height: 1.4)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 108,
            height: 118,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                FoodThumb(item: item, size: 108, gray: dim),
                Positioned(bottom: 0, child: _addButton(item)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final h = _h;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 270,
      backgroundColor: kBrandDark,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          backgroundColor: Colors.black38,
          child: IconButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        ),
      ),
      title: ListenableBuilder(
        listenable: _sc,
        builder: (c, _) {
          final off = _sc.hasClients ? _sc.offset : 0.0;
          final o = ((off - 130) / 60).clamp(0.0, 1.0).toDouble();
          return Opacity(opacity: o, child: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, weight: FontWeight.w800, color: Colors.white)));
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            HotelCover(hotel: h, gray: !_canOrder),
            Positioned(
              left: 18,
              right: 18,
              bottom: 36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    if (h.pureVeg)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withAlpha(110), borderRadius: BorderRadius.circular(9)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.eco_rounded, size: 13, color: Color(0xFF7BE0A8)),
                          const SizedBox(width: 4),
                          Text(app.tr('PURE VEG', 'சைவம்'), style: ts(10.5, weight: FontWeight.w800, color: Colors.white)),
                        ]),
                      ),
                    RatingBadge(rating: h.rating, count: h.ratingCount),
                  ]),
                  const SizedBox(height: 8),
                  Text(h.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(26, weight: FontWeight.w800, color: Colors.white, height: 1.15)),
                  if (h.cuisine.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(h.cuisine, style: ts(13.5, color: Colors.white.withAlpha(220))),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              child: Container(
                height: 26,
                decoration: const BoxDecoration(color: kBg, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(IconData i, String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x112A7DE1), blurRadius: 12, offset: Offset(0, 5))]),
          child: Column(children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle),
              child: Icon(i, size: 18, color: kBrand),
            ),
            const SizedBox(height: 6),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, weight: FontWeight.w800)),
            const SizedBox(height: 1),
            Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, color: kMuted)),
          ]),
        ),
      );

  Widget _info() {
    final h = _h;
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (h.address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.location_on_rounded, size: 16, color: kBrand),
                const SizedBox(width: 5),
                Expanded(child: Text(h.address, style: ts(13, color: kMuted, height: 1.3))),
              ]),
            ),
          Row(children: [
            _statTile(Icons.timer_outlined, '${h.prepMinutes}-${h.prepMinutes + 10}', app.tr('minutes', 'நிமிடம்')),
            const SizedBox(width: 10),
            _statTile(Icons.delivery_dining_rounded, h.canDeliver ? (h.deliveryFee <= 0 ? app.tr('Free', 'இலவசம்') : rupee(h.deliveryFee)) : '—', app.tr('delivery', 'டெலிவரி')),
            const SizedBox(width: 10),
            _statTile(Icons.shopping_basket_outlined, h.minOrder > 0 ? rupee(h.minOrder) : app.tr('None', 'இல்லை'), app.tr('min order', 'குறைந்தபட்சம்')),
          ]),
          if (h.freeAbove != null && h.freeAbove! > 0 && h.canDeliver && h.deliveryFee > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE3F6EC), Color(0xFFF1FBF6)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.local_offer_rounded, size: 18, color: kGreen),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    app.tr('Free delivery on orders above ${rupee(h.freeAbove!)}', '${rupee(h.freeAbove!)}-க்கு மேல் ஆர்டருக்கு இலவச டெலிவரி'),
                    style: ts(13, weight: FontWeight.w800, color: const Color(0xFF14663F)),
                  ),
                ),
              ]),
            ),
          ],
          if (!_canOrder) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB26A00)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _h.openNow
                        ? app.tr('Not taking orders right now. You can still see the menu.', 'இப்போது ஆர்டர் எடுக்கவில்லை. மெனுவை பார்க்கலாம்.')
                        : app.tr('Closed now${_h.openTime != null && _h.openTime!.length >= 5 ? ' · opens ${_h.openTime!.substring(0, 5)}' : ''}. You can still see the menu.',
                            'இப்போது மூடப்பட்டுள்ளது. மெனுவை பார்க்கலாம்.'),
                    style: ts(12.5, weight: FontWeight.w600, color: const Color(0xFF8A5200)),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _vegSwitch() => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const VegDot(veg: true),
          const SizedBox(width: 10),
          Text(app.tr('Veg only', 'சைவம் மட்டும்'), style: ts(14, weight: FontWeight.w700)),
          const Spacer(),
          Switch(value: _vegOnly, activeColor: kGreen, onChanged: (v) => setState(() => _vegOnly = v)),
        ]),
      );

  Widget _popular(List<FoodItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 12),
          child: Row(children: [
            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE08A00), size: 22),
            const SizedBox(width: 6),
            Text(app.tr('Popular here', 'இங்கு பிரபலமானவை'), style: ts(18, weight: FontWeight.w800)),
          ]),
        ),
        SizedBox(
          height: 218,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (c, i) {
              final it = items[i];
              return Container(
                width: 150,
                margin: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [BoxShadow(color: Color(0x142A7DE1), blurRadius: 14, offset: Offset(0, 6))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(children: [
                      FoodThumb(item: it, size: 130, gray: !it.available),
                      Positioned(left: 7, top: 7, child: Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)), child: VegDot(veg: it.veg, size: 13))),
                    ]),
                    const SizedBox(height: 8),
                    Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, weight: FontWeight.w800)),
                    const Spacer(),
                    Row(children: [
                      Expanded(child: Text(it.hasVariants ? '${rupee(it.fromPrice)}+' : rupee(it.price), style: ts(14.5, weight: FontWeight.w800, color: kBrandDark))),
                      GestureDetector(
                        onTap: () => _add(it),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: it.available ? kBrand : kLine, borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ]),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<FoodItem> items, GlobalKey? key) {
    return Container(
      key: key,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0F2A7DE1), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(children: [
              Text(title, style: ts(17, weight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(8)),
                child: Text('${items.length}', style: ts(12, weight: FontWeight.w800, color: kBrandDark)),
              ),
            ]),
          ),
          for (var i = 0; i < items.length; i++) ...[
            _itemRow(items[i]),
            if (i != items.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: kLine),
          ],
        ],
      ),
    );
  }

  Widget _chipsBar(List<FoodCategory> cats) {
    return Container(
      color: kBg,
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _scrollTo(c.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _activeCat == c.id ? kBrand : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _activeCat == c.id ? kBrand : kLine),
                  ),
                  child: Text(c.name, style: ts(13, weight: FontWeight.w800, color: _activeCat == c.id ? Colors.white : kChipText)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _slivers() {
    final m = _menu;
    if (m == null) {
      if (_error != null) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 50, 32, 20),
              child: Column(children: [
                const Icon(Icons.wifi_off_rounded, size: 44, color: kBrandMid),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center, style: ts(14, color: kMuted)),
                TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: Text(app.tr('Try again', 'மீண்டும் முயற்சி'))),
              ]),
            ),
          ),
        ];
      }
      return const [
        SliverToBoxAdapter(child: Padding(padding: EdgeInsets.fromLTRB(16, 24, 16, 0), child: PulseBox(height: 300))),
      ];
    }
    final out = <Widget>[];
    final cats = <FoodCategory>[];
    final sections = <Widget>[];
    for (final c in m.categories) {
      final its = m.itemsIn(c.id).where((i) => !_vegOnly || i.veg).toList();
      if (its.isEmpty) continue;
      cats.add(c);
      _keys.putIfAbsent(c.id, () => GlobalKey());
      sections.add(_section(c.name, its, _keys[c.id]));
    }
    final loose = m.items.where((i) => i.categoryId == null && (!_vegOnly || i.veg)).toList();
    if (loose.isNotEmpty) sections.add(_section(app.tr('Others', 'மற்றவை'), loose, null));

    final best = m.items.where((i) => i.bestseller && i.available && (!_vegOnly || i.veg)).toList();
    if (best.isNotEmpty) out.add(SliverToBoxAdapter(child: _popular(best)));
    if (cats.length > 1) {
      out.add(SliverPersistentHeader(pinned: true, delegate: _PinnedBar(child: _chipsBar(cats))));
    }
    if (sections.isEmpty) {
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 50, 32, 20),
          child: Text(app.tr('No items to show.', 'காட்ட பொருட்கள் இல்லை.'), textAlign: TextAlign.center, style: ts(14, color: kMuted)),
        ),
      ));
    } else {
      out.add(SliverToBoxAdapter(child: Column(children: [const SizedBox(height: 4), ...sections])));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cart, app]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: kBg,
          body: RefreshIndicator(
            onRefresh: _load,
            edgeOffset: 90,
            child: CustomScrollView(
              controller: _sc,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _hero(),
                SliverToBoxAdapter(child: _info()),
                SliverToBoxAdapter(child: _vegSwitch()),
                ..._slivers(),
                SliverToBoxAdapter(child: SizedBox(height: cart.isEmpty ? 30 : 100)),
              ],
            ),
          ),
          bottomNavigationBar: cart.isEmpty ? null : const CartBar(),
        );
      },
    );
  }
}

class _PinnedBar extends SliverPersistentHeaderDelegate {
  final Widget child;

  _PinnedBar({required this.child});

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox(height: 52, child: child);

  @override
  bool shouldRebuild(covariant _PinnedBar oldDelegate) => true;
}
