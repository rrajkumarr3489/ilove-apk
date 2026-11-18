import 'package:flutter/foundation.dart';

import '../bus/bus_api.dart';
import 'food_models.dart';

/// Hotels and menus read from the server.
class FoodRepo extends ChangeNotifier {
  List<FoodHotel> hotels = <FoodHotel>[];
  bool loading = false;
  bool loadedOnce = false;
  String? error;
  final Map<int, HotelMenu> _menus = <int, HotelMenu>{};

  Future<void> loadHotels({bool force = false}) async {
    if (loading) return;
    if (loadedOnce && !force) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await BusApi.get('/food/hotels') as List<dynamic>;
      hotels = [for (final h in r) FoodHotel.fromJson(h as Map<String, dynamic>)];
      loadedOnce = true;
    } catch (e) {
      error = BusApi.friendly(e);
    }
    loading = false;
    notifyListeners();
  }

  HotelMenu? cachedMenu(int id) => _menus[id];

  /// Always asks the server (prices and "sold out" change), and keeps the last answer for a quick first paint.
  Future<HotelMenu> loadMenu(int id) async {
    final j = await BusApi.get('/food/hotels/$id') as Map<String, dynamic>;
    final m = HotelMenu.fromJson(j);
    _menus[id] = m;
    return m;
  }
}

final FoodRepo food = FoodRepo();
