import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../app_state.dart';
import '../auth/auth_guard.dart';
import '../auth/auth_service.dart';
import '../bus/bus_api.dart';
import '../theme.dart';
import 'food_cart.dart';
import 'food_home_screen.dart';
import 'food_models.dart';
import 'food_repo.dart';
import 'food_widgets.dart';
import 'hotel_menu_screen.dart';

const Color _kPage = Color(0xFFF8FAFD);

double _n(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
String _s(dynamic v) => v == null ? '' : v.toString();

/// The money of ONE hotel's order (server quote, or a local estimate while the quote is not there yet).
class _HotelBill {
  final FoodHotel hotel;
  double items = 0;
  double packing = 0;
  double delivery = 0;
  double platform = 0;
  double discount = 0;
  double tip = 0;
  double total = 0;
  String coupon = '';
  String? problem;
  int nudgeNeed = 0;
  double nudgeSave = 0;
  String nudgeCode = '';
  _HotelBill(this.hotel);
}

/// The bag: one card per hotel (each becomes its own order), the bill, the payment (UPI / Card / Net Banking) and Pay.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // payment
  late String _tab;
  Razorpay? _rzp;
  String? _rzpErr;

  // bag options
  int _tip = 0;
  String _slot = 'ASAP';
  final TextEditingController _note = TextEditingController(text: cart.note);

  // address
  List<Map<String, dynamic>> _addrs = <Map<String, dynamic>>[];
  int? _addrId;
  bool _addrLoaded = false;

  // server price
  Map<String, dynamic>? _quote;
  String? _quoteErr;
  Timer? _qTimer;
  int _qToken = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tip = int.tryParse(food.cfg('Food.DefaultTip', '0')) ?? 0;
    final upiOn = food.flag('Food.UpiEnabled', true);
    _tab = upiOn ? 'upi' : (food.flag('Food.CodEnabled', true) ? 'cod' : 'card');
    cart.addListener(_onCart);
    if (auth.loggedIn) _loadAddresses();
    _scheduleQuote();
  }

  @override
  void dispose() {
    cart.removeListener(_onCart);
    _qTimer?.cancel();
    cart.note = _note.text;
    _rzp?.clear();
    _note.dispose();
    super.dispose();
  }

  void _onCart() => _scheduleQuote();

  // ---------- server quote ----------
  Map<String, dynamic> _bagBody({String? payMethod, String? payRef}) => <String, dynamic>{
        'fulfil': cart.fulfil,
        'items': [
          for (final l in cart.lines)
            <String, dynamic>{
              'itemId': l.itemId,
              if (l.variantId != null) 'variantId': l.variantId,
              'qty': l.qty,
              if ((l.spiceEn ?? '').isNotEmpty) 'spice': l.spiceEn,
              if (l.itemNote.isNotEmpty) 'note': l.itemNote,
              if (l.addOns.isNotEmpty) 'addOnIds': [for (final a in l.addOns) a.id],
            },
        ],
        'tip': cart.fulfil == 'Delivery' ? _tip : 0,
        'couponCode': '',
        if (payMethod != null) 'paymentMethod': payMethod,
        if (payRef != null) 'paymentRef': payRef,
      };

  void _scheduleQuote() {
    _qTimer?.cancel();
    if (cart.isEmpty || !auth.loggedIn) {
      if (_quote != null) {
        if (mounted) {
          setState(() => _quote = null);
        } else {
          _quote = null;
        }
      }
      return;
    }
    _qTimer = Timer(const Duration(milliseconds: 350), _fetchQuote);
  }

  Future<void> _fetchQuote() async {
    if (cart.isEmpty || !auth.loggedIn) return;
    final my = ++_qToken;
    try {
      final r = await BusApi.post('/food/quote', _bagBody());
      if (!mounted || my != _qToken) return;
      setState(() {
        _quote = (r is Map) ? Map<String, dynamic>.from(r) : null;
        _quoteErr = null;
      });
    } catch (e) {
      if (!mounted || my != _qToken) return;
      setState(() {
        _quote = null;
        _quoteErr = BusApi.friendly(e);
      });
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final r = await BusApi.get('/food/addresses');
      final list = <Map<String, dynamic>>[];
      if (r is List) {
        for (final e in r) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
      }
      if (!mounted) return;
      setState(() {
        _addrs = list;
        _addrLoaded = true;
        if (_addrId == null || !list.any((a) => a['addressId'] == _addrId)) {
          Map<String, dynamic>? pick;
          for (final a in list) {
            if (a['isDefault'] == true) pick = a;
          }
          pick ??= list.isEmpty ? null : list.first;
          _addrId = pick == null ? null : (pick['addressId'] as num).toInt();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _addrLoaded = true);
    }
  }

  // ---------- numbers ----------
  List<_HotelBill> _bills() {
    final out = <_HotelBill>[];
    final q = _quote;
    final qh = q == null ? const <dynamic>[] : (q['hotels'] is List ? q['hotels'] as List : const <dynamic>[]);
    final hs = cart.hotels;
    for (var i = 0; i < hs.length; i++) {
      final h = hs[i];
      final b = _HotelBill(h);
      Map? row;
      for (final r in qh) {
        if (r is Map && _n(r['hotelId']).toInt() == h.id) row = r;
      }
      if (row != null) {
        b.items = _n(row['itemsTotal']);
        b.packing = _n(row['packingCharge']);
        b.delivery = _n(row['deliveryFee']);
        b.platform = _n(row['platformFee']);
        b.discount = _n(row['discount']);
        b.tip = _n(row['tip']);
        b.total = _n(row['total']);
        b.coupon = _s(row['couponCode']);
        b.problem = _s(row['problem']).isEmpty ? null : _s(row['problem']);
        b.nudgeNeed = _n(row['nudgeNeed']).toInt();
        b.nudgeSave = _n(row['nudgeSave']);
        b.nudgeCode = _s(row['nudgeCode']);
      } else {
        final del = cart.fulfil == 'Delivery';
        b.items = cart.totalOf(h.id);
        b.delivery = cart.deliveryFeeOf(h);
        b.packing = del ? h.packing : 0;
        b.platform = double.tryParse(food.cfg(del ? 'Food.PlatformFee' : 'Food.PlatformFeePickup', '0')) ?? 0;
        b.tip = (del && i == 0) ? _tip.toDouble() : 0;
        b.total = b.items + b.delivery + b.packing + b.platform + b.tip;
        if (h.minOrder > 0 && b.items < h.minOrder) {
          b.problem = app.tr('Minimum order is ${rupee(h.minOrder)}. Add ${rupee(h.minOrder - b.items)} more.', 'குறைந்தபட்ச ஆர்டர் ${rupee(h.minOrder)}. இன்னும் ${rupee(h.minOrder - b.items)} சேர்க்கவும்.');
        }
      }
      out.add(b);
    }
    return out;
  }

  String _payMethodLabel() {
    switch (_tab) {
      case 'upi':
        return 'UPI';
      case 'card':
        return app.tr('Card', 'கார்டு');
      case 'nb':
        return app.tr('Net Banking', 'நெட் பேங்கிங்');
      default:
        return app.tr('Cash on Delivery', 'கையில் பணம்');
    }
  }

  // ---------- helpers ----------
  void _msg(String t) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating));
  }

  Widget _box({required Widget child, EdgeInsets? padding, Color? color, Color? border, double radius = 22, EdgeInsets? margin}) => Container(
        margin: margin ?? const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border ?? kLine), boxShadow: color == null ? kSoftShadow : null),
        child: child,
      );

  Widget _row(String l, String v, {bool bold = false, Color? color, bool strike = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.5),
        child: Row(children: [
          Expanded(child: Text(l, style: ts(bold ? 14.5 : 12.5, weight: bold ? FontWeight.w800 : FontWeight.w500, color: color ?? (bold ? kInk : kMuted)))),
          Text(v, style: ts(bold ? 15 : 12.5, weight: bold ? FontWeight.w800 : FontWeight.w700, color: color ?? kInk)),
        ]),
      );

  // ---------- top ----------
  Widget _top() {
    final hs = cart.hotels;
    final del = cart.fulfil == 'Delivery';
    var eta = 0;
    for (final h in hs) {
      final e = del ? h.shownEta : h.prepMinutes;
      if (e > eta) eta = e;
    }
    return Container(
      padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: kLine))),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: kLine), boxShadow: kSoftShadow), child: const Icon(Icons.arrow_back_rounded, size: 19, color: kInk)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.tr('Your Bag', 'உங்கள் பை'), style: ts(16, weight: FontWeight.w800)),
            if (hs.isNotEmpty)
              Text(del ? app.tr('🛵 Express delivery in $eta mins', '🛵 $eta நிமிடத்தில் டெலிவரி') : app.tr('🛍️ Ready for pickup in $eta mins', '🛍️ $eta நிமிடத்தில் தயார்'), style: ts(11, weight: FontWeight.w600, color: kBrand)),
          ]),
        ),
        if (!cart.isEmpty)
          GestureDetector(
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text(app.tr('Clear the bag?', 'பையை காலி செய்யவா?'), style: ts(17, weight: FontWeight.w700)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(app.tr('No', 'வேண்டாம்'))),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: Text(app.tr('Clear', 'காலி செய்'))),
                  ],
                ),
              );
              if (ok == true) cart.clear();
            },
            child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle), child: const Icon(Icons.delete_outline_rounded, size: 18, color: kRed)),
          ),
      ]),
    );
  }

  Widget _modeToggle() {
    final hs = cart.hotels;
    final canDel = hs.every((h) => h.canDeliver);
    final canPick = hs.every((h) => h.canPickup);
    Widget btn(String v, String emoji, String label, bool enabled) {
      final on = cart.fulfil == v;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (!enabled) {
              _msg(v == 'Pickup' ? app.tr('A hotel in your bag does not offer self-pickup.', 'பையில் உள்ள ஒரு ஹோட்டலில் நேரில் எடுக்கும் வசதி இல்லை.') : app.tr('A hotel in your bag does not deliver.', 'பையில் உள்ள ஒரு ஹோட்டல் டெலிவரி செய்வதில்லை.'));
              return;
            }
            cart.setFulfil(v);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: on ? kBrand : Colors.transparent, borderRadius: BorderRadius.circular(14), boxShadow: on ? const [BoxShadow(color: kBrandShadow, blurRadius: 10, offset: Offset(0, 4))] : null),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, weight: FontWeight.w800, color: on ? Colors.white : (enabled ? kInk : kMuted)))),
            ]),
          ),
        ),
      );
    }

    final save = hs.fold<double>(0, (s, h) => s + h.deliveryFee);
    return _box(
      padding: const EdgeInsets.all(4),
      color: kTint,
      border: kBrandMid,
      radius: 20,
      child: Row(children: [
        btn('Delivery', '🛵', app.tr('Home Delivery', 'டெலிவரி'), canDel),
        btn('Pickup', '🛍️', save > 0 ? app.tr('Self-Pickup (Save ${rupee(save)})', 'நேரில் (சேமிப்பு ${rupee(save)})') : app.tr('Self-Pickup', 'நேரில் எடுக்க'), canPick),
      ]),
    );
  }

  // ---------- hotel-wise order card ----------
  Widget _lineRow(CartLine l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: VegDot(veg: l.veg, size: 14)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: ts(13.5, weight: FontWeight.w800, height: 1.25)),
            if (l.variant.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(l.variant, style: ts(11, color: kMuted, height: 1.3))),
            if (l.itemNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('“${l.itemNote}”', style: ts(11, color: kMuted).copyWith(fontStyle: FontStyle.italic))),
            const SizedBox(height: 3),
            Text(rupee(l.price), style: ts(11.5, color: kMuted)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          QtyStepper(qty: l.qty, compact: true, onMinus: () => cart.dec(l), onPlus: () => cart.inc(l)),
          const SizedBox(height: 4),
          Text(rupee(l.total), style: ts(13, weight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget _hotelCard(_HotelBill b, int index, int total) {
    final h = b.hotel;
    final lines = cart.linesOf(h.id);
    final del = cart.fulfil == 'Delivery';
    final fee = b.packing + b.platform;
    return _box(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: const BoxDecoration(color: kTintSoft, borderRadius: BorderRadius.vertical(top: Radius.circular(22)), border: Border(bottom: BorderSide(color: kLine))),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 42, height: 42, child: Container(color: kTint, child: NetImg(file: h.picture, cacheWidth: 140)))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (total > 1) Text(app.tr('ORDER ${index + 1} OF $total', 'ஆர்டர் ${index + 1} / $total'), style: ts(9.5, weight: FontWeight.w800, color: kBrand)),
                Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14.5, weight: FontWeight.w800)),
                Text(del ? '🛵 ${app.tr('${h.shownEta} mins', '${h.shownEta} நிமிடம்')}${h.area != null ? ' • ${h.area}' : ''}' : '🛍️ ${app.tr('Ready in ${h.prepMinutes} mins', '${h.prepMinutes} நிமிடத்தில் தயார்')}', style: ts(11, weight: FontWeight.w600, color: kBrand)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Column(children: [
            for (var i = 0; i < lines.length; i++) ...[
              _lineRow(lines[i]),
              if (i != lines.length - 1) const Divider(height: 1, color: kTintSoft),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          child: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => HotelMenuScreen(hotel: h))),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrandMid)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, size: 15, color: kBrand),
                const SizedBox(width: 5),
                Text(app.tr('Add more items', 'மேலும் சேர்க்க'), style: ts(12, weight: FontWeight.w800, color: kBrand)),
              ]),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _kPage, borderRadius: BorderRadius.circular(16), border: Border.all(color: kTintSoft)),
          child: Column(children: [
            _row(app.tr('Item Total', 'பொருட்கள் மொத்தம்'), rupee(b.items)),
            if (del) _row(app.tr('Delivery Fee', 'டெலிவரி கட்டணம்'), b.delivery <= 0 ? app.tr('FREE', 'இலவசம்') : rupee(b.delivery), color: b.delivery <= 0 ? kGreen : null),
            if (fee > 0) _row(app.tr('Packaging & Platform Fee', 'பேக்கிங் & தளக் கட்டணம்'), rupee(fee)),
            if (b.tip > 0) _row(app.tr('Rider Tip', 'ரைடர் டிப்'), rupee(b.tip)),
            if (b.discount > 0) _row(app.tr('Promo Discount (${b.coupon})', 'சலுகை (${b.coupon})'), '-${rupee(b.discount)}', color: kGreen),
            const Divider(height: 14, color: kLine),
            _row(app.tr('Order Total', 'ஆர்டர் மொத்தம்'), rupee(b.total), bold: true),
            if (b.problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: kRed),
                  const SizedBox(width: 6),
                  Expanded(child: Text(b.problem!, style: ts(11.5, weight: FontWeight.w600, color: kRed))),
                ]),
              )
            else if (b.nudgeNeed > 0 && b.nudgeSave > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(app.tr('Add ₹${b.nudgeNeed} more to save ${rupee(b.nudgeSave)}${b.nudgeCode.isEmpty ? '' : ' (${b.nudgeCode})'}', '₹${b.nudgeNeed} சேர்த்தால் ${rupee(b.nudgeSave)} சேமிக்கலாம்${b.nudgeCode.isEmpty ? '' : ' (${b.nudgeCode})'}'), style: ts(11.5, weight: FontWeight.w700, color: kBrand)),
              ),
          ]),
        ),
      ]),
    );
  }

  // ---------- coupon / address / pickup / tip ----------
  Widget _couponCard(List<_HotelBill> bills) {
    final saved = bills.fold<double>(0, (s, b) => s + b.discount);
    if (saved <= 0) return const SizedBox.shrink();
    final codes = bills.where((b) => b.discount > 0).map((b) => b.coupon).toSet().join(', ');
    return _box(
      padding: const EdgeInsets.all(11),
      color: kTint,
      border: kBrandMid,
      radius: 18,
      child: Row(children: [
        Container(width: 30, height: 30, decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.local_offer_rounded, size: 15, color: Colors.white)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.tr('$codes Applied!', '$codes சேர்ந்தது!'), style: ts(12.5, weight: FontWeight.w800)),
            Text(app.tr('You saved ${rupee(saved)} on this order', 'இந்த ஆர்டரில் ${rupee(saved)} சேமித்தீர்கள்'), style: ts(10.5, weight: FontWeight.w600, color: kBrand)),
          ]),
        ),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBrandMid)), child: Text(app.tr('Auto-Saved', 'தானாக'), style: ts(10, weight: FontWeight.w800, color: kBrand))),
      ]),
    );
  }

  Map<String, dynamic>? get _addr {
    for (final a in _addrs) {
      if (a['addressId'] == _addrId) return a;
    }
    return null;
  }

  Widget _addressCard() {
    final a = _addr;
    return GestureDetector(
      onTap: () async {
        if (!await requireLogin(context, whyEn: 'Please login to choose your delivery address.', whyTa: 'டெலிவரி முகவரியை தேர்வு செய்ய உள்நுழையவும்.')) return;
        if (!mounted) return;
        if (!_addrLoaded) await _loadAddresses();
        if (mounted) _addressSheet();
      },
      child: _box(
        padding: const EdgeInsets.all(12),
        color: kTintSoft,
        border: kLine,
        radius: 18,
        child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.location_on_rounded, size: 17, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(
            child: a == null
                ? Text(app.tr('Add delivery address', 'டெலிவரி முகவரியை சேர்க்கவும்'), style: ts(13, weight: FontWeight.w800, color: kBrand))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.tr('Delivering to ${_s(a['label']).isEmpty ? 'Home' : _s(a['label'])}', '${_s(a['label']).isEmpty ? 'வீடு' : _s(a['label'])} முகவரிக்கு'), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, weight: FontWeight.w800)),
                    Text(_s(a['addressLine']), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(10.5, color: kMuted)),
                  ]),
          ),
          Text(app.tr('Change', 'மாற்று'), style: ts(11, weight: FontWeight.w800, color: kBrand)),
        ]),
      ),
    );
  }

  void _addressSheet() {
    final label = TextEditingController(text: 'Home');
    final name = TextEditingController();
    final phone = TextEditingController();
    final line = TextEditingController();
    final land = TextEditingController();
    var adding = _addrs.isEmpty;
    var saving = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        Widget field(TextEditingController ctl, String hint, {TextInputType? type, int lines = 1}) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: ctl,
                keyboardType: type,
                maxLines: lines,
                style: ts(14),
                decoration: InputDecoration(isDense: true, hintText: hint, hintStyle: ts(13, color: kMuted), filled: true, fillColor: kTintSoft, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine))),
              ),
            );
        return foodScale(
          c,
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.9),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(adding ? app.tr('New address', 'புதிய முகவரி') : app.tr('Deliver to', 'டெலிவரி முகவரி'), style: ts(17, weight: FontWeight.w800))),
                    GestureDetector(onTap: () => Navigator.pop(c), child: Container(width: 34, height: 34, decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 18))),
                  ]),
                  const SizedBox(height: 14),
                  if (!adding) ...[
                    for (final a in _addrs)
                      GestureDetector(
                        onTap: () {
                          setState(() => _addrId = (a['addressId'] as num).toInt());
                          Navigator.pop(c);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: a['addressId'] == _addrId ? kTintSoft : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: a['addressId'] == _addrId ? kBrand : kLine, width: a['addressId'] == _addrId ? 1.6 : 1)),
                          child: Row(children: [
                            Icon(a['addressId'] == _addrId ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: kBrand, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_s(a['label']).isEmpty ? app.tr('Address', 'முகவரி') : _s(a['label']), style: ts(13.5, weight: FontWeight.w800)), Text(_s(a['addressLine']), maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(11.5, color: kMuted))])),
                          ]),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => setS(() => adding = true),
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 12), alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrandMid)), child: Text('+ ${app.tr('Add new address', 'புதிய முகவரி சேர்')}', style: ts(12.5, weight: FontWeight.w800, color: kBrand))),
                    ),
                  ] else ...[
                    field(label, app.tr('Label (Home / Work)', 'பெயர் (வீடு / அலுவலகம்)')),
                    field(name, app.tr('Contact name', 'பெயர்')),
                    field(phone, app.tr('Contact phone', 'தொலைபேசி'), type: TextInputType.phone),
                    field(line, app.tr('Door no, street, area', 'கதவு எண், தெரு, பகுதி'), lines: 2),
                    field(land, app.tr('Landmark (optional)', 'அடையாளம் (விருப்பம்)')),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: saving
                          ? null
                          : () async {
                              if (line.text.trim().length < 5) {
                                _msg(app.tr('Please type the full address.', 'முழு முகவரியை எழுதவும்.'));
                                return;
                              }
                              setS(() => saving = true);
                              try {
                                final r = await BusApi.post('/food/addresses', <String, dynamic>{
                                  'label': label.text.trim(),
                                  'contactName': name.text.trim(),
                                  'contactPhone': phone.text.trim(),
                                  'addressLine': line.text.trim(),
                                  'landmark': land.text.trim(),
                                  'isDefault': _addrs.isEmpty,
                                });
                                if (r is Map && r['addressId'] != null) _addrId = _n(r['addressId']).toInt();
                                await _loadAddresses();
                                if (c.mounted) Navigator.pop(c);
                              } catch (e) {
                                setS(() => saving = false);
                                _msg(BusApi.friendly(e));
                              }
                            },
                      child: Container(height: 50, alignment: Alignment.center, decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(16)), child: Text(saving ? '...' : app.tr('Save address', 'முகவரியை சேமி'), style: ts(15, weight: FontWeight.w800, color: Colors.white))),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }

  List<List<String>> _slots() {
    final raw = food.cfg('Food.PickupSlots', 'ASAP|உடனே,In 30 mins|30 நிமிடத்தில்');
    final out = <List<String>>[];
    for (final p in raw.split(',')) {
      final x = p.split('|');
      final en = x[0].trim();
      if (en.isEmpty) continue;
      out.add([en, x.length > 1 && x[1].trim().isNotEmpty ? x[1].trim() : en]);
    }
    return out;
  }

  Widget _pickupCard() {
    final hs = cart.hotels;
    final slots = _slots();
    if (!slots.any((s) => s[0] == _slot) && slots.isNotEmpty) _slot = slots.first[0];
    return _box(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFEAF6EE),
      border: const Color(0xFFB7E1C1),
      radius: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final h in hs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: kGreen, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.storefront_rounded, size: 17, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, weight: FontWeight.w800)),
                  if (h.address.isNotEmpty) Text(h.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(10.5, color: kMuted)),
                  Text('⏱️ ${app.tr('Ready in ${h.prepMinutes} mins', '${h.prepMinutes} நிமிடத்தில் தயார்')}${h.distanceKm != null ? ' • ${h.distanceKm!.toStringAsFixed(1)} km' : ''}', style: ts(10.5, weight: FontWeight.w700, color: kGreen)),
                ]),
              ),
              GestureDetector(
                onTap: () => _msg(app.tr('Map directions will open here in a coming update.', 'வரைபட வழி விரைவில் வரும்.')),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFB7E1C1))), child: Text(app.tr('Get Directions', 'வழி'), style: ts(10, weight: FontWeight.w800, color: kGreen))),
              ),
            ]),
          ),
        const Divider(height: 10, color: Color(0xFFB7E1C1)),
        Row(children: [
          Text(app.tr('Pickup Slot:', 'எடுக்கும் நேரம்:'), style: ts(11, weight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 28,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final s in slots)
                  GestureDetector(
                    onTap: () => setState(() => _slot = s[0]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _slot == s[0] ? kGreen : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB7E1C1))),
                      child: Text(app.lang == 'ta' ? s[1] : s[0], style: ts(10.5, weight: FontWeight.w800, color: _slot == s[0] ? Colors.white : kInk)),
                    ),
                  ),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _tipBox() {
    final opts = food.cfg('Food.TipOptions', '0,10,20,30').split(',').map((e) => int.tryParse(e.trim())).whereType<int>().toList();
    if (opts.isEmpty) return const SizedBox.shrink();
    return _box(
      padding: const EdgeInsets.all(12),
      radius: 18,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(app.tr('Tip your Rider', 'ரைடருக்கு டிப்'), style: ts(12.5, weight: FontWeight.w800))),
          Text(app.tr('100% goes to rider', '100% ரைடருக்கு'), style: ts(10, color: kMuted)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < opts.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _tip = opts[i]);
                  _scheduleQuote();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _tip == opts[i] ? kTintSoft : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _tip == opts[i] ? kBrand : kLine, width: _tip == opts[i] ? 1.8 : 1)),
                  child: Text(opts[i] == 0 ? app.tr('None', 'வேண்டாம்') : '₹${opts[i]}${opts[i] == opts.last && opts.length > 2 ? ' ❤️' : ''}', style: ts(12, weight: FontWeight.w800, color: _tip == opts[i] ? kBrand : kMuted)),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _noteBox() => _box(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        radius: 18,
        child: TextField(
          controller: _note,
          maxLines: 2,
          maxLength: 150,
          style: ts(13),
          decoration: InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            counterText: '',
            icon: const Icon(Icons.edit_note_rounded, color: kBrand),
            hintText: app.tr('Note for the kitchen (optional)', 'சமையலறைக்கு குறிப்பு (விருப்பம்)'),
            hintStyle: ts(12.5, color: kMuted),
          ),
        ),
      );

  Widget _summary(List<_HotelBill> bills) {
    double sum(double Function(_HotelBill) f) => bills.fold<double>(0, (s, b) => s + f(b));
    final del = cart.fulfil == 'Delivery';
    final grand = sum((b) => b.total);
    return _box(
      radius: 18,
      color: _kPage,
      border: kTintSoft,
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _row(app.tr('Item Total', 'பொருட்கள் மொத்தம்'), rupee(sum((b) => b.items))),
        if (del) _row(app.tr('Delivery Fee', 'டெலிவரி கட்டணம்'), sum((b) => b.delivery) <= 0 ? app.tr('FREE', 'இலவசம்') : rupee(sum((b) => b.delivery)), color: sum((b) => b.delivery) <= 0 ? kGreen : null),
        if (sum((b) => b.packing + b.platform) > 0) _row(app.tr('Packaging & Platform Fee', 'பேக்கிங் & தளக் கட்டணம்'), rupee(sum((b) => b.packing + b.platform))),
        if (sum((b) => b.tip) > 0) _row(app.tr('Rider Tip', 'ரைடர் டிப்'), rupee(sum((b) => b.tip))),
        if (sum((b) => b.discount) > 0) _row(app.tr('Promo Discount', 'சலுகை'), '-${rupee(sum((b) => b.discount))}', color: kGreen),
        const Divider(height: 16, color: kLine),
        _row(app.tr('Grand Total', 'மொத்தம்'), rupee(grand), bold: true),
        if (bills.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              const Icon(Icons.call_split_rounded, size: 15, color: kBrand),
              const SizedBox(width: 6),
              Expanded(child: Text(app.tr('${bills.length} hotels = ${bills.length} separate orders, each delivered by its own hotel.', '${bills.length} ஹோட்டல் = ${bills.length} தனித்தனி ஆர்டர்கள்.'), style: ts(11, weight: FontWeight.w600, color: kBrand))),
            ]),
          ),
      ]),
    );
  }

  // ---------- payment ----------
  Widget _payTab(String id, IconData icon, String label) {
    final on = _tab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(14), boxShadow: on ? kSoftShadow : null),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: on ? kBrand : kMuted),
            const SizedBox(width: 4),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, weight: FontWeight.w800, color: on ? kBrand : kMuted))),
          ]),
        ),
      ),
    );
  }

  Widget _onlinePanel() {
    final isUpi = _tab == 'upi';
    final isCard = _tab == 'card';
    final icon = isUpi ? Icons.bolt_rounded : (isCard ? Icons.credit_card_rounded : Icons.account_balance_rounded);
    final head = isUpi ? app.tr('Pay with any UPI app', 'எந்த UPI ஆப்பிலும் செலுத்தலாம்') : (isCard ? app.tr('Pay with Debit / Credit card', 'டெபிட் / கிரெடிட் கார்டு') : app.tr('Pay with Net Banking', 'நெட் பேங்கிங்'));
    final sub = isUpi
        ? app.tr('GPay, PhonePe, Paytm, BHIM or any UPI app opens on the next screen.', 'அடுத்த திரையில் GPay, PhonePe, Paytm போன்ற UPI ஆப் திறக்கும்.')
        : (isCard ? app.tr('Enter your card details on the secure Razorpay screen. We never see or store them.', 'அட்டை விவரங்களை பாதுகாப்பான Razorpay திரையில் உள்ளிடவும். நாங்கள் சேமிக்க மாட்டோம்.') : app.tr('Choose your bank on the secure Razorpay screen.', 'பாதுகாப்பான Razorpay திரையில் உங்கள் வங்கியை தேர்வு செய்யவும்.'));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBrandMid)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 20, color: kBrand)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(head, style: ts(13.5, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(sub, style: ts(12, color: kMuted, height: 1.4)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.lock_rounded, size: 12, color: kGreen),
              const SizedBox(width: 4),
              Text(app.tr('Secured by Razorpay', 'Razorpay பாதுகாப்பு'), style: ts(10.5, weight: FontWeight.w800, color: kGreen)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _codPanel() => Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.payments_rounded, color: kBrand, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(cart.fulfil == 'Delivery' ? app.tr('Pay cash to the delivery partner when your food arrives.', 'உணவு வந்ததும் டெலிவரி நபரிடம் பணம் கொடுங்கள்.') : app.tr('Pay cash at the hotel counter when you collect.', 'எடுக்கும் போது ஹோட்டலில் பணம் கொடுங்கள்.'), style: ts(12.5, color: kInk, height: 1.4))),
      ]);

  Widget _paymentBox() {
    final upiOn = food.flag('Food.UpiEnabled', true);
    final codOn = food.flag('Food.CodEnabled', true);
    return _box(
      padding: const EdgeInsets.all(12),
      color: const Color(0x80E8F0FE),
      border: kBrandMid,
      radius: 24,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(app.tr('PAYMENT METHOD', 'பணம் செலுத்தும் முறை'), style: ts(11, weight: FontWeight.w800))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(20)), child: Text(app.tr('100% Secure', '100% பாதுகாப்பு'), style: ts(10, weight: FontWeight.w800, color: kBrand))),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(18), border: Border.all(color: kBrandMid)),
          child: Row(children: [
            if (upiOn) _payTab('upi', Icons.bolt_rounded, 'UPI'),
            if (food.flag('Food.CardEnabled', true)) _payTab('card', Icons.credit_card_rounded, app.tr('Card', 'கார்டு')),
            if (food.flag('Food.NetBankingEnabled', true)) _payTab('nb', Icons.account_balance_rounded, app.tr('Net Banking', 'நெட் பேங்கிங்')),
            if (codOn) _payTab('cod', Icons.payments_rounded, app.tr('Cash', 'பணம்')),
          ]),
        ),
        const SizedBox(height: 12),
        if (_tab != 'cod') _onlinePanel(),
        if (_tab == 'cod') _codPanel(),
      ]),
    );
  }

  // ---------- pay ----------
  Future<void> _pay(List<_HotelBill> bills) async {
    if (_busy || cart.isEmpty) return;
    final bad = bills.where((b) => b.problem != null).toList();
    if (bad.isNotEmpty) {
      _msg(bad.first.problem!);
      return;
    }
    if (!await requireLogin(context, whyEn: 'Please login to place your order.', whyTa: 'ஆர்டர் செய்ய உள்நுழையவும்.')) return;
    if (!mounted) return;
    if (!_addrLoaded) await _loadAddresses();
    if (cart.fulfil == 'Delivery' && _addrId == null) {
      _msg(app.tr('Add your delivery address first.', 'முதலில் டெலிவரி முகவரியை சேர்க்கவும்.'));
      _addressSheet();
      return;
    }
    setState(() => _busy = true);
    try {
      final body = _bagBody(payMethod: _tab == 'cod' ? 'COD' : 'ONLINE', payRef: null);
      body['addressId'] = cart.fulfil == 'Delivery' ? _addrId : null;
      body['pickupSlot'] = cart.fulfil == 'Pickup' ? _slot : null;
      body['note'] = _note.text.trim();
      dynamic r;
      if (_tab == 'cod') {
        r = await BusApi.post('/food/orders', body);
      } else {
        r = await _payOnline(body);
        if (r == null) {
          if (mounted) {
            setState(() => _busy = false);
            if (_rzpErr != null) _msg(_rzpErr!);
          }
          return;
        }
      }
      final orders = <Map<String, dynamic>>[];
      Map<String, dynamic> checkout = <String, dynamic>{};
      if (r is Map) {
        if (r['orders'] is List) {
          for (final o in r['orders'] as List) {
            if (o is Map) orders.add(Map<String, dynamic>.from(o));
          }
        }
        if (r['checkout'] is Map) checkout = Map<String, dynamic>.from(r['checkout'] as Map);
      }
      final paid = bills.fold<double>(0, (s, b) => s + b.total);
      final result = _OrderResult(
        orders: orders,
        pickup: cart.fulfil == 'Pickup',
        total: checkout.isNotEmpty && _n(checkout['grandTotal']) > 0 ? _n(checkout['grandTotal']) : paid,
        payLine: _tab != 'cod' ? app.tr('Paid ${rupee(paid)} online (Razorpay)', '${rupee(paid)} ஆன்லைனில் செலுத்தப்பட்டது') : app.tr('Pay ${rupee(paid)} on ${cart.fulfil == 'Delivery' ? 'delivery' : 'pickup'}', '${rupee(paid)} ${cart.fulfil == 'Delivery' ? 'டெலிவரியில்' : 'எடுக்கும் போது'} செலுத்தவும்'),
        area: bills.isNotEmpty ? (bills.first.hotel.area ?? '') : '',
        eta: bills.fold<int>(0, (m, b) => (cart.fulfil == 'Delivery' ? b.hotel.shownEta : b.hotel.prepMinutes) > m ? (cart.fulfil == 'Delivery' ? b.hotel.shownEta : b.hotel.prepMinutes) : m),
        hotels: [for (final b in bills) b.hotel],
      );
      cart.note = '';
      cart.clear();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => _OrderSuccess(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _msg(BusApi.friendly(e));
      }
    }
  }

  /// Online payment: server makes the Razorpay order, the Razorpay screen takes the money, the server checks it and places the orders.
  /// Returns the server reply (orders) or null when the customer did not pay.
  Future<dynamic> _payOnline(Map<String, dynamic> body) async {
    _rzpErr = null;
    final c = await BusApi.post('/food/pay/create', body);
    if (c is! Map) throw 'Could not start the payment.';
    final done = Completer<PaymentSuccessResponse?>();
    _rzp?.clear();
    final rz = Razorpay();
    _rzp = rz;
    rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) done.complete(r);
    });
    rz.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      final m = (r.message ?? '').toString();
      _rzpErr = m.isEmpty || m.toLowerCase().contains('cancel') ? null : m;
      if (!done.isCompleted) done.complete(null);
    });
    rz.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
    final prefill = <String, dynamic>{'method': _tab == 'upi' ? 'upi' : (_tab == 'card' ? 'card' : 'netbanking')};
    final ph = auth.mobile.replaceAll(RegExp(r'\D'), '');
    if (ph.length >= 10) prefill['contact'] = ph.substring(ph.length - 10);
    final em = auth.email;
    if (em.contains('@')) prefill['email'] = em;
    rz.open(<String, dynamic>{
      'key': c['keyId'],
      'amount': c['amount'],
      'currency': 'INR',
      'order_id': c['rzpOrderId'],
      'name': 'I Love APK',
      'description': app.tr('Food order', 'உணவு ஆர்டர்'),
      'prefill': prefill,
      'theme': <String, dynamic>{'color': '#1A73E8'},
      'retry': <String, dynamic>{'enabled': true, 'max_count': 2},
    });
    final ok = await done.future;
    _rzp?.clear();
    _rzp = null;
    if (ok == null) return null;
    try {
      return await BusApi.post('/food/pay/verify', <String, dynamic>{'rzpOrderId': ok.orderId, 'rzpPaymentId': ok.paymentId, 'signature': ok.signature});
    } catch (e) {
      // The money is paid and the webhook will still place the order, so do not let the customer pay twice.
      final m = BusApi.friendly(e);
      cart.note = '';
      cart.clear();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dc) => AlertDialog(
            title: Text(app.tr('Payment received', 'பணம் பெறப்பட்டது')),
            content: Text(app.tr('$m\nPlease check My Orders in a minute. If no order appears, the amount is refunded automatically.', '$m\nஒரு நிமிடத்தில் My Orders பாருங்கள். ஆர்டர் இல்லையெனில் பணம் தானாக திரும்பும்.')),
            actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('OK'))],
          ),
        );
        if (mounted) Navigator.of(context).pop();
      }
      return null;
    }
  }

  Widget _payBar(List<_HotelBill> bills) {
    final grand = bills.fold<double>(0, (s, b) => s + b.total);
    final blocked = bills.any((b) => b.problem != null);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
      child: GestureDetector(
        onTap: (_busy || blocked) ? null : () => _pay(bills),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: blocked ? kLine : kBrand, borderRadius: BorderRadius.circular(18), boxShadow: blocked ? null : const [BoxShadow(color: kBrandShadow, blurRadius: 16, offset: Offset(0, 6))]),
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: Text(
                      _tab == 'cod' ? app.tr('Place Order • ${rupee(grand)}', 'ஆர்டர் செய் • ${rupee(grand)}') : app.tr('Pay ${rupee(grand)} via ${_payMethodLabel()}', '${rupee(grand)} செலுத்து • ${_payMethodLabel()}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(15, weight: FontWeight.w800, color: blocked ? kMuted : Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.lock_rounded, size: 15, color: blocked ? kMuted : Colors.white),
                ]),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 84, height: 84, decoration: const BoxDecoration(color: kTint, shape: BoxShape.circle), child: const Icon(Icons.shopping_bag_outlined, size: 40, color: kBrand)),
            const SizedBox(height: 16),
            Text(app.tr('Your bag is empty', 'உங்கள் பை காலியாக உள்ளது'), style: ts(17, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(app.tr('Add dishes from any hotel and they will show up here.', 'எந்த ஹோட்டலிலிருந்தும் உணவை சேர்க்கவும்.'), textAlign: TextAlign.center, style: ts(13, color: kMuted)),
            const SizedBox(height: 18),
            GestureDetector(onTap: () => Navigator.maybePop(context), child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), decoration: BoxDecoration(color: kBrand, borderRadius: BorderRadius.circular(16)), child: Text(app.tr('Browse hotels', 'ஹோட்டல்களை பார்'), style: ts(13.5, weight: FontWeight.w800, color: Colors.white)))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([cart, app, food]),
      builder: (context, _) {
        final empty = cart.isEmpty;
        final bills = empty ? const <_HotelBill>[] : _bills();
        return foodScale(
          context,
          Scaffold(
            backgroundColor: _kPage,
            body: Column(children: [
              _top(),
              Expanded(
                child: empty
                    ? _empty()
                    : ListView(
                        padding: const EdgeInsets.only(top: 12, bottom: 20),
                        children: [
                          _modeToggle(),
                          for (var i = 0; i < bills.length; i++) _hotelCard(bills[i], i, bills.length),
                          _couponCard(bills),
                          if (cart.fulfil == 'Delivery') _addressCard() else _pickupCard(),
                          if (cart.fulfil == 'Delivery') _tipBox(),
                          _noteBox(),
                          _summary(bills),
                          _paymentBox(),
                        ],
                      ),
              ),
              if (!empty) _payBar(bills),
            ]),
          ),
        );
      },
    );
  }
}

class _OrderResult {
  final List<Map<String, dynamic>> orders;
  final bool pickup;
  final double total;
  final String payLine;
  final String area;
  final int eta;
  final List<FoodHotel> hotels;
  _OrderResult({required this.orders, required this.pickup, required this.total, required this.payLine, required this.area, required this.eta, required this.hotels});
}

/// Order confirmed (design "Order Confirmation & live tracker / pickup token").
class _OrderSuccess extends StatelessWidget {
  final _OrderResult result;
  const _OrderSuccess({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    final multi = r.orders.length > 1;
    final head = r.orders.isEmpty ? app.tr('Order Confirmed', 'ஆர்டர் உறுதியானது') : (multi ? app.tr('${r.orders.length} Orders Confirmed', '${r.orders.length} ஆர்டர்கள் உறுதி') : app.tr('Order #${_s(r.orders.first['orderNo'])} Confirmed', 'ஆர்டர் #${_s(r.orders.first['orderNo'])} உறுதி'));
    return foodScale(
      context,
      Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kBrand, Color(0xFF1557B0)])),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 84, height: 84, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 10))]), child: const Icon(Icons.check_circle_rounded, size: 52, color: Color(0xFF1E9E5A))),
                  const SizedBox(height: 16),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)), child: Text(head.toUpperCase(), style: ts(11.5, weight: FontWeight.w800, color: Colors.white))),
                  const SizedBox(height: 10),
                  Text(app.tr('Kitchen is firing up!', 'சமையலறை தயாராகிறது!'), textAlign: TextAlign.center, style: ts(25, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    multi ? app.tr('Your food is being freshly prepared in ${r.hotels.length} kitchens.', '${r.hotels.length} சமையலறைகளில் உங்கள் உணவு தயாராகிறது.') : app.tr('Your food is being freshly prepared${r.area.isNotEmpty ? ' in ${r.area}' : ''}.', 'உங்கள் உணவு புதிதாக தயாராகிறது${r.area.isNotEmpty ? ' - ${r.area}' : ''}.'),
                    textAlign: TextAlign.center,
                    style: ts(12.5, color: const Color(0xFFD2E3FC), height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _step(const Color(0xFF4ADE80), '1. ${r.payLine}', true),
                      const SizedBox(height: 11),
                      _step(const Color(0xFFFCD34D), app.tr('2. Hotel confirming & chef preparing your meal', '2. ஹோட்டல் உறுதி செய்து சமைக்கிறது'), true),
                      const SizedBox(height: 11),
                      _step(Colors.white54, r.pickup ? app.tr('3. Ready for Self-Pickup in ${r.eta} mins', '3. ${r.eta} நிமிடத்தில் எடுக்கத் தயார்') : app.tr('3. Out for Express Delivery', '3. டெலிவரிக்கு புறப்படும்'), false),
                    ]),
                  ),
                  for (final o in r.orders) ...[
                    const SizedBox(height: 12),
                    r.pickup && _s(o['pickupToken']).isNotEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF86EFAC), width: 2)),
                            child: Column(children: [
                              Text(app.tr('SELF-PICKUP COUNTER TOKEN', 'நேரில் எடுக்கும் டோக்கன்'), style: ts(10, weight: FontWeight.w800, color: kGreen)),
                              Text('#${_s(o['pickupToken'])}', style: ts(38, weight: FontWeight.w800, color: kInk)),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEAF6EE), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFB7E1C1))), child: Text(app.tr('Show at hotel counter to skip queue', 'ஹோட்டல் கவுண்டரில் காட்டவும்'), style: ts(11, weight: FontWeight.w800, color: kGreen))),
                              const SizedBox(height: 6),
                              Text('${_s(o['hotelNameEn'])} • ${app.tr('Ready in ${r.eta} mins', '${r.eta} நிமிடத்தில் தயார்')}', textAlign: TextAlign.center, style: ts(11, color: kMuted)),
                            ]),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white24)),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_s(o['hotelNameEn']), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, weight: FontWeight.w800, color: Colors.white)),
                                  Text('#${_s(o['orderNo'])} • ${rupee(_n(o['totalAmount']))}', style: ts(11, color: const Color(0xFFD2E3FC))),
                                ]),
                              ),
                              if (_s(o['deliveryOtp']).isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                  child: Column(children: [Text('OTP', style: ts(8.5, weight: FontWeight.w800, color: kMuted)), Text(_s(o['deliveryOtp']), style: ts(15, weight: FontWeight.w800, color: kBrand))]),
                                ),
                            ]),
                          ),
                  ],
                  const SizedBox(height: 22),
                  GestureDetector(
                    onTap: () => Navigator.popUntil(context, (route) => route.isFirst || route == FoodHomeScreen.homeRoute),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))]), child: Text(app.tr('Back to Home', 'முகப்புக்கு'), style: ts(13.5, weight: FontWeight.w800, color: kBrand))),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _step(Color dot, String text, bool strong) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: ts(12.5, weight: strong ? FontWeight.w800 : FontWeight.w500, color: strong ? Colors.white : const Color(0xFFD2E3FC)))),
      ]);
}
