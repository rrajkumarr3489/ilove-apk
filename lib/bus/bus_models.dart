// Plain data classes for the bus module. Each keeps the original server JSON
// (`raw`) so the offline copy can be saved exactly as received.

int jInt(dynamic v, [int d = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? d;
  return d;
}

int? jIntN(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? jDblN(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String jStr(dynamic v) => v == null ? '' : v.toString();

bool jBool(dynamic v, [bool d = true]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return d;
}

/// "06:15" -> 375
int clockToMin(String? s) {
  if (s == null || s.length < 4) return 0;
  final p = s.split(':');
  final h = int.tryParse(p[0]) ?? 0;
  final m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
  return h * 60 + m;
}

String dateStr(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

class Place {
  final Map<String, dynamic> raw;
  final int id;
  final String type;
  final String nameEn;
  final String nameTa;
  final int? parentId;
  final double? lat;
  final double? lng;
  final bool active;

  Place(Map<String, dynamic> j)
      : raw = j,
        id = jInt(j['placeId']),
        type = jStr(j['placeType']),
        nameEn = jStr(j['nameEn']),
        nameTa = jStr(j['nameTa']),
        parentId = jIntN(j['parentPlaceId']),
        lat = jDblN(j['latitude']),
        lng = jDblN(j['longitude']),
        active = jBool(j['isActive']);

  String name(String lang) =>
      (lang == 'ta' && nameTa.isNotEmpty) ? nameTa : nameEn;
}

class BusType {
  final Map<String, dynamic> raw;
  final int id;
  final String nameEn;
  final String nameTa;
  final String colorHex;
  final int sort;
  final bool active;

  BusType(Map<String, dynamic> j)
      : raw = j,
        id = jInt(j['categoryId']),
        nameEn = jStr(j['nameEn']),
        nameTa = jStr(j['nameTa']),
        colorHex = jStr(j['colorHex']),
        sort = jInt(j['sortOrder']),
        active = jBool(j['isActive']);

  String name(String lang) =>
      (lang == 'ta' && nameTa.isNotEmpty) ? nameTa : nameEn;
}

class BusRoute {
  final Map<String, dynamic> raw;
  final int id;
  final String routeNo;
  final int? typeId;
  final String operatorEn;
  final String operatorTa;
  final int fromId;
  final int toId;
  final int duration;
  final double? distanceKm;
  final double? fareTotal;
  final String notesEn;
  final String notesTa;

  BusRoute(Map<String, dynamic> j)
      : raw = j,
        id = jInt(j['busRouteId']),
        routeNo = jStr(j['routeNo']),
        typeId = jIntN(j['busTypeId']),
        operatorEn = jStr(j['operatorEn']),
        operatorTa = jStr(j['operatorTa']),
        fromId = jInt(j['fromPlaceId']),
        toId = jInt(j['toPlaceId']),
        duration = jInt(j['durationMinutes']),
        distanceKm = jDblN(j['distanceKm']),
        fareTotal = jDblN(j['fareTotal']),
        notesEn = jStr(j['notesEn']),
        notesTa = jStr(j['notesTa']);

  String operatorName(String lang) =>
      (lang == 'ta' && operatorTa.isNotEmpty) ? operatorTa : operatorEn;

  String notes(String lang) =>
      (lang == 'ta' && notesTa.isNotEmpty) ? notesTa : notesEn;
}

class RouteStop {
  final Map<String, dynamic> raw;
  final int routeId;
  final int seq;
  final int placeId;
  final int offset;
  final double? fare;

  RouteStop(Map<String, dynamic> j)
      : raw = j,
        routeId = jInt(j['busRouteId']),
        seq = jInt(j['stopSeq']),
        placeId = jInt(j['placeId']),
        offset = jInt(j['minutesFromStart']),
        fare = jDblN(j['fareFromStart']);

  /// Start and end of a route are not stored as stops; they are built here.
  RouteStop.make(this.routeId, this.seq, this.placeId, this.offset, this.fare)
      : raw = const <String, dynamic>{};
}

class Trip {
  final Map<String, dynamic> raw;
  final int id;
  final int routeId;
  final int departMin;
  final int mask;
  final String platform;
  final String tagEn;
  final String tagTa;
  final String? validFrom;
  final String? validTo;

  Trip(Map<String, dynamic> j)
      : raw = j,
        id = jInt(j['busTripId']),
        routeId = jInt(j['busRouteId']),
        departMin = clockToMin(jStr(j['departTime'])),
        mask = jInt(j['daysMask'], 127),
        platform = jStr(j['platformNo']),
        tagEn = jStr(j['tagEn']),
        tagTa = jStr(j['tagTa']),
        validFrom = j['validFrom'] == null ? null : jStr(j['validFrom']),
        validTo = j['validTo'] == null ? null : jStr(j['validTo']);

  String tag(String lang) => (lang == 'ta' && tagTa.isNotEmpty) ? tagTa : tagEn;

  /// Does this trip run on the given calendar day?
  bool runsOn(DateTime d) {
    final bit = 1 << (d.weekday - 1); // Monday = 1 ... Sunday = 64
    if ((mask & bit) == 0) return false;
    final s = dateStr(d);
    if (validFrom != null && validFrom!.compareTo(s) > 0) return false;
    if (validTo != null && validTo!.compareTo(s) < 0) return false;
    return true;
  }
}

class Notice {
  final Map<String, dynamic> raw;
  final int id;
  final int? routeId;
  final int? tripId;
  final String kind; // Cancelled, Delayed, Diverted, Info
  final int? delay;
  final String msgEn;
  final String msgTa;
  final String from;
  final String to;
  final bool active;

  Notice(Map<String, dynamic> j)
      : raw = j,
        id = jInt(j['disruptionId']),
        routeId = jIntN(j['busRouteId']),
        tripId = jIntN(j['busTripId']),
        kind = jStr(j['kind']),
        delay = jIntN(j['delayMinutes']),
        msgEn = jStr(j['messageEn']),
        msgTa = jStr(j['messageTa']),
        from = jStr(j['fromDate']),
        to = jStr(j['toDate']),
        active = jBool(j['isActive']);

  String msg(String lang) => (lang == 'ta' && msgTa.isNotEmpty) ? msgTa : msgEn;

  int get priority {
    switch (kind) {
      case 'Cancelled':
        return 0;
      case 'Delayed':
        return 1;
      case 'Diverted':
        return 2;
      default:
        return 3;
    }
  }

  bool coversDate(String ds) => from.compareTo(ds) <= 0 && to.compareTo(ds) >= 0;
}

/// One bus line in a search result or a bus-stand board.
class BusResult {
  final BusRoute route;
  final Trip trip;
  final int fromPlaceId;
  final int toPlaceId;
  final int departsMin;
  final int arrivesMin;
  final int durationMin;
  final double? fare;
  final List<int> viaIds;
  final String status; // OnTime, Cancelled, Delayed, Diverted, Info
  final int? delay;
  final Notice? notice;
  final DateTime serviceDate;

  const BusResult({
    required this.route,
    required this.trip,
    required this.fromPlaceId,
    required this.toPlaceId,
    required this.departsMin,
    required this.arrivesMin,
    required this.durationMin,
    required this.fare,
    required this.viaIds,
    required this.status,
    required this.delay,
    required this.notice,
    required this.serviceDate,
  });
}

class SavedSearch {
  final int fromId;
  final int toId;
  final int? viaId;

  const SavedSearch(this.fromId, this.toId, this.viaId);

  String get key => '$fromId|$toId|${viaId ?? 0}';

  static SavedSearch? parse(String s) {
    final p = s.split('|');
    if (p.length != 3) return null;
    final a = int.tryParse(p[0]);
    final b = int.tryParse(p[1]);
    final c = int.tryParse(p[2]);
    if (a == null || b == null || c == null) return null;
    return SavedSearch(a, b, c == 0 ? null : c);
  }
}

/// One card in "Today's news" (from the server: Tamil and English are stored separately).
class NewsItem {
  final String title;
  final String titleTa;
  final String date;
  final String image;
  final String link;

  NewsItem(Map<String, dynamic> j)
      : title = jStr(j['titleEn']),
        titleTa = jStr(j['titleTa']),
        date = _niceDate(jStr(j['publishedOn'])),
        image = jStr(j['imageFile']),
        link = jStr(j['linkUrl']);

  static String _niceDate(String iso) {
    final d = DateTime.tryParse(iso.length >= 10 ? iso.substring(0, 10) : iso);
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${m[d.month - 1]} ${d.year}';
  }

  /// The language the person picked; falls back to the other one when that title is empty.
  String name(String lang) {
    if (lang == 'ta') return titleTa.isNotEmpty ? titleTa : title;
    return title.isNotEmpty ? title : titleTa;
  }
}
