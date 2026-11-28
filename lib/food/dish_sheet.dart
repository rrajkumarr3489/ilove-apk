import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'food_cart.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';

/// Shared by Home and the hotel menu: checks the hotel is open. Dishes of other hotels stay in the bag. true = go ahead.
Future<bool> foodPrepareAdd(BuildContext context, FoodHotel h) async {
  void msg(String t) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
  if (!(h.openNow && h.acceptsOrders)) {
    msg(h.openNow ? app.tr('This hotel is not taking orders now.', 'இந்த ஹோட்டல் இப்போது ஆர்டர் எடுக்கவில்லை.') : app.tr('This hotel is closed now.', 'இந்த ஹோட்டல் இப்போது மூடப்பட்டுள்ளது.'));
    return false;
  }
  return true;
}

/// Adds a dish on the SAME page: straight into the bag when there is nothing to choose,
/// otherwise the customize sheet opens over the current page. Never opens another screen.
Future<void> foodQuickAdd(BuildContext context, FoodHotel h, FoodItem item, {List<FoodSpice> spices = const <FoodSpice>[]}) async {
  if (!item.available) return;
  if (item.hasVariants) {
    await showDishSheet(context, h, item, spices: spices);
    return;
  }
  if (!await foodPrepareAdd(context, h)) return;
  cart.add(h, item, null);
}

/// "Customize portion & taste" sheet: portion (Half / Full), spice, extras, cooking instructions, quantity.
Future<void> showDishSheet(BuildContext context, FoodHotel h, FoodItem item, {List<FoodSpice> spices = const <FoodSpice>[]}) {
  FoodVariant? sel;
  for (final v in item.variants) {
    if (v.available) {
      sel = v;
      break;
    }
  }
  final sp = item.hasSpice ? spices : const <FoodSpice>[];
  FoodSpice? spice;
  if (sp.isNotEmpty) {
    final def = food.cfg('Food.DefaultSpice', '').toLowerCase();
    spice = sp.first;
    for (final x in sp) {
      if (x.nameEn.toLowerCase() == def) spice = x;
    }
  }
  final picked = <int>{};
  final noteC = TextEditingController();
  var qty = 1;
  final canOrder = h.openNow && h.acceptsOrders;
  Widget title(String t, {Widget? tail}) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Row(children: [
          Expanded(child: Text(t, style: ts(15.5, weight: FontWeight.w800))),
          if (tail != null) tail,
        ]),
      );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) {
        final extras = [for (final a in item.addOns) if (picked.contains(a.id)) a];
        final unit = (sel?.price ?? item.price) + extras.fold<double>(0, (t, a) => t + a.price);
        final can = item.available && canOrder && (!item.hasVariants || sel != null);
        final base = item.variants.isEmpty ? 0.0 : item.variants.first.price;
        return foodScale(
          c,
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.92),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Row(children: [
                        FoodPhoto(file: item.picture, width: 62, height: 62, radius: 16),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(app.tr('CUSTOMIZE PORTION & TASTE', 'அளவு & சுவையை தேர்வு செய்'), style: ts(11, weight: FontWeight.w800, color: kBrand)),
                            const SizedBox(height: 3),
                            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(18, weight: FontWeight.w800, height: 1.2)),
                            Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, color: kMuted)),
                          ]),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(c),
                          child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 20, color: kInk)),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: kLine),
                      if (item.hasVariants) ...[
                        title(app.tr('Portion Size', 'அளவு'), tail: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(12)), child: Text(app.tr('Required', 'அவசியம்'), style: ts(11.5, weight: FontWeight.w800, color: kBrand)))),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          for (final v in item.variants)
                            GestureDetector(
                              onTap: v.available ? () => setS(() => sel = v) : null,
                              child: Container(
                                width: (MediaQuery.of(c).size.width - 40 - 10) / 2,
                                padding: const EdgeInsets.all(13),
                                decoration: BoxDecoration(
                                  color: sel?.id == v.id ? kTintSoft : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: sel?.id == v.id ? kBrand : kLine, width: sel?.id == v.id ? 2 : 1),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(v.name, style: ts(14.5, weight: FontWeight.w800, color: v.available ? kInk : kMuted)),
                                  const SizedBox(height: 2),
                                  Text(v.price > base ? '+${rupee(v.price - base)}' : app.tr('Regular portion', 'வழக்கமான அளவு'), style: ts(11.5, color: kMuted)),
                                  const SizedBox(height: 6),
                                  Text(v.available ? rupee(v.price) : app.tr('Sold out', 'தீர்ந்தது'), style: ts(15, weight: FontWeight.w800, color: v.available ? kBrand : kMuted)),
                                ]),
                              ),
                            ),
                        ]),
                      ],
                      if (sp.isNotEmpty) ...[
                        title(app.tr('Spice Level', 'காரம் அளவு')),
                        Row(children: [
                          for (var i = 0; i < sp.length; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setS(() => spice = sp[i]),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: spice == sp[i] ? kTintSoft : Colors.white,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(color: spice == sp[i] ? kBrand : kLine, width: spice == sp[i] ? 1.6 : 1),
                                  ),
                                  child: Text(sp[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13.5, weight: FontWeight.w800, color: spice == sp[i] ? kBrand : kInk)),
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ],
                      if (item.addOns.isNotEmpty) ...[
                        title(app.tr('Add-ons & Extras', 'கூடுதல் பொருட்கள்')),
                        for (final a in item.addOns)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => setS(() {
                              if (!picked.add(a.id)) picked.remove(a.id);
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(color: kTintSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: picked.contains(a.id) ? kBrand : kLine)),
                              child: Row(children: [
                                Icon(picked.contains(a.id) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: picked.contains(a.id) ? kBrand : kMuted, size: 24),
                                const SizedBox(width: 12),
                                Expanded(child: Text(a.name, style: ts(14.5, weight: FontWeight.w600))),
                                Text('+${rupee(a.price)}', style: ts(14, weight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                      ],
                      title(app.tr('Cooking Instructions', 'சமையல் குறிப்பு')),
                      TextField(
                        controller: noteC,
                        maxLength: 80,
                        style: ts(14),
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          hintText: app.tr('e.g., Less spicy, extra sambar...', 'எ.கா., காரம் குறைவு, கூடுதல் சாம்பார்...'),
                          hintStyle: ts(13.5, color: kMuted),
                          filled: true,
                          fillColor: kTintSoft,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kLine)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBrand)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                ),
                const Divider(height: 1, color: kLine),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 14 + MediaQuery.of(c).padding.bottom),
                  child: Row(children: [
                    QtyStepper(
                      qty: qty,
                      onMinus: () => setS(() {
                        if (qty > 1) qty--;
                      }),
                      onPlus: () => setS(() {
                        if (qty < cart.maxQty) qty++;
                      }),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: !can
                            ? null
                            : () async {
                                Navigator.pop(c);
                                if (!await foodPrepareAdd(context, h)) return;
                                cart.add(h, item, sel, spice: spice, addOns: extras, note: noteC.text, qty: qty);
                              },
                        child: Container(
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: can ? kBrand : kLine, borderRadius: BorderRadius.circular(16)),
                          child: Text(
                            !item.available ? app.tr('Sold out', 'தீர்ந்தது') : (!canOrder ? app.tr('Not taking orders', 'ஆர்டர் இல்லை') : '${app.tr('Add Item', 'சேர்')}  •  ${rupee(unit * qty)}'),
                            style: ts(15.5, weight: FontWeight.w800, color: can ? Colors.white : kMuted),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    ),
  ).whenComplete(noteC.dispose);
}
