import 'package:flutter/foundation.dart';

import '../app_state.dart';
import 'food_models.dart';
import 'food_repo.dart';

class CartLine {
  final FoodHotel hotel;
  final int itemId;
  final int? variantId;
  final String nameEn;
  final String? nameTa;
  final String? variantEn;
  final String? variantTa;
  final double price;
  final bool veg;
  final String? spiceEn;
  final String? spiceTa;
  final List<FoodAddOn> addOns;
  final String itemNote;
  int qty;

  CartLine({
    required this.hotel,
    required this.itemId,
    this.variantId,
    required this.nameEn,
    this.nameTa,
    this.variantEn,
    this.variantTa,
    required this.price,
    required this.veg,
    this.spiceEn,
    this.spiceTa,
    this.addOns = const <FoodAddOn>[],
    this.itemNote = '',
    this.qty = 1,
  });

  /// Same dish with the same choices = the same line.
  String get key => '$itemId|${variantId ?? 0}|${spiceEn ?? ''}|${(addOns.map((a) => a.id).toList()..sort()).join(',')}|$itemNote';

  String get name => (app.lang == 'ta' && (nameTa ?? '').isNotEmpty) ? nameTa! : nameEn;
  String get variant {
    final parts = <String>[];
    final v = (app.lang == 'ta' && (variantTa ?? '').isNotEmpty) ? variantTa! : (variantEn ?? '');
    if (v.isNotEmpty) parts.add(v);
    final sp = (app.lang == 'ta' && (spiceTa ?? '').isNotEmpty) ? spiceTa! : (spiceEn ?? '');
    if (sp.isNotEmpty) parts.add(sp);
    for (final a in addOns) {
      parts.add('+ ${a.name}');
    }
    return parts.join(' · ');
  }
  double get total => price * qty;
}

/// The food bag. It can hold dishes from SEVERAL hotels; checkout splits it into one order per hotel.
class FoodCart extends ChangeNotifier {
  final List<CartLine> lines = <CartLine>[];
  String fulfil = 'Delivery'; // Delivery / Pickup
  String note = '';

  int get count => lines.fold<int>(0, (s, l) => s + l.qty);
  double get itemsTotal => lines.fold<double>(0, (s, l) => s + l.total);
  bool get isEmpty => lines.isEmpty;

  int qtyOfItem(int itemId) => lines.where((l) => l.itemId == itemId).fold<int>(0, (s, l) => s + l.qty);

  /// The hotels in the bag, in the order they were first added.
  List<FoodHotel> get hotels {
    final out = <FoodHotel>[];
    for (final l in lines) {
      if (!out.any((h) => h.id == l.hotel.id)) out.add(l.hotel);
    }
    return out;
  }

  /// The hotel added last (what the single-hotel screens show).
  FoodHotel? get hotel => lines.isEmpty ? null : lines.last.hotel;

  List<CartLine> linesOf(int hotelId) => lines.where((l) => l.hotel.id == hotelId).toList();
  int countOf(int hotelId) => linesOf(hotelId).fold<int>(0, (s, l) => s + l.qty);
  double totalOf(int hotelId) => linesOf(hotelId).fold<double>(0, (s, l) => s + l.total);

  /// Delivery fee of one hotel's order (free above the hotel's limit, nothing for pickup).
  double deliveryFeeOf(FoodHotel h) {
    if (fulfil != 'Delivery') return 0;
    final free = h.freeAbove;
    if (free != null && free > 0 && totalOf(h.id) >= free) return 0;
    return h.deliveryFee;
  }

  double get deliveryFee => hotels.fold<double>(0, (s, h) => s + deliveryFeeOf(h));
  double get packing => hotels.fold<double>(0, (s, h) => s + h.packing);
  double get grandTotal => itemsTotal + deliveryFee + packing;

  /// Adds one. Dishes of other hotels stay in the bag (one order per hotel at checkout).
  void add(FoodHotel h, FoodItem item, FoodVariant? v, {FoodSpice? spice, List<FoodAddOn> addOns = const <FoodAddOn>[], String note = '', int qty = 1}) {
    if (lines.isEmpty) {
      fulfil = h.canDeliver ? 'Delivery' : 'Pickup';
    }
    final extra = addOns.fold<double>(0, (s, a) => s + a.price);
    final probe = CartLine(
      hotel: h,
      itemId: item.id,
      variantId: v?.id,
      nameEn: item.nameEn,
      price: 0,
      veg: item.veg,
      spiceEn: spice?.nameEn,
      addOns: addOns,
      itemNote: note.trim(),
    );
    for (final l in lines) {
      if (l.key == probe.key) {
        l.qty = (l.qty + qty).clamp(1, maxQty).toInt();
        notifyListeners();
        return;
      }
    }
    lines.add(CartLine(
      hotel: h,
      itemId: item.id,
      variantId: v?.id,
      nameEn: item.nameEn,
      nameTa: item.nameTa,
      variantEn: v?.nameEn,
      variantTa: v?.nameTa,
      price: (v?.price ?? item.price) + extra,
      veg: item.veg,
      spiceEn: spice?.nameEn,
      spiceTa: spice?.nameTa,
      addOns: addOns,
      itemNote: note.trim(),
      qty: qty.clamp(1, maxQty).toInt(),
    ));
    notifyListeners();
  }

  /// Most pieces of one dish (setting Food.MaxItemQty in the admin panel).
  int get maxQty => (int.tryParse(food.cfg('Food.MaxItemQty', '10')) ?? 10).clamp(1, 50).toInt();

  void inc(CartLine l) {
    if (l.qty < maxQty) l.qty++;
    notifyListeners();
  }

  void dec(CartLine l) {
    l.qty--;
    if (l.qty <= 0) lines.remove(l);
    notifyListeners();
  }

  /// "-" on a menu row: takes one off the item (the last option added when it has several).
  void decItem(int itemId) {
    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].itemId == itemId) {
        dec(lines[i]);
        return;
      }
    }
  }

  void setFulfil(String v) {
    fulfil = v;
    notifyListeners();
  }

  void clear() {
    lines.clear();
    note = '';
    notifyListeners();
  }
}

final FoodCart cart = FoodCart();
