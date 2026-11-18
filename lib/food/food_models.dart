import '../app_state.dart';

double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);
bool _b(dynamic v) => v == true || v == 1;
int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);
String? _s(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

String _pick(String en, String? ta) => (app.lang == 'ta' && ta != null && ta.isNotEmpty) ? ta : en;

/// 1250 -> ₹1250, 62.5 -> ₹62.50
String rupee(double v) => '₹${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

class FoodHotel {
  final int id;
  final String nameEn;
  final String? nameTa;
  final String? cuisineEn;
  final String? cuisineTa;
  final String? addressEn;
  final String? addressTa;
  final String? phone;
  final String? picture;
  final bool pureVeg;
  final String? openTime;
  final String? closeTime;
  final bool openNow;
  final bool acceptsOrders;
  final bool canDeliver;
  final bool canPickup;
  final double deliveryFee;
  final double? freeAbove;
  final double packing;
  final double minOrder;
  final int prepMinutes;
  final double rating;
  final int ratingCount;
  final double? priceFrom;
  final int itemCount;

  FoodHotel({
    required this.id,
    required this.nameEn,
    this.nameTa,
    this.cuisineEn,
    this.cuisineTa,
    this.addressEn,
    this.addressTa,
    this.phone,
    this.picture,
    this.pureVeg = false,
    this.openTime,
    this.closeTime,
    this.openNow = true,
    this.acceptsOrders = true,
    this.canDeliver = true,
    this.canPickup = true,
    this.deliveryFee = 0,
    this.freeAbove,
    this.packing = 0,
    this.minOrder = 0,
    this.prepMinutes = 20,
    this.rating = 0,
    this.ratingCount = 0,
    this.priceFrom,
    this.itemCount = 0,
  });

  factory FoodHotel.fromJson(Map<String, dynamic> j) => FoodHotel(
        id: _i(j['hotelId']),
        nameEn: _s(j['nameEn']) ?? '',
        nameTa: _s(j['nameTa']),
        cuisineEn: _s(j['cuisineEn']),
        cuisineTa: _s(j['cuisineTa']),
        addressEn: _s(j['addressEn']),
        addressTa: _s(j['addressTa']),
        phone: _s(j['phone']),
        picture: _s(j['pictureFile']),
        pureVeg: _b(j['isPureVeg']),
        openTime: _s(j['openTime']),
        closeTime: _s(j['closeTime']),
        openNow: _b(j['isOpenNow']),
        acceptsOrders: _b(j['acceptsOrders']),
        canDeliver: _b(j['canDeliver']),
        canPickup: _b(j['canPickup']),
        deliveryFee: _d(j['deliveryFee']),
        freeAbove: j['freeDeliveryAbove'] == null ? null : _d(j['freeDeliveryAbove']),
        packing: _d(j['packingCharge']),
        minOrder: _d(j['minOrderAmount']),
        prepMinutes: _i(j['prepMinutes']) <= 0 ? 20 : _i(j['prepMinutes']),
        rating: _d(j['ratingAvg']),
        ratingCount: _i(j['ratingCount']),
        priceFrom: j['priceFrom'] == null ? null : _d(j['priceFrom']),
        itemCount: _i(j['itemCount']),
      );

  String get name => _pick(nameEn, nameTa);
  String get cuisine => _pick(cuisineEn ?? '', cuisineTa);
  String get address => _pick(addressEn ?? '', addressTa);

  /// Text used by the search box (both languages).
  String get searchText => '$nameEn ${nameTa ?? ''} ${cuisineEn ?? ''} ${cuisineTa ?? ''}'.toLowerCase();

  /// Delivery line for cards: "Free delivery", "₹20 delivery" or "Pickup only".
  String get deliveryText {
    if (!canDeliver) return app.tr('Pickup only', 'நேரில் எடுக்க மட்டும்');
    if (deliveryFee <= 0) return app.tr('Free delivery', 'இலவச டெலிவரி');
    return app.tr('${rupee(deliveryFee)} delivery', '${rupee(deliveryFee)} டெலிவரி');
  }
}

class FoodCategory {
  final int id;
  final String nameEn;
  final String? nameTa;

  FoodCategory({required this.id, required this.nameEn, this.nameTa});

  factory FoodCategory.fromJson(Map<String, dynamic> j) =>
      FoodCategory(id: _i(j['categoryId']), nameEn: _s(j['nameEn']) ?? '', nameTa: _s(j['nameTa']));

  String get name => _pick(nameEn, nameTa);
}

class FoodVariant {
  final int id;
  final String nameEn;
  final String? nameTa;
  final double price;
  final bool available;

  FoodVariant({required this.id, required this.nameEn, this.nameTa, required this.price, this.available = true});

  factory FoodVariant.fromJson(Map<String, dynamic> j) => FoodVariant(
        id: _i(j['variantId']),
        nameEn: _s(j['nameEn']) ?? '',
        nameTa: _s(j['nameTa']),
        price: _d(j['price']),
        available: _b(j['isAvailable']),
      );

  String get name => _pick(nameEn, nameTa);
}

class FoodItem {
  final int id;
  final int? categoryId;
  final String nameEn;
  final String? nameTa;
  final String? descEn;
  final String? descTa;
  final double price;
  final bool veg;
  final String? picture;
  final bool available;
  final bool bestseller;
  final List<FoodVariant> variants;

  FoodItem({
    required this.id,
    this.categoryId,
    required this.nameEn,
    this.nameTa,
    this.descEn,
    this.descTa,
    required this.price,
    this.veg = true,
    this.picture,
    this.available = true,
    this.bestseller = false,
    this.variants = const <FoodVariant>[],
  });

  factory FoodItem.fromJson(Map<String, dynamic> j, List<FoodVariant> variants) => FoodItem(
        id: _i(j['itemId']),
        categoryId: j['categoryId'] == null ? null : _i(j['categoryId']),
        nameEn: _s(j['nameEn']) ?? '',
        nameTa: _s(j['nameTa']),
        descEn: _s(j['descEn']),
        descTa: _s(j['descTa']),
        price: _d(j['price']),
        veg: _b(j['isVeg']),
        picture: _s(j['pictureFile']),
        available: _b(j['isAvailable']),
        bestseller: _b(j['isBestseller']),
        variants: variants,
      );

  String get name => _pick(nameEn, nameTa);
  String get desc => _pick(descEn ?? '', descTa);
  bool get hasVariants => variants.isNotEmpty;

  /// Item price, or the lowest option price when the item has options.
  double get fromPrice {
    if (variants.isEmpty) return price;
    var m = variants.first.price;
    for (final v in variants) {
      if (v.price < m) m = v.price;
    }
    return m;
  }
}

class HotelMenu {
  final FoodHotel hotel;
  final List<FoodCategory> categories;
  final List<FoodItem> items;

  HotelMenu(this.hotel, this.categories, this.items);

  factory HotelMenu.fromJson(Map<String, dynamic> j) {
    final vars = <int, List<FoodVariant>>{};
    for (final v in (j['variants'] as List<dynamic>? ?? const <dynamic>[])) {
      final m = v as Map<String, dynamic>;
      vars.putIfAbsent(_i(m['itemId']), () => <FoodVariant>[]).add(FoodVariant.fromJson(m));
    }
    final items = <FoodItem>[];
    for (final it in (j['items'] as List<dynamic>? ?? const <dynamic>[])) {
      final m = it as Map<String, dynamic>;
      items.add(FoodItem.fromJson(m, vars[_i(m['itemId'])] ?? const <FoodVariant>[]));
    }
    final cats = <FoodCategory>[
      for (final c in (j['categories'] as List<dynamic>? ?? const <dynamic>[])) FoodCategory.fromJson(c as Map<String, dynamic>),
    ];
    return HotelMenu(FoodHotel.fromJson(j['hotel'] as Map<String, dynamic>), cats, items);
  }

  List<FoodItem> itemsIn(int? categoryId) => items.where((i) => i.categoryId == categoryId).toList();
}
