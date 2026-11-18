import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
import 'food_cart.dart';
import 'food_models.dart';
import 'food_widgets.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final TextEditingController _note = TextEditingController(text: cart.note);

  @override
  void dispose() {
    cart.note = _note.text;
    _note.dispose();
    super.dispose();
  }

  Widget _topInfo(FoodHotel h) {
    final free = h.freeAbove ?? 0;
    final showBar = cart.fulfil == 'Delivery' && h.canDeliver && h.deliveryFee > 0 && free > 0;
    final reached = showBar && cart.itemsTotal >= free;
    final left = free - cart.itemsTotal;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFE8F2FF), Color(0xFFF6FAFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
            child: const Icon(Icons.schedule_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                cart.fulfil == 'Delivery'
                    ? app.tr('Arrives in ${h.prepMinutes + 10}-${h.prepMinutes + 20} min', '${h.prepMinutes + 10}-${h.prepMinutes + 20} நிமிடத்தில் வரும்')
                    : app.tr('Ready in ${h.prepMinutes}-${h.prepMinutes + 10} min', '${h.prepMinutes}-${h.prepMinutes + 10} நிமிடத்தில் தயார்'),
                style: ts(15, weight: FontWeight.w800, color: kChipText),
              ),
              Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, color: kMuted)),
            ]),
          ),
        ]),
        if (showBar) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (cart.itemsTotal / free).clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(reached ? kGreen : kBrand),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(reached ? Icons.celebration_rounded : Icons.local_offer_rounded, size: 16, color: reached ? kGreen : kBrand),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                reached
                    ? app.tr('Yay! You got FREE delivery', 'சூப்பர்! இலவச டெலிவரி கிடைத்தது')
                    : app.tr('Add ${rupee(left)} more for FREE delivery', 'இலவச டெலிவரிக்கு இன்னும் ${rupee(left)} சேர்க்கவும்'),
                style: ts(12.5, weight: FontWeight.w800, color: reached ? kGreen : kChipText),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _line(CartLine l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        VegDot(veg: l.veg),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: ts(15, weight: FontWeight.w700)),
            if (l.variant.isNotEmpty) Text(l.variant, style: ts(12.5, color: kMuted)),
            const SizedBox(height: 2),
            Text(rupee(l.price), style: ts(12.5, color: kMuted)),
          ]),
        ),
        QtyStepper(qty: l.qty, compact: true, onMinus: () => cart.dec(l), onPlus: () => cart.inc(l)),
        SizedBox(width: 62, child: Text(rupee(l.total), textAlign: TextAlign.right, style: ts(14.5, weight: FontWeight.w800))),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x112A7DE1), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: child,
      );

  Widget _choice(String value, IconData icon, String label, String sub) {
    final on = cart.fulfil == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => cart.setFulfil(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? kTint : kBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? kBrand : Colors.transparent, width: 1.5),
          ),
          child: Column(children: [
            Icon(icon, color: on ? kBrand : kMuted, size: 26),
            const SizedBox(height: 6),
            Text(label, style: ts(13.5, weight: FontWeight.w800, color: on ? kBrandDark : kInk)),
            const SizedBox(height: 2),
            Text(sub, style: ts(11.5, color: kMuted)),
          ]),
        ),
      ),
    );
  }

  Widget _billRow(String l, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(l, style: ts(bold ? 16 : 14, weight: bold ? FontWeight.w800 : FontWeight.w500, color: bold ? kInk : kMuted))),
          Text(v, style: ts(bold ? 17 : 14, weight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? kInk)),
        ]),
      );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag_outlined, size: 44, color: kBrand),
            ),
            const SizedBox(height: 16),
            Text(app.tr('Your cart is empty', 'உங்கள் கார்ட் காலி'), style: ts(18, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(app.tr('Add some tasty food from a hotel.', 'ஹோட்டலில் இருந்து சுவையான உணவை சேர்க்கவும்.'), style: ts(13.5, color: kMuted)),
            const SizedBox(height: 18),
            TextButton(onPressed: () => Navigator.pop(context), child: Text(app.tr('Browse hotels', 'ஹோட்டல்களை பார்க்க'))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cart, app]),
      builder: (context, _) {
        final h = cart.hotel;
        final empty = cart.isEmpty || h == null;
        final hh = h;
        final belowMin = hh != null && !cart.isEmpty && hh.minOrder > 0 && cart.itemsTotal < hh.minOrder;
        return Scaffold(
          backgroundColor: kBg,
          body: Column(children: [
            AppHeader(
              bubbles: false,
              radius: 24,
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 14),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.tr('Your cart', 'உங்கள் கார்ட்'), style: ts(20, weight: FontWeight.w800, color: Colors.white)),
                    if (hh != null) Text(hh.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, color: kOnBrandSoft)),
                  ]),
                ),
                if (!empty)
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(app.tr('Clear cart?', 'கார்ட்டை காலி செய்யவா?'), style: ts(17, weight: FontWeight.w800)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(app.tr('No', 'வேண்டாம்'))),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(app.tr('Clear', 'காலி செய்'))),
                          ],
                        ),
                      );
                      if (ok == true) cart.clear();
                    },
                    child: Text(app.tr('Clear', 'காலி'), style: ts(13.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
              ]),
            ),
            Expanded(
              child: empty
                  ? _empty()
                  : ListView(
                      padding: const EdgeInsets.only(top: 16, bottom: 24),
                      children: [
                        if (hh != null) _topInfo(hh),
                        _card(Column(children: [
                          for (var i = 0; i < cart.lines.length; i++) ...[
                            _line(cart.lines[i]),
                            if (i != cart.lines.length - 1) const Divider(height: 1, color: kLine),
                          ],
                        ])),
                        if (hh != null && hh.canDeliver && hh.canPickup)
                          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(app.tr('How do you want it?', 'எப்படி வேண்டும்?'), style: ts(15, weight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            Row(children: [
                              _choice('Delivery', Icons.delivery_dining_rounded, app.tr('Delivery', 'டெலிவரி'), app.tr('To your door', 'வீட்டுக்கு')),
                              const SizedBox(width: 10),
                              _choice('Pickup', Icons.storefront_rounded, app.tr('Pickup', 'நேரில்'), app.tr('Collect yourself', 'நீங்களே எடுக்க')),
                            ]),
                          ])),
                        _card(TextField(
                          controller: _note,
                          maxLines: 2,
                          maxLength: 150,
                          style: ts(14),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            counterText: '',
                            icon: const Icon(Icons.edit_note_rounded, color: kBrand),
                            hintText: app.tr('Cooking note (less spicy, no onion…)', 'சமையல் குறிப்பு (காரம் குறைவு, வெங்காயம் வேண்டாம்…)'),
                            hintStyle: ts(13.5, color: kMuted),
                          ),
                        )),
                        _card(Column(children: [
                          _billRow(app.tr('Item total', 'பொருட்கள் மொத்தம்'), rupee(cart.itemsTotal)),
                          if (cart.fulfil == 'Delivery')
                            _billRow(app.tr('Delivery fee', 'டெலிவரி கட்டணம்'), cart.deliveryFee <= 0 ? app.tr('FREE', 'இலவசம்') : rupee(cart.deliveryFee),
                                color: cart.deliveryFee <= 0 ? kGreen : null),
                          if (cart.packing > 0) _billRow(app.tr('Packing charge', 'பேக்கிங் கட்டணம்'), rupee(cart.packing)),
                          const Divider(height: 18, color: kLine),
                          _billRow(app.tr('To pay', 'செலுத்த வேண்டியது'), rupee(cart.grandTotal), bold: true),
                        ])),
                        if (belowMin && hh != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Row(children: [
                              const Icon(Icons.info_outline_rounded, size: 17, color: kRed),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  app.tr('Minimum order is ${rupee(hh!.minOrder)}. Add ${rupee(hh!.minOrder - cart.itemsTotal)} more.',
                                      'குறைந்தபட்ச ஆர்டர் ${rupee(hh!.minOrder)}. இன்னும் ${rupee(hh!.minOrder - cart.itemsTotal)} சேர்க்கவும்.'),
                                  style: ts(12.5, weight: FontWeight.w600, color: kRed),
                                ),
                              ),
                            ]),
                          ),
                      ],
                    ),
            ),
          ]),
          bottomNavigationBar: empty
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: GradButton(
                      label: '${app.tr('Place order', 'ஆர்டர் செய்')} · ${rupee(cart.grandTotal)}',
                      icon: Icons.check_circle_rounded,
                      onTap: belowMin
                          ? null
                          : () {
                              cart.note = _note.text;
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(SnackBar(
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(app.tr('Ordering opens in the next update. Your cart is saved.', 'ஆர்டர் செய்யும் வசதி அடுத்த update-ல் வரும். உங்கள் கார்ட் சேமிக்கப்பட்டுள்ளது.')),
                                ));
                            },
                    ),
                  ),
                ),
        );
      },
    );
  }
}
