import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../theme.dart';
import 'bus_models.dart';
import 'bus_repo.dart';
import 'bus_submit_screens.dart';
import 'bus_widgets.dart';
import 'maps_util.dart';

/// One bus line: every stop with its time, trip chooser, notices and a map.
class RouteDetailScreen extends StatefulWidget {
  final int routeId;
  final int? tripId;
  final DateTime date;
  final int? boardId;
  final int? alightId;

  const RouteDetailScreen({
    super.key,
    required this.routeId,
    this.tripId,
    required this.date,
    this.boardId,
    this.alightId,
  });

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  int? _tripId;
  bool _map = false;

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
  }

  Trip? _selected(List<Trip> running, List<Trip> all) {
    for (final t in all) {
      if (t.id == _tripId) return t;
    }
    if (running.isNotEmpty) return running.first;
    return all.isEmpty ? null : all.first;
  }

  String _copyText(BusRoute r, List<RouteStop> stops, Trip? t) {
    final sb = StringBuffer();
    sb.writeln('${routeTitle(r)}  (${typeName(r.typeId)} ${r.routeNo})'.trim());
    sb.writeln(fmtDate(widget.date));
    for (final s in stops) {
      final time = t == null ? '' : '${fmtClock(t.departMin + s.offset)}  ';
      sb.writeln('$time${repo.placeName(s.placeId)}');
    }
    sb.write('I Love APK');
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: busListen,
      builder: (context, _) {
        final r = repo.routes[widget.routeId];
        if (r == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.directions_bus_outlined,
              title: app.tr('This route is not available any more', 'இந்தப் பாதை இப்போது இல்லை'),
            ),
          );
        }
        final all = repo.tripsByRoute[r.id] ?? <Trip>[];
        final running = all.where((t) => t.runsOn(widget.date)).toList();
        final sel = _selected(running, all);
        final stops = repo.fullStops(r);
        final notices = repo.noticesForRoute(r.id, widget.date);
        final fav = repo.isFavRoute(r.id);

        int bi = -1;
        int ai = -1;
        if (widget.boardId != null) {
          final fb = repo.family(widget.boardId!);
          for (var i = 0; i < stops.length && bi < 0; i++) {
            if (fb.contains(stops[i].placeId)) bi = i;
          }
          if (bi >= 0 && widget.alightId != null) {
            final fa = repo.family(widget.alightId!);
            for (var j = bi + 1; j < stops.length && ai < 0; j++) {
              if (fa.contains(stops[j].placeId)) ai = j;
            }
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(app.tr('Bus details', 'பேருந்து விவரம்')),
            actions: [
              IconButton(
                tooltip: app.tr('Copy', 'நகலெடு'),
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _copyText(r, stops, sel)));
                  if (context.mounted) showMsg(context, app.tr('Copied. You can paste it in WhatsApp.', 'நகலெடுக்கப்பட்டது. WhatsApp-ல் ஒட்டலாம்.'));
                },
              ),
              IconButton(
                tooltip: app.tr('Save', 'சேமி'),
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? kRed : null),
                onPressed: () => repo.toggleFavRoute(r.id),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              _header(r),
              const SizedBox(height: 12),
              for (final n in notices) NoticeTile(n),
              SectionTitle(app.tr('Departure from ${repo.placeName(r.fromId)}', '${repo.placeName(r.fromId)} புறப்பாடு')),
              _tripChips(running, all, sel),
              const SizedBox(height: 14),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.timeline),
                    label: Text(app.tr('Stops', 'நிறுத்தங்கள்')),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.map_outlined),
                    label: Text(app.tr('Map', 'வரைபடம்')),
                  ),
                ],
                selected: <bool>{_map},
                onSelectionChanged: (s) => setState(() => _map = s.first),
              ),
              const SizedBox(height: 14),
              if (_map) _mapView(stops) else _timeline(stops, sel, bi, ai),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: OutlinedButton.icon(
                  onPressed: () => openAddTiming(context, r.id),
                  icon: const Icon(Icons.add_alarm),
                  label: Text(app.tr('Add a timing for this bus', 'இந்த பேருந்துக்கு நேரம் சேர்')),
                ),
              ),
              if (r.notes(app.lang).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SoftCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: kBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.notes(app.lang), style: ts(13.5, height: 1.4))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BusRoute r) {
    final operatorName = r.operatorName(app.lang);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [kNavy, kBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(repo.placeName(r.fromId), style: ts(14, color: const Color(0xFFBFD8EE), weight: FontWeight.w600)),
          Text(routeTitle(r), style: ts(20, weight: FontWeight.w900, color: Colors.white, height: 1.2)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (r.typeId != null) Pill(typeName(r.typeId), color: typeColor(r.typeId), filled: true),
              if (r.routeNo.isNotEmpty) Pill(r.routeNo, color: Colors.white, icon: Icons.tag),
              if (operatorName.isNotEmpty) Pill(operatorName, color: Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric(Icons.schedule, fmtDur(r.duration)),
              if (r.fareTotal != null) _metric(Icons.payments_outlined, fmtFare(r.fareTotal)),
              if (r.distanceKm != null) _metric(Icons.route, '${r.distanceKm!.toStringAsFixed(0)} km'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFFBFD8EE)),
          const SizedBox(width: 5),
          Text(text, style: ts(14, weight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _tripChips(List<Trip> running, List<Trip> all, Trip? sel) {
    final list = running.isNotEmpty ? running : all;
    if (list.isEmpty) {
      return Text(app.tr('No trips are listed for this route.', 'இந்தப் பாதைக்கு நேரங்கள் பட்டியலில் இல்லை.'),
          style: ts(14, color: kMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (running.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
                app.tr('No bus on ${fmtDate(widget.date)}. These are the other days\' timings.',
                    '${fmtDate(widget.date)} அன்று பேருந்து இல்லை. மற்ற நாட்களின் நேரங்கள் இவை.'),
                style: ts(12.5, color: kMuted)),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final t in list)
              ChoiceChip(
                label: Text(fmtClock(t.departMin)),
                selected: sel != null && sel.id == t.id,
                onSelected: (_) => setState(() => _tripId = t.id),
              ),
          ],
        ),
      ],
    );
  }

  Widget _timeline(List<RouteStop> stops, Trip? t, int bi, int ai) {
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        children: [
          for (var i = 0; i < stops.length; i++) _stopRow(stops, i, t, bi, ai),
        ],
      ),
    );
  }

  Widget _stopRow(List<RouteStop> stops, int i, Trip? t, int bi, int ai) {
    final s = stops[i];
    final first = i == 0;
    final last = i == stops.length - 1;
    final isBoard = i == bi;
    final isAlight = i == ai;
    final dim = bi >= 0 && ai >= 0 && (i < bi || i > ai);
    final Color dot = first ? kGreen : (last ? kRed : (isBoard || isAlight ? kBrand : kBlue));
    String time = '--';
    if (t != null) {
      final m = t.departMin + s.offset;
      time = fmtClock(m);
      if (m >= 1440) time = '$time +${m ~/ 1440}';
    }
    final kind = first
        ? app.tr('Start', 'தொடக்கம்')
        : (last ? app.tr('End', 'முடிவு') : app.tr('Via', 'வழி'));
    final fare = (s.fare != null && !first && s.fare! > 0) ? '  ·  ${fmtFare(s.fare)}' : '';
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 92,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(time, style: ts(13.5, weight: FontWeight.w800)),
              ),
            ),
            SizedBox(
              width: 22,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: (isBoard || isAlight) ? dot : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: dot, width: 3),
                    ),
                  ),
                  if (!last) Expanded(child: Container(width: 2, color: kLine)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.placeName(s.placeId), style: ts(15, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('$kind$fare', style: ts(12.5, color: kMuted)),
                        if (isBoard) Pill(app.tr('Board here', 'இங்கு ஏறவும்'), color: kBrand, filled: true),
                        if (isAlight) Pill(app.tr('Get down here', 'இங்கு இறங்கவும்'), color: kBrand, filled: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView(List<RouteStop> stops) {
    final points = <LatLng>[];
    final markers = <Marker>[];
    for (var i = 0; i < stops.length; i++) {
      final p = repo.coordOf(stops[i].placeId);
      if (p == null) continue;
      points.add(p);
      final first = i == 0;
      final last = i == stops.length - 1;
      markers.add(Marker(
        point: p,
        width: 30,
        height: 30,
        child: Container(
          decoration: BoxDecoration(
            color: first ? kGreen : (last ? kRed : kBlue),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text('${i + 1}', style: ts(12, weight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ));
    }
    if (points.length < 2) {
      return SoftCard(
        child: Column(
          children: [
            const Icon(Icons.map_outlined, color: kMuted, size: 36),
            const SizedBox(height: 8),
            Text(
              app.tr('The map needs locations for the places on this route. They are added by the admin.',
                  'இந்தப் பாதையின் இடங்களுக்கு வரைபட இடம் தேவை. அவை நிர்வாகியால் சேர்க்கப்படும்.'),
              textAlign: TextAlign.center,
              style: ts(13.5, color: kMuted, height: 1.4),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 340,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: points.first,
                    initialZoom: 9,
                    initialCameraFit: CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(points),
                      padding: const EdgeInsets.all(44),
                    ),
                  ),
                  children: [
                    TileLayer(urlTemplate: kTileUrl, userAgentPackageName: kTileAgent),
                    PolylineLayer(polylines: [Polyline(points: points, strokeWidth: 4, color: kBlue)]),
                    MarkerLayer(markers: markers),
                  ],
                ),
                Positioned(
                  left: 6,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white70,
                    child: Text('© OpenStreetMap contributors', style: ts(10, color: kMuted)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => openDirections(context, points),
            icon: const Icon(Icons.map, size: 18),
            label: Text(app.tr('Open in Google Maps', 'Google Maps-ல் திற')),
          ),
        ),
      ],
    );
  }
}
