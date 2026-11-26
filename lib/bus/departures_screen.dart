import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
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
          backgroundColor: kBusBg,
          body: Column(
            children: [
              BusHeader(
                title: app.tr('Bus stand board', 'பேருந்து நிலைய பலகை'),
                subtitle: app.tr('Buses leaving from one place', 'ஒரு இடத்திலிருந்து புறப்படும் பேருந்துகள்'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: _pickPlace,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE3EAF6))),
                        child: Row(
                          children: [
                            const IconBubble(Icons.departure_board_rounded, size: 40),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app.tr('Buses leaving from', 'புறப்படும் இடம்'), style: ts(bs(12), color: kMuted, weight: FontWeight.w600)),
                                  Text(repo.placeName(_placeId), style: ts(bs(17), weight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            const Icon(Icons.expand_more_rounded, color: kBrand),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    LightDateStrip(
                      date: _date,
                      isToday: isToday,
                      canPrev: canPrev,
                      canNext: canNext,
                      onPrev: () => _shift(-1),
                      onNext: () => _shift(1),
                    ),
                    if (isToday) ...[
                      const SizedBox(height: 12),
                      SegTabs(
                        labels: [app.tr('From now', 'இப்போதிலிருந்து'), app.tr('Whole day', 'நாள் முழுவதும்')],
                        selected: _fromNow ? 0 : 1,
                        onSelect: (i) => setState(() => _fromNow = i == 0),
                      ),
                    ],
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
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE3EAF6))),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: kBrand.withAlpha(24), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Text(
                    fmtClock(b.departsMin).substring(0, 5),
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: kBrand,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(fmtClock(b.departsMin).substring(6), style: ts(12, weight: FontWeight.w800, color: kBrand)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(repo.placeName(b.toPlaceId), style: ts(bs(16), weight: FontWeight.w900)),
                  if (via.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('${app.tr('via', 'வழி')} $via', style: ts(bs(12.5), color: kMuted)),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (r.typeId != null) Pill(typeName(r.typeId), color: typeColor(r.typeId)),
                      if (b.trip.platform.isNotEmpty) Pill('${app.tr('Platform', 'நடைமேடை')} ${b.trip.platform}', color: kMuted),
                      StatusBadge(b.status, delay: b.delay),
                    ],
                  ),
                ],
              ),
            ),
            const Padding(padding: EdgeInsets.only(top: 10), child: Icon(Icons.chevron_right_rounded, color: kMuted)),
          ],
        ),
        ),
          ),
        ),
      ),
    );
  }
}
