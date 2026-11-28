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
  final double? lat;
  final double? lng;
  final String? area;
  final double? priceForTwo;
  final bool highProtein;
  final bool bestseller;
  final double? distanceKm;
  final int etaMin;
  final List<int> categoryIds;
  final String? offerCode;
  final String? offerDescEn;
  final String? offerDescTa;
  final double offerMin;

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
    this.lat,
    this.lng,
    this.area,
    this.priceForTwo,
    this.highProtein = false,
    this.bestseller = false,
    this.distanceKm,
    this.etaMin = 0,
    this.categoryIds = const <int>[],
    this.offerCode,
    this.offerDescEn,
    this.offerDescTa,
    this.offerMin = 0,
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
        lat: j['latitude'] == null ? null : _d(j['latitude']),
        lng: j['longitude'] == null ? null : _d(j['longitude']),
        area: _s(j['area']),
        priceForTwo: j['priceForTwo'] == null ? null : _d(j['priceForTwo']),
        highProtein: _b(j['isHighProtein']),
        bestseller: _b(j['isBestseller']),
        distanceKm: j['distanceKm'] == null ? null : _d(j['distanceKm']),
        etaMin: _i(j['etaMin']),
        categoryIds: [
          for (final x in (_s(j['categoryIds']) ?? '').split(','))
            if (int.tryParse(x.trim()) != null) int.parse(x.trim()),
        ],
        offerCode: _s(j['offerCode']),
        offerDescEn: _s(j['offerDescEn']),
        offerDescTa: _s(j['offerDescTa']),
        offerMin: _d(j['offerMinOrder']),
      );

  /// "Aruppukottai Main Rd" style line: area and price for two, when the admin filled them.
  String get areaLine {
    final parts = <String>[];
    if (area != null) parts.add(area!);
    if (priceForTwo != null && priceForTwo! > 0) parts.add(app.tr('${rupee(priceForTwo!)} for two', '${rupee(priceForTwo!)} இருவருக்கு'));
    return parts.join(' · ');
  }

  String get offerText => _pick(offerDescEn ?? offerCode ?? '', offerDescTa);

  /// Minutes shown on cards: the server's estimate (prep + travel), else the hotel's own prep time.
  int get shownEta => etaMin > 0 ? etaMin : prepMinutes;

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
  final double? oldPrice;
  final bool spicy;
  final bool hasSpice;
  final double itemRating;
  final List<FoodAddOn> addOns;

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
    this.oldPrice,
    this.spicy = false,
    this.hasSpice = false,
    this.itemRating = 0,
    this.addOns = const <FoodAddOn>[],
  });

  factory FoodItem.fromJson(Map<String, dynamic> j, List<FoodVariant> variants, [List<FoodAddOn> addOns = const <FoodAddOn>[]]) => FoodItem(
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
        oldPrice: j['oldPrice'] == null ? null : _d(j['oldPrice']),
        spicy: _b(j['isSpicy']),
        hasSpice: _b(j['hasSpiceLevel']),
        itemRating: _d(j['itemRating']),
        addOns: addOns,
      );

  /// true when tapping ADD must open the sheet (options, spice or add-ons).
  bool get customizable => variants.isNotEmpty || hasSpice || addOns.isNotEmpty;
  int get offPercent => (oldPrice != null && oldPrice! > fromPrice) ? (((oldPrice! - fromPrice) / oldPrice!) * 100).round() : 0;

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

/// An extra the customer can tick on a dish (extra raita, cheese ...). itemId null = offered on every dish of the hotel.
class FoodAddOn {
  final int id;
  final int? itemId;
  final String nameEn;
  final String? nameTa;
  final double price;

  FoodAddOn({required this.id, this.itemId, required this.nameEn, this.nameTa, required this.price});

  factory FoodAddOn.fromJson(Map<String, dynamic> j) => FoodAddOn(
        id: _i(j['addOnId']),
        itemId: j['itemId'] == null ? null : _i(j['itemId']),
        nameEn: _s(j['nameEn']) ?? '',
        nameTa: _s(j['nameTa']),
        price: _d(j['price']),
      );

  String get name => _pick(nameEn, nameTa);
}

/// One spice choice (Mild / Medium / Fiery). The list is a setting in the admin panel.
class FoodSpice {
  final String nameEn;
  final String? nameTa;

  FoodSpice(this.nameEn, this.nameTa);

  String get name => _pick(nameEn, nameTa);
}

class HotelMenu {
  final FoodHotel hotel;
  final List<FoodCategory> categories;
  final List<FoodItem> items;
  final List<FoodSpice> spiceLevels;
  final List<FoodOffer> offers;

  HotelMenu(this.hotel, this.categories, this.items, {this.spiceLevels = const <FoodSpice>[], this.offers = const <FoodOffer>[]});

  factory HotelMenu.fromJson(Map<String, dynamic> j) {
    final vars = <int, List<FoodVariant>>{};
    for (final v in (j['variants'] as List<dynamic>? ?? const <dynamic>[])) {
      final m = v as Map<String, dynamic>;
      vars.putIfAbsent(_i(m['itemId']), () => <FoodVariant>[]).add(FoodVariant.fromJson(m));
    }
    final adds = <FoodAddOn>[
      for (final a in (j['addOns'] as List<dynamic>? ?? const <dynamic>[])) FoodAddOn.fromJson(a as Map<String, dynamic>),
    ];
    final items = <FoodItem>[];
    for (final it in (j['items'] as List<dynamic>? ?? const <dynamic>[])) {
      final m = it as Map<String, dynamic>;
      final id = _i(m['itemId']);
      items.add(FoodItem.fromJson(m, vars[id] ?? const <FoodVariant>[], [for (final a in adds) if (a.itemId == null || a.itemId == id) a]));
    }
    final cats = <FoodCategory>[
      for (final c in (j['categories'] as List<dynamic>? ?? const <dynamic>[])) FoodCategory.fromJson(c as Map<String, dynamic>),
    ];
    return HotelMenu(
      FoodHotel.fromJson(j['hotel'] as Map<String, dynamic>),
      cats,
      items,
      spiceLevels: [
        for (final x in (j['spiceLevels'] as List<dynamic>? ?? const <dynamic>[])) FoodSpice(_s((x as Map<String, dynamic>)['nameEn']) ?? '', _s(x['nameTa'])),
      ],
      offers: [for (final o in (j['offers'] as List<dynamic>? ?? const <dynamic>[])) FoodOffer.fromJson(o as Map<String, dynamic>)],
    );
  }

  String categoryName(int? id) {
    for (final c in categories) {
      if (c.id == id) return c.name;
    }
    return '';
  }

  List<FoodItem> itemsIn(int? categoryId) => items.where((i) => i.categoryId == categoryId).toList();
}

/// A dish together with the hotel that sells it (used for search and the "popular dishes" row).
class DishHit {
  final FoodHotel hotel;
  final FoodItem item;
  final String category;

  DishHit(this.hotel, this.item, this.category);
}

/// A banner from the admin panel (top of the Food screen).
class FoodBanner {
  final int id;
  final String image;
  final String? bgColor;
  final String linkType; // None / Hotel / Filter
  final String? linkValue;

  FoodBanner({required this.id, required this.image, this.bgColor, this.linkType = 'None', this.linkValue});

  factory FoodBanner.fromJson(Map<String, dynamic> j) => FoodBanner(
        id: _i(j['bannerId']),
        image: _s(j['imageFile']) ?? '',
        bgColor: _s(j['bgColor']),
        linkType: _s(j['linkType']) ?? 'None',
        linkValue: _s(j['linkValue']),
      );
}

/// A story card at the top of the Food home (admin panel: Food Content).
class FoodStory {
  final int id;
  final String labelEn;
  final String? labelTa;
  final String titleEn;
  final String? titleTa;
  final String? subEn;
  final String? subTa;
  final String image;
  final int? hotelId;
  final int? itemId;
  final double? price;
  final String? hotelNameEn;
  final String? hotelNameTa;

  FoodStory({this.itemId, required this.id, required this.labelEn, this.labelTa, required this.titleEn, this.titleTa, this.subEn, this.subTa, required this.image, this.hotelId, this.price, this.hotelNameEn, this.hotelNameTa});

  factory FoodStory.fromJson(Map<String, dynamic> j) => FoodStory(
        id: _i(j['storyId']),
        labelEn: _s(j['labelEn']) ?? '',
        labelTa: _s(j['labelTa']),
        titleEn: _s(j['titleEn']) ?? '',
        titleTa: _s(j['titleTa']),
        subEn: _s(j['subtitleEn']),
        subTa: _s(j['subtitleTa']),
        image: _s(j['imageFile']) ?? '',
        hotelId: j['hotelId'] == null ? null : _i(j['hotelId']),
        itemId: j['itemId'] == null ? null : _i(j['itemId']),
        price: j['price'] == null ? null : _d(j['price']),
        hotelNameEn: _s(j['hotelNameEn']),
        hotelNameTa: _s(j['hotelNameTa']),
      );

  String get label => _pick(labelEn, labelTa);
  String get title => _pick(titleEn, titleTa);
  String get sub => _pick(subEn ?? '', subTa);
  String get hotelName => _pick(hotelNameEn ?? '', hotelNameTa);
}

/// A food circle (Biriyani, Tiffin ...) made in the admin panel.
class HomeCategory {
  final int id;
  final String nameEn;
  final String? nameTa;
  final String? image;

  HomeCategory({required this.id, required this.nameEn, this.nameTa, this.image});

  factory HomeCategory.fromJson(Map<String, dynamic> j) => HomeCategory(id: _i(j['foodCategoryId']), nameEn: _s(j['nameEn']) ?? '', nameTa: _s(j['nameTa']), image: _s(j['imageFile']));

  String get name => _pick(nameEn, nameTa);
}

/// A quick deal ("drop"): a dish with a short delivery time and maybe a cut price.
class FoodDrop {
  final int itemId;
  final int hotelId;
  final String hotelNameEn;
  final String? hotelNameTa;
  final String nameEn;
  final String? nameTa;
  final double price;
  final double? oldPrice;
  final bool veg;
  final String? picture;
  final int etaMin;
  final int? secondsLeft;
  final bool customizable;

  FoodDrop({required this.itemId, required this.hotelId, required this.hotelNameEn, this.hotelNameTa, required this.nameEn, this.nameTa, required this.price, this.oldPrice, this.veg = true, this.picture, this.etaMin = 15, this.secondsLeft, this.customizable = false});

  factory FoodDrop.fromJson(Map<String, dynamic> j) => FoodDrop(
        itemId: _i(j['itemId']),
        hotelId: _i(j['hotelId']),
        hotelNameEn: _s(j['hotelNameEn']) ?? '',
        hotelNameTa: _s(j['hotelNameTa']),
        nameEn: _s(j['nameEn']) ?? '',
        nameTa: _s(j['nameTa']),
        price: _d(j['price']),
        oldPrice: j['oldPrice'] == null ? null : _d(j['oldPrice']),
        veg: _b(j['isVeg']),
        picture: _s(j['pictureFile']),
        etaMin: _i(j['etaMin']) <= 0 ? 15 : _i(j['etaMin']),
        secondsLeft: j['secondsLeft'] == null ? null : _i(j['secondsLeft']),
        customizable: _b(j['customizable']),
      );

  String get name => _pick(nameEn, nameTa);
  String get hotelName => _pick(hotelNameEn, hotelNameTa);
  int get offPercent => (oldPrice != null && oldPrice! > price) ? (((oldPrice! - price) / oldPrice!) * 100).round() : 0;
}

/// A coupon shown in the offers strip.
class FoodOffer {
  final String code;
  final String descEn;
  final String? descTa;
  final String type; // Flat / Percent
  final double value;
  final double? maxDiscount;
  final double minOrder;
  final int? hotelId;

  FoodOffer({required this.code, required this.descEn, this.descTa, this.type = 'Flat', this.value = 0, this.maxDiscount, this.minOrder = 0, this.hotelId});

  factory FoodOffer.fromJson(Map<String, dynamic> j) => FoodOffer(
        code: _s(j['code']) ?? '',
        descEn: _s(j['descEn']) ?? '',
        descTa: _s(j['descTa']),
        type: _s(j['discountType']) ?? 'Flat',
        value: _d(j['discountValue']),
        maxDiscount: j['maxDiscount'] == null ? null : _d(j['maxDiscount']),
        minOrder: _d(j['minOrder']),
        hotelId: j['hotelId'] == null ? null : _i(j['hotelId']),
      );

  String get desc {
    final d = _pick(descEn, descTa);
    if (d.isNotEmpty) return d;
    return type == 'Percent' ? '${value.toStringAsFixed(0)}% OFF' : '${rupee(value)} OFF';
  }
}
