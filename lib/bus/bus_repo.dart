import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../config.dart';
import 'bus_api.dart';
import 'bus_models.dart';

/// Holds the offline copy of the bus timetable and answers every question
/// (search, bus-stand board, route detail) from it, so the app works without
/// internet after the first download.
class BusRepo extends ChangeNotifier {
  final Map<int, Place> places = {};
  final Map<int, BusType> types = {};
  final Map<int, BusRoute> routes = {};
  final Map<int, List<RouteStop>> stopsByRoute = {};
  final Map<int, List<Trip>> tripsByRoute = {};
  final Map<int, Notice> notices = {};
  final Map<String, String> settings = {};

  /// Address of a picture in the server media folder (null when the folder is not set yet).
  String? mediaUrl(String file) {
    var base = settings['Media.BaseUrl'] ?? '';
    if (base.isEmpty || file.isEmpty) return null;
    if (file.startsWith('http')) return file;
    if (!base.endsWith('/')) base = '$base/';
    return '$base$file';
  }

  /// "Today's news" cards on the home screen. They are read from the file news.json in the media folder.
  List<NewsItem> news = <NewsItem>[];

  /// Home-screen sections as sent by the server (name, colour, icon, live or not).
  List<Map<String, dynamic>> sections = <Map<String, dynamic>>[];

  String? serverTime;
  DateTime? lastSync;
  String? lastError;
  bool syncing = false;

  File? _file;
  Set<int>? _served;
  final List<Map<String, dynamic>> _events = [];

  List<int> favRoutes = [];
  List<int> favTrips = [];
  List<SavedSearch> recents = [];
  List<SavedSearch> favSearches = [];

  bool get hasData => routes.isNotEmpty;

  // ------------------------------------------------------------ load / save

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/bus_cache.json');
      if (_file!.existsSync()) {
        final map = jsonDecode(await _file!.readAsString()) as Map<String, dynamic>;
        _load(map);
      }
    } catch (_) {
      // A broken cache is simply downloaded again.
      _clear();
    }
    favRoutes = app
        .getList('bus.favRoutes')
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toList();
    favTrips = app.getList('bus.favTrips').map((e) => int.tryParse(e)).whereType<int>().toList();
    recents = _readSearches('bus.recents');
    favSearches = _readSearches('bus.favSearches');
  }

  List<SavedSearch> _readSearches(String key) =>
      app.getList(key).map(SavedSearch.parse).whereType<SavedSearch>().toList();

  void _clear() {
    places.clear();
    types.clear();
    routes.clear();
    stopsByRoute.clear();
    tripsByRoute.clear();
    notices.clear();
    serverTime = null;
    lastSync = null;
    _served = null;
  }

  List<Map<String, dynamic>> _maps(dynamic v) {
    if (v is! List) return <Map<String, dynamic>>[];
    return v.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _load(Map<String, dynamic> m) {
    _clear();
    for (final j in _maps(m['places'])) {
      final p = Place(j);
      places[p.id] = p;
    }
    for (final j in _maps(m['types'])) {
      final t = BusType(j);
      types[t.id] = t;
    }
    for (final j in _maps(m['routes'])) {
      final r = BusRoute(j);
      routes[r.id] = r;
    }
    for (final j in _maps(m['stops'])) {
      final s = RouteStop(j);
      stopsByRoute.putIfAbsent(s.routeId, () => <RouteStop>[]).add(s);
    }
    for (final j in _maps(m['trips'])) {
      final t = Trip(j);
      tripsByRoute.putIfAbsent(t.routeId, () => <Trip>[]).add(t);
    }
    for (final j in _maps(m['notices'])) {
      final n = Notice(j);
      notices[n.id] = n;
    }
    sections = _maps(m['sections']);
    final st = m['settings'];
    settings.clear();
    if (st is Map) {
      st.forEach((k, v) => settings[_settingKey(k.toString())] = v.toString());
    }
    serverTime = m['serverTime'] as String?;
    final ls = m['lastSync'] as String?;
    lastSync = ls == null ? null : DateTime.tryParse(ls);
    _sortAll();
  }

  void _sortAll() {
    for (final l in stopsByRoute.values) {
      l.sort((a, b) => a.seq.compareTo(b.seq));
    }
    for (final l in tripsByRoute.values) {
      l.sort((a, b) => a.departMin.compareTo(b.departMin));
    }
    _served = null;
  }

  Future<void> _save() async {
    final f = _file;
    if (f == null) return;
    final map = <String, dynamic>{
      'v': 1,
      'serverTime': serverTime,
      'lastSync': lastSync?.toIso8601String(),
      'places': places.values.map((e) => e.raw).toList(),
      'types': types.values.map((e) => e.raw).toList(),
      'routes': routes.values.map((e) => e.raw).toList(),
      'stops': [for (final l in stopsByRoute.values) for (final s in l) s.raw],
      'trips': [for (final l in tripsByRoute.values) for (final t in l) t.raw],
      'notices': notices.values.map((e) => e.raw).toList(),
      'settings': settings,
      'sections': sections,
    };
    try {
      await f.writeAsString(jsonEncode(map));
    } catch (_) {
      // Not being able to save the copy must never break the app.
    }
  }

  // ------------------------------------------------------------------ sync

  /// Downloads when there is no data yet, or the copy is older than 30 minutes.
  Future<void> autoSync() async {
    if (!app.serverConfigured) return;
    final ls = lastSync;
    final stale = ls == null || DateTime.now().difference(ls).inMinutes >= 30;
    if (!hasData || stale) await sync();
  }

  /// [full] = throw the copy away and download everything again.
  Future<bool> sync({bool full = false}) async {
    if (syncing) return false;
    if (!app.serverConfigured) {
      lastError = app.tr('Enter the server address in Settings first.',
          'முதலில் Settings-ல் சர்வர் முகவரியை உள்ளிடவும்.');
      notifyListeners();
      return false;
    }
    syncing = true;
    lastError = null;
    notifyListeners();
    var ok = false;
    try {
      final since = (full || !hasData) ? null : serverTime;
      final q = <String, String>{};
      if (since != null) q['since'] = since;
      final j = await BusApi.get('/bus/sync', query: q) as Map<String, dynamic>;
      _apply(j, jBool(j['isFull'], false));
      serverTime = j['serverTime'] as String?;
      lastSync = DateTime.now();
      await _save();
      ok = true;
      _loadConfigQuietly();
      flushEvents();
    } catch (e) {
      lastError = BusApi.friendly(e);
    }
    syncing = false;
    notifyListeners();
    return ok;
  }

  /// The server sends setting names with a small first letter ("media.BaseUrl");
  /// the app always uses a capital first letter ("Media.BaseUrl").
  static String _settingKey(String k) => k.isEmpty ? k : k[0].toUpperCase() + k.substring(1);

  /// Settings from the server (banner pictures etc). Called every time the app opens,
  /// so a change made on the server shows up without waiting for a timetable download.
  Future<void> loadConfig() async {
    await _loadConfigQuietly();
    await _loadNews();
  }

  /// News comes from the database through the API (GET /news); the last copy is kept on the phone.
  Future<void> _loadNews() async {
    final cached = app.getString('news.json');
    if (news.isEmpty && cached != null) news = _parseNews(cached);
    try {
      final d = await BusApi.get('/news?top=5');
      final text = jsonEncode(d);
      news = _parseNews(text);
      await app.setString('news.json', text);
      notifyListeners();
    } catch (_) {
      // News is optional; keep what we have.
    }
  }

  List<NewsItem> _parseNews(String text) {
    try {
      final d = jsonDecode(text);
      if (d is! List) return <NewsItem>[];
      final out = <NewsItem>[];
      for (final e in d) {
        if (e is Map) out.add(NewsItem(Map<String, dynamic>.from(e)));
      }
      return out;
    } catch (_) {
      return <NewsItem>[];
    }
  }

  Future<void> _loadConfigQuietly() async {
    try {
      final j = await BusApi.get('/config') as Map<String, dynamic>;
      final sec = j['sections'];
      if (sec is List) sections = _maps(sec);
      final s = j['settings'];
      if (s is Map) {
        settings.clear();
        s.forEach((k, v) => settings[_settingKey(k.toString())] = v == null ? '' : v.toString());
        await _save();
        notifyListeners();
      }
    } catch (_) {
      // Optional extras; ignore.
    }
  }

  void _apply(Map<String, dynamic> j, bool full) {
    if (full) _clear();
    for (final raw in _maps(j['places'])) {
      final p = Place(raw);
      if (!p.active) {
        places.remove(p.id);
      } else {
        places[p.id] = p;
      }
    }
    for (final raw in _maps(j['busTypes'])) {
      final t = BusType(raw);
      if (!t.active) {
        types.remove(t.id);
      } else {
        types[t.id] = t;
      }
    }
    final live = <int>{};
    for (final raw in _maps(j['routes'])) {
      final r = BusRoute(raw);
      final gone = jBool(raw['isDeleted'], false) || !jBool(raw['isActive']);
      if (gone) {
        routes.remove(r.id);
        stopsByRoute.remove(r.id);
        tripsByRoute.remove(r.id);
      } else {
        routes[r.id] = r;
        live.add(r.id);
      }
    }
    for (final id in live) {
      stopsByRoute[id] = <RouteStop>[];
      tripsByRoute[id] = <Trip>[];
    }
    for (final raw in _maps(j['stops'])) {
      final s = RouteStop(raw);
      if (live.contains(s.routeId)) stopsByRoute[s.routeId]!.add(s);
    }
    for (final raw in _maps(j['trips'])) {
      final t = Trip(raw);
      if (live.contains(t.routeId)) tripsByRoute[t.routeId]!.add(t);
    }
    for (final raw in _maps(j['disruptions'])) {
      final n = Notice(raw);
      if (!n.active) {
        notices.remove(n.id);
      } else {
        notices[n.id] = n;
      }
    }
    final today = dateStr(DateTime.now());
    notices.removeWhere((id, n) => n.to.compareTo(today) < 0);
    _sortAll();
  }

  // ---------------------------------------------------------- places helpers

  Place? placeByName(String nameEn) {
    for (final p in places.values) {
      if (p.nameEn == nameEn && p.parentId == null) return p;
    }
    return null;
  }

  String placeName(int id) {
    final p = places[id];
    return p == null ? '' : p.name(app.lang);
  }

  /// The place and everything inside it (a town includes its bus stands).
  Set<int> family(int id) {
    final s = <int>{id};
    for (final p in places.values) {
      if (p.parentId == id) s.add(p.id);
    }
    for (final p in places.values) {
      final pp = p.parentId;
      if (pp != null && s.contains(pp)) s.add(p.id);
    }
    return s;
  }

  /// Map position of a place; a bus stand without its own position uses its town.
  LatLng? coordOf(int id) {
    Place? p = places[id];
    var guard = 0;
    while (p != null && guard < 3) {
      if (p.lat != null && p.lng != null) return LatLng(p.lat!, p.lng!);
      final pid = p.parentId;
      p = pid == null ? null : places[pid];
      guard++;
    }
    return null;
  }

  /// Places that have at least one bus (the stop itself and its town).
  Set<int> get servedIds {
    final cached = _served;
    if (cached != null) return cached;
    final s = <int>{};
    void addWithParents(int id) {
      Place? p = places[id];
      var guard = 0;
      s.add(id);
      while (p != null && p.parentId != null && guard < 3) {
        s.add(p.parentId!);
        p = places[p.parentId!];
        guard++;
      }
    }

    for (final r in routes.values) {
      addWithParents(r.fromId);
      addWithParents(r.toId);
      for (final st in stopsByRoute[r.id] ?? const <RouteStop>[]) {
        addWithParents(st.placeId);
      }
    }
    _served = s;
    return s;
  }

  static int _typeOrder(String t) {
    switch (t) {
      case 'Town':
        return 0;
      case 'Village':
        return 1;
      case 'BusStand':
        return 2;
      case 'BusStop':
        return 3;
      case 'RailwayStation':
        return 4;
      default:
        return 5;
    }
  }

  /// Every active place (used when someone adds a new bus and the place has no bus yet).
  List<Place> allPlaces(String query) => servedPlaces(query, all: true);

  List<Place> servedPlaces(String query, {bool all = false}) {
    final q = query.trim().toLowerCase();
    final list = <Place>[];
    final ids = all ? places.keys : servedIds;
    for (final id in ids) {
      final p = places[id];
      if (p == null || !p.active) continue;
      if (q.isNotEmpty &&
          !p.nameEn.toLowerCase().contains(q) &&
          !p.nameTa.toLowerCase().contains(q)) {
        continue;
      }
      list.add(p);
    }
    list.sort((a, b) {
      final c = _typeOrder(a.type).compareTo(_typeOrder(b.type));
      if (c != 0) return c;
      return a.nameEn.compareTo(b.nameEn);
    });
    return list;
  }

  // ------------------------------------------------------------ route helpers

  /// Start + via stops + end, in travel order.
  List<RouteStop> fullStops(BusRoute r) {
    final via = stopsByRoute[r.id] ?? const <RouteStop>[];
    return <RouteStop>[
      RouteStop.make(r.id, 0, r.fromId, 0, 0),
      ...via,
      RouteStop.make(r.id, 32767, r.toId, r.duration, r.fareTotal),
    ];
  }

  Notice? noticeFor(int routeId, int tripId, DateTime day) {
    final ds = dateStr(day);
    Notice? best;
    for (final n in notices.values) {
      if (!n.coversDate(ds)) continue;
      final match = n.tripId == tripId || (n.tripId == null && n.routeId == routeId);
      if (!match) continue;
      if (best == null || n.priority < best.priority) best = n;
    }
    return best;
  }

  List<Notice> activeNotices(DateTime day) {
    final ds = dateStr(day);
    final list = notices.values.where((n) => n.coversDate(ds)).toList();
    list.sort((a, b) {
      final c = a.priority.compareTo(b.priority);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
    return list;
  }

  /// Notices that apply to one route (the whole route or any of its trips).
  List<Notice> noticesForRoute(int routeId, DateTime day) {
    final ds = dateStr(day);
    final tripIds = (tripsByRoute[routeId] ?? const <Trip>[]).map((t) => t.id).toSet();
    return notices.values
        .where((n) =>
            n.coversDate(ds) &&
            (n.routeId == routeId || (n.tripId != null && tripIds.contains(n.tripId))))
        .toList();
  }

  // ------------------------------------------------------------------ search

  /// Buses from [fromId] to [toId] on [date]. [viaId] (optional) keeps only
  /// buses that also stop at that place between the two.
  List<BusResult> search({
    required int fromId,
    required int toId,
    int? viaId,
    required DateTime date,
    int? afterMin,
  }) {
    final famFrom = family(fromId);
    final famTo = family(toId);
    final famVia = viaId == null ? null : family(viaId);
    final out = <BusResult>[];

    for (final r in routes.values) {
      final stops = fullStops(r);
      var i0 = -1;
      var j0 = -1;
      for (var i = 0; i < stops.length && i0 < 0; i++) {
        if (!famFrom.contains(stops[i].placeId)) continue;
        for (var j = i + 1; j < stops.length; j++) {
          if (famTo.contains(stops[j].placeId)) {
            i0 = i;
            j0 = j;
            break;
          }
        }
      }
      if (i0 < 0) continue;
      if (famVia != null) {
        var hasVia = false;
        for (var k = i0 + 1; k < j0; k++) {
          if (famVia.contains(stops[k].placeId)) hasVia = true;
        }
        if (!hasVia) continue;
      }
      final a = stops[i0];
      final b = stops[j0];
      final fare = (a.fare != null && b.fare != null) ? b.fare! - a.fare! : null;
      final viaIds = <int>[for (var k = i0 + 1; k < j0; k++) stops[k].placeId];
      out.addAll(_expandTrips(r, a.offset, b.offset, a.placeId, b.placeId, fare,
          viaIds, date, afterMin));
    }
    out.sort((x, y) {
      final c = x.departsMin.compareTo(y.departsMin);
      return c != 0 ? c : x.arrivesMin.compareTo(y.arrivesMin);
    });
    return out;
  }

  List<BusResult> _expandTrips(BusRoute r, int fromOffset, int toOffset, int fromPlace,
      int toPlace, double? fare, List<int> viaIds, DateTime date, int? afterMin) {
    final out = <BusResult>[];
    for (final t in tripsByRoute[r.id] ?? const <Trip>[]) {
      // shift 1 = the bus that left yesterday and passes this stop after midnight
      for (var shift = 0; shift <= 1; shift++) {
        final day = DateTime(date.year, date.month, date.day - shift);
        if (!t.runsOn(day)) continue;
        final dep = t.departMin + fromOffset - 1440 * shift;
        if (dep < 0 || dep >= 1440) continue;
        if (afterMin != null && dep < afterMin) continue;
        final n = noticeFor(r.id, t.id, day);
        out.add(BusResult(
          route: r,
          trip: t,
          fromPlaceId: fromPlace,
          toPlaceId: toPlace,
          departsMin: dep,
          arrivesMin: t.departMin + toOffset - 1440 * shift,
          durationMin: toOffset - fromOffset,
          fare: fare,
          viaIds: viaIds,
          status: n == null ? 'OnTime' : n.kind,
          delay: n?.delay,
          notice: n,
          serviceDate: day,
        ));
      }
    }
    return out;
  }

  /// Bus-stand board: every bus that leaves [placeId], with its final stop.
  List<BusResult> departures({
    required int placeId,
    required DateTime date,
    int? afterMin,
  }) {
    final fam = family(placeId);
    final out = <BusResult>[];
    for (final r in routes.values) {
      final stops = fullStops(r);
      var i0 = -1;
      for (var i = 0; i < stops.length - 1; i++) {
        if (fam.contains(stops[i].placeId)) {
          i0 = i;
          break;
        }
      }
      if (i0 < 0) continue;
      final a = stops[i0];
      final viaIds = <int>[for (var k = i0 + 1; k < stops.length - 1; k++) stops[k].placeId];
      out.addAll(_expandTrips(r, a.offset, r.duration, a.placeId, r.toId, null, viaIds,
          date, afterMin));
    }
    out.sort((x, y) => x.departsMin.compareTo(y.departsMin));
    return out;
  }

  // ------------------------------------------------ favourites and history

  bool isFavRoute(int id) => favRoutes.contains(id);

  /// A saved timing = one departure of one bus (so tapping a heart marks only that card).
  bool isFavTrip(int tripId) => favTrips.contains(tripId);

  Future<void> toggleFavTrip(int tripId) async {
    if (favTrips.contains(tripId)) {
      favTrips.remove(tripId);
    } else {
      favTrips.insert(0, tripId);
    }
    await app.setList('bus.favTrips', favTrips.map((e) => e.toString()).toList());
    notifyListeners();
  }

  Trip? tripById(int tripId) {
    for (final list in tripsByRoute.values) {
      for (final t in list) {
        if (t.id == tripId) return t;
      }
    }
    return null;
  }

  Future<void> toggleFavRoute(int id) async {
    if (favRoutes.contains(id)) {
      favRoutes.remove(id);
    } else {
      favRoutes.insert(0, id);
    }
    await app.setList('bus.favRoutes', favRoutes.map((e) => e.toString()).toList());
    notifyListeners();
  }

  bool isFavSearch(SavedSearch s) => favSearches.any((e) => e.key == s.key);

  Future<void> toggleFavSearch(SavedSearch s) async {
    if (isFavSearch(s)) {
      favSearches.removeWhere((e) => e.key == s.key);
    } else {
      favSearches.insert(0, s);
    }
    await app.setList('bus.favSearches', favSearches.map((e) => e.key).toList());
    notifyListeners();
  }

  Future<void> addRecent(SavedSearch s) async {
    recents.removeWhere((e) => e.key == s.key);
    recents.insert(0, s);
    if (recents.length > 6) recents = recents.sublist(0, 6);
    await app.setList('bus.recents', recents.map((e) => e.key).toList());
    notifyListeners();
  }

  // ----------------------------------------------------------- usage events

  /// Remembers what people use (which search, which screen). Sent in batches.
  void logEvent(String type, {String? entityType, int? entityId, String? detail}) {
    _events.add(<String, dynamic>{
      'eventType': type,
      'sectionKey': 'bus',
      'entityType': entityType,
      'entityId': entityId,
      'detail': detail,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    if (_events.length >= 15) flushEvents();
  }

  Future<void> flushEvents() async {
    if (_events.isEmpty || !app.serverConfigured) return;
    final batch = List<Map<String, dynamic>>.of(_events);
    _events.clear();
    try {
      await BusApi.post('/events', <String, dynamic>{'deviceId': app.deviceId, 'events': batch});
    } catch (_) {
      // Keep them for the next try, but never grow without limit.
      if (_events.length < 100) _events.insertAll(0, batch);
    }
  }

  Future<void> registerDevice() async {
    if (!app.serverConfigured) return;
    try {
      await BusApi.post('/devices', <String, dynamic>{
        'deviceId': app.deviceId,
        'platform': 'android',
        'appVersion': kAppVersion,
        'language': app.lang,
      });
    } catch (_) {
      // Optional; ignore.
    }
  }
}

final BusRepo repo = BusRepo();
