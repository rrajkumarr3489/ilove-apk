import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'bus_models.dart';
import 'bus_repo.dart';
import 'bus_widgets.dart';
import 'place_picker_screen.dart';
import 'route_detail_screen.dart';

/// Bus-stand board: every bus that leaves a place on one day, with where it goes.
class DeparturesScreen extends StatefulWidget {
  final int placeId;

  const DeparturesScreen({super.key, required this.placeId});

  @override
  State<DeparturesScreen> createState() => _DeparturesScreenState();
}

class _DeparturesScreenState extends State<DeparturesScreen> {
  late int _placeId;
  DateTime _date = dayOnly(DateTime.now());
  bool _fromNow = true;

  @override
  void initState() {
    super.initState();
    _placeId = widget.placeId;
  }

  int get _maxDays => int.tryParse(repo.settings['Bus.SearchDaysAhead'] ?? '') ?? 14;

  Future<void> _pickPlace() async {
    final p = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => PlacePickerScreen(title: app.tr('Choose bus stand / town', 'நிலையம் / ஊரைத் தேர்வு செய்'))),
    );
    if (p != null) setState(() => _placeId = p.id);
  }

  void _shift(int d) => setState(() => _date = _date.add(Duration(days: d)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: busListen,
      builder: (context, _) {
        final now = DateTime.now();
        final today = dayOnly(now);
        final isToday = sameDay(_date, today);
        final after = (_fromNow && isToday) ? now.hour * 60 + now.minute : null;
        final list = repo.departures(placeId: _placeId, date: _date, afterMin: after);
        final canPrev = _date.isAfter(today);
        final canNext = _date.isBefore(today.add(Duration(days: _maxDays)));
        return Scaffold(
          appBar: AppBar(title: Text(app.tr('Bus stand board', 'பேருந்து நிலைய பலகை'))),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SoftCard(
                  onTap: _pickPlace,
                  child: Row(
                    children: [
                      const Icon(Icons.departure_board, color: kBrand),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(app.tr('Buses leaving from', 'புறப்படும் இடம்'), style: ts(12, color: kMuted)),
                            Text(repo.placeName(_placeId), style: ts(18, weight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: canPrev ? () => _shift(-1) : null),
                  Expanded(
                    child: Text(
                      isToday ? '${fmtDate(_date)} · ${app.tr('Today', 'இன்று')}' : fmtDate(_date),
                      textAlign: TextAlign.center,
                      style: ts(15.5, weight: FontWeight.w800),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: canNext ? () => _shift(1) : null),
                ],
              ),
              if (isToday)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(app.tr('From now', 'இப்போதிலிருந்து')),
                        selected: _fromNow,
                        onSelected: (_) => setState(() => _fromNow = true),
                      ),
                      ChoiceChip(
                        label: Text(app.tr('Whole day', 'நாள் முழுவதும்')),
                        selected: !_fromNow,
                        onSelected: (_) => setState(() => _fromNow = false),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: list.isEmpty
                    ? EmptyState(
                        icon: Icons.departure_board,
                        title: app.tr('No buses', 'பேருந்துகள் இல்லை'),
                        message: app.tr('No bus leaves from here at this time.', 'இந்த நேரத்தில் இங்கிருந்து பேருந்து புறப்படவில்லை.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _Row(result: list[i], placeId: _placeId),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  final BusResult result;
  final int placeId;

  const _Row({required this.result, required this.placeId});

  @override
  Widget build(BuildContext context) {
    final b = result;
    final r = b.route;
    final cancelled = b.status == 'Cancelled';
    final via = viaText(b.viaIds, max: 3);
    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: SoftCard(
        margin: const EdgeInsets.only(bottom: 10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteDetailScreen(
              routeId: r.id,
              tripId: b.trip.id,
              date: b.serviceDate,
              boardId: placeId,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 88,
              child: Text(
                fmtClock(b.departsMin),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: kInk,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(repo.placeName(b.toPlaceId), style: ts(15.5, weight: FontWeight.w800)),
                  if (via.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${app.tr('via', 'வழி')} $via', style: ts(12.5, color: kMuted)),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (r.typeId != null) Pill(typeName(r.typeId), color: typeColor(r.typeId)),
                      if (b.trip.platform.isNotEmpty)
                        Pill('${app.tr('Platform', 'நடைமேடை')} ${b.trip.platform}', color: kMuted),
                      StatusBadge(b.status, delay: b.delay),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
