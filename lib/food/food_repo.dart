import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../bus/bus_api.dart';
import 'food_models.dart';

/// Hotels and menus read from the server. Keeps what it read on the phone, so the screen opens at once next time.
class FoodRepo extends ChangeNotifier {
  List<FoodHotel> hotels = <FoodHotel>[];
  bool loading = false;
  bool loadedOnce = false;
  bool offline = false;
  String? error;

  final Map<int, HotelMenu> _menus = <int, HotelMenu>{};
  bool menusLoading = false;
  bool menusDone = false;

  List<FoodBanner> banners = <FoodBanner>[];

  final Set<int> favs = <int>{};
  List<String> recent = <String>[];

  List<FoodHotel> _parse(List<dynamic> r) => [for (final h in r) FoodHotel.fromJson(h as Map<String, dynamic>)];

  /// Shows the hotels saved last time (if any) before the server answers.
  void restore() {
    if (hotels.isEmpty) {
      final s = app.getString('food.hotels');
      if (s != null && s.isNotEmpty) {
        try {
          hotels = _parse(jsonDecode(s) as List<dynamic>);
          loadedOnce = hotels.isNotEmpty;
        } catch (_) {}
      }
    }
    if (banners.isEmpty) {
      final b = app.getString('food.banners');
      if (b != null && b.isNotEmpty) {
        try {
          banners = [for (final x in (jsonDecode(b) as List<dynamic>)) FoodBanner.fromJson(x as Map<String, dynamic>)];
        } catch (_) {}
      }
    }
    favs.clear();
    for (final e in app.getList('food.favs')) {
      final v = int.tryParse(e);
      if (v != null) favs.add(v);
    }
    recent = app.getList('food.recent');
  }

  Future<void> loadHotels({bool force = false}) async {
    if (loading) return;
    if (loadedOnce && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await BusApi.get('/food/hotels') as List<dynamic>;
      hotels = _parse(r);
      loadedOnce = true;
      offline = false;
      await app.setString('food.hotels', jsonEncode(r));
    } catch (e) {
      if (hotels.isEmpty) {
        error = BusApi.friendly(e);
      } else {
        offline = true;
      }
    }
    loading = false;
    notifyListeners();
    unawaited(loadAllMenus());
    unawaited(loadBanners());
  }

  /// Banners set in the admin panel. If the server cannot be reached the last ones are kept.
  Future<void> loadBanners() async {
    try {
      final r = await BusApi.get('/food/banners') as List<dynamic>;
      banners = [for (final x in r) FoodBanner.fromJson(x as Map<String, dynamic>)];
      await app.setString('food.banners', jsonEncode(r));
      notifyListeners();
    } catch (_) {}
  }

  HotelMenu? cachedMenu(int id) => _menus[id];

  /// Always asks the server (prices and "sold out" change) and keeps the answer.
  Future<HotelMenu> loadMenu(int id) async {
    final j = await BusApi.get('/food/hotels/$id') as Map<String, dynamic>;
    final m = HotelMenu.fromJson(j);
    _menus[id] = m;
    return m;
  }

  /// Reads every hotel's menu in the background (3 at a time) so dish search, popular dishes and cuisine photos work.
  Future<void> loadAllMenus() async {
    if (menusLoading || hotels.isEmpty) return;
    menusLoading = true;
    notifyListeners();
    final ids = [for (final h in hotels) h.id];
    var next = 0;
    Future<void> worker() async {
      while (next < ids.length) {
        final id = ids[next];
        next++;
        try {
          await loadMenu(id);
        } catch (_) {}
        notifyListeners();
      }
    }

    await Future.wait([worker(), worker(), worker()]);
    menusLoading = false;
    menusDone = true;
    notifyListeners();
  }

  // ---------- dishes ----------
  List<DishHit> allDishes() {
    final out = <DishHit>[];
    for (final h in hotels) {
      final m = _menus[h.id];
      if (m == null) continue;
      for (final it in m.items) {
        out.add(DishHit(h, it, m.categoryName(it.categoryId)));
      }
    }
    return out;
  }

  bool _hasPic(FoodItem i) => i.picture != null && i.picture!.isNotEmpty;

  /// Bestsellers with a photo first, then other photos, then other bestsellers.
  List<DishHit> popularDishes({int limit = 14}) {
    final all = allDishes().where((d) => d.item.available).toList();
    int score(DishHit d) => (d.item.bestseller ? 2 : 0) + (_hasPic(d.item) ? 3 : 0);
    final good = all.where((d) => score(d) > 0).toList();
    good.sort((a, b) => score(b).compareTo(score(a)));
    return good.take(limit).toList();
  }

  /// First dish photo whose name or category contains one of the words (for the cuisine circles).
  String? photoFor(List<String> words) {
    for (final d in allDishes()) {
      if (!_hasPic(d.item)) continue;
      final t = '${d.item.nameEn} ${d.item.nameTa ?? ''} ${d.category} ${d.hotel.cuisineEn ?? ''}'.toLowerCase();
      for (final w in words) {
        if (w.isNotEmpty && t.contains(w)) return d.item.picture;
      }
    }
    return null;
  }

  List<DishHit> searchDishes(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return <DishHit>[];
    return allDishes().where((d) {
      final t = '${d.item.nameEn} ${d.item.nameTa ?? ''} ${d.item.descEn ?? ''} ${d.item.descTa ?? ''} ${d.category}'.toLowerCase();
      return t.contains(s);
    }).toList();
  }

  // ---------- favourites and recent searches ----------
  bool isFav(int id) => favs.contains(id);

  Future<void> toggleFav(int id) async {
    if (!favs.add(id)) favs.remove(id);
    notifyListeners();
    await app.setList('food.favs', [for (final f in favs) '$f']);
  }

  Future<void> addRecent(String q) async {
    final s = q.trim();
    if (s.length < 2) return;
    recent.removeWhere((e) => e.toLowerCase() == s.toLowerCase());
    recent.insert(0, s);
    if (recent.length > 8) recent = recent.sublist(0, 8);
    notifyListeners();
    await app.setList('food.recent', recent);
  }

  Future<void> clearRecent() async {
    recent = <String>[];
    notifyListeners();
    await app.setList('food.recent', recent);
  }
}

final FoodRepo food = FoodRepo();
