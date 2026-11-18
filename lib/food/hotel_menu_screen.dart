import 'package:flutter/material.dart';

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
    if (k == null || k.currentContext == null) return;
    setState(() => _activeCat = catId);
    Scrollable.ensureVisible(k.currentContext!, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: 0.0);
  }

  Widget _addButton(FoodItem item) {
    if (!item.available) {
      return Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
        child: Text(app.tr('Sold out', 'தீர்ந்தது'), style: ts(12, weight: FontWeight.w700, color: kMuted)),
      );
    }
    final q = cart.qtyOfItem(item.id);
    if (q > 0 && !item.hasVariants) {
      return QtyStepper(
        qty: q,
        compact: true,
        onMinus: () => cart.decItem(item.id),
        onPlus: () => _add(item),
      );
    }
    return GestureDetector(
      onTap: () => _add(item),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBrand, width: 1.4),
          boxShadow: const [BoxShadow(color: Color(0x1F2A7DE1), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(q > 0 ? '$q ' : '', style: ts(13, weight: FontWeight.w800, color: kBrand)),
          Text(app.tr('ADD', 'சேர்'), style: ts(13.5, weight: FontWeight.w800, color: kBrand)),
          if (item.hasVariants) const Icon(Icons.add_rounded, size: 15, color: kBrand),
        ]),
      ),
    );
  }

  Widget _itemRow(FoodItem item) {
    final dim = !item.available;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                      const Icon(Icons.local_fire_department_rounded, size: 15, color: kAmber),
                      const SizedBox(width: 2),
                      Text(app.tr('Bestseller', 'அதிகம் விற்பனை'), style: ts(11.5, weight: FontWeight.w700, color: kAmber)),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text(item.name, style: ts(16, weight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 3),
                  Text(
                    item.hasVariants ? app.tr('From ${rupee(item.fromPrice)}', '${rupee(item.fromPrice)} முதல்') : rupee(item.price),
                    style: ts(14.5, weight: FontWeight.w700, color: kChipText),
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
            width: 112,
            child: Column(
              children: [
                if (item.picture != null)
                  SizedBox(
                    height: 102,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        FoodPhoto(file: item.picture, width: 112, height: 94, radius: 16, gray: dim),
                        Positioned(bottom: 0, child: _addButton(item)),
                      ],
                    ),
                  )
                else
                  Padding(padding: const EdgeInsets.only(top: 18), child: _addButton(item)),
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
      expandedHeight: 210,
      backgroundColor: kBrandDark,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(6),
        child: CircleAvatar(
          backgroundColor: Colors.black38,
          child: IconButton(padding: EdgeInsets.zero, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            FoodPhoto(file: h.picture, radius: 0, gray: !_canOrder),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.black26, Colors.transparent, Colors.black54], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ],
        ),
      ),
      title: Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, weight: FontWeight.w800, color: Colors.white)),
    );
  }

  Widget _info() {
    final h = _h;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(h.name, style: ts(22, weight: FontWeight.w800, height: 1.2))),
            RatingBadge(rating: h.rating, count: h.ratingCount),
          ]),
          if (h.cuisine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(h.cuisine, style: ts(13.5, color: kMuted)),
          ],
          if (h.address.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.location_on_rounded, size: 15, color: kBrand),
              const SizedBox(width: 4),
              Expanded(child: Text(h.address, style: ts(12.5, color: kMuted, height: 1.3))),
            ]),
          ],
          const SizedBox(height: 14),
          Row(children: [
            _stat(Icons.timer_outlined, '${h.prepMinutes}-${h.prepMinutes + 10}', app.tr('minutes', 'நிமிடம்')),
            _div(),
            _stat(Icons.delivery_dining_rounded, h.canDeliver ? (h.deliveryFee <= 0 ? app.tr('Free', 'இலவசம்') : rupee(h.deliveryFee)) : '—', app.tr('delivery', 'டெலிவரி')),
            _div(),
            _stat(Icons.shopping_basket_outlined, h.minOrder > 0 ? rupee(h.minOrder) : app.tr('None', 'இல்லை'), app.tr('min order', 'குறைந்தபட்சம்')),
          ]),
          if (h.freeAbove != null && h.freeAbove! > 0 && h.canDeliver && h.deliveryFee > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.local_offer_rounded, size: 16, color: kBrand),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.tr('Free delivery on orders above ${rupee(h.freeAbove!)}', '${rupee(h.freeAbove!)}-க்கு மேல் ஆர்டருக்கு இலவச டெலிவரி'),
                    style: ts(12.5, weight: FontWeight.w700, color: kChipText),
                  ),
                ),
              ]),
            ),
          ],
          if (!_canOrder) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB26A00)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _h.openNow
                        ? app.tr('Not taking orders right now. You can still see the menu.', 'இப்போது ஆர்டர் எடுக்கவில்லை. மெனுவை பார்க்கலாம்.')
                        : app.tr('Closed now${_h.openTime != null ? ' · opens ${_h.openTime!.substring(0, 5)}' : ''}. You can still see the menu.',
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

  Widget _div() => Container(width: 1, height: 34, margin: const EdgeInsets.symmetric(horizontal: 10), color: kLine);

  Widget _stat(IconData i, String v, String l) => Expanded(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, size: 16, color: kBrand),
            const SizedBox(width: 4),
            Flexible(child: Text(v, overflow: TextOverflow.ellipsis, style: ts(14.5, weight: FontWeight.w800))),
          ]),
          const SizedBox(height: 2),
          Text(l, style: ts(11.5, color: kMuted)),
        ]),
      );

  Widget _chips(List<FoodCategory> cats) {
    return Container(
      color: kBg,
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _scrollTo(c.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _activeCat == c.id ? kBrand : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _activeCat == c.id ? kBrand : kLine),
                  ),
                  child: Text(c.name, style: ts(13, weight: FontWeight.w700, color: _activeCat == c.id ? Colors.white : kChipText)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _vegSwitch() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 6),
        child: Row(children: [
          const VegDot(veg: true),
          const SizedBox(width: 8),
          Text(app.tr('Veg only', 'சைவம் மட்டும்'), style: ts(13.5, weight: FontWeight.w700)),
          const Spacer(),
          Switch(value: _vegOnly, activeColor: kGreen, onChanged: (v) => setState(() => _vegOnly = v)),
        ]),
      );

  Widget _section(String title, List<FoodItem> items, GlobalKey? key) {
    return Container(
      key: key,
      color: Colors.white,
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text('$title  ·  ${items.length}', style: ts(16, weight: FontWeight.w800, color: kChipText)),
          ),
          for (var i = 0; i < items.length; i++) ...[
            _itemRow(items[i]),
            if (i != items.length - 1) const Divider(height: 1, indent: 16, endIndent: 16, color: kLine),
          ],
        ],
      ),
    );
  }

  List<Widget> _menuBody() {
    final m = _menu;
    if (m == null) {
      if (_error != null) {
        return [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 50, 32, 20),
            child: Column(children: [
              const Icon(Icons.wifi_off_rounded, size: 44, color: kBrandMid),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: ts(14, color: kMuted)),
              TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: Text(app.tr('Try again', 'மீண்டும் முயற்சி'))),
            ]),
          ),
        ];
      }
      return [
        const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator())),
      ];
    }
    final out = <Widget>[];
    final cats = <FoodCategory>[];
    for (final c in m.categories) {
      final its = m.itemsIn(c.id).where((i) => !_vegOnly || i.veg).toList();
      if (its.isEmpty) continue;
      cats.add(c);
      _keys.putIfAbsent(c.id, () => GlobalKey());
      out.add(_section(c.name, its, _keys[c.id]));
    }
    final loose = m.items.where((i) => i.categoryId == null && (!_vegOnly || i.veg)).toList();
    if (loose.isNotEmpty) out.add(_section(app.tr('Others', 'மற்றவை'), loose, null));
    if (out.isEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(32, 50, 32, 20),
        child: Text(app.tr('No items to show.', 'காட்ட பொருட்கள் இல்லை.'), textAlign: TextAlign.center, style: ts(14, color: kMuted)),
      ));
    }
    return [
      if (cats.length > 1) _chips(cats),
      ...out,
    ];
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
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _hero(),
                SliverToBoxAdapter(child: _info()),
                SliverToBoxAdapter(child: _vegSwitch()),
                SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _menuBody())),
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
