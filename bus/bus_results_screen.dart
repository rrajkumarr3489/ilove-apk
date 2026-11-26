import 'package:flutter/material.dart';

import '../app_state.dart';
import '../screen_header.dart';
import '../theme.dart';
import 'bus_models.dart';
import 'bus_repo.dart';
import 'bus_widgets.dart';
import 'route_detail_screen.dart';

/// List of buses for From -> To (and optional Via) on one day.
class BusResultsScreen extends StatefulWidget {
  final int fromId;
  final int toId;
  final int? viaId;
  final DateTime date;

  const BusResultsScreen({
    super.key,
    required this.fromId,
    required this.toId,
    required this.viaId,
    required this.date,
  });

  @override
  State<BusResultsScreen> createState() => _BusResultsScreenState();
}

class _BusResultsScreenState extends State<BusResultsScreen> {
  late DateTime _date;
  bool _fromNow = true;

  @override
  void initState() {
    super.initState();
    _date = dayOnly(widget.date);
  }

  int get _maxDays => int.tryParse(repo.settings['Bus.SearchDaysAhead'] ?? '') ?? 14;

  SavedSearch get _saved => SavedSearch(widget.fromId, widget.toId, widget.viaId);

  void _shift(int days) => setState(() => _date = _date.add(Duration(days: days)));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: busListen,
      builder: (context, _) {
        final now = DateTime.now();
        final today = dayOnly(now);
        final isToday = sameDay(_date, today);
        final after = (_fromNow && isToday) ? now.hour * 60 + now.minute : null;
        final results = repo.search(
          fromId: widget.fromId,
          toId: widget.toId,
          viaId: widget.viaId,
          date: _date,
          afterMin: after,
        );
        final fav = repo.isFavSearch(_saved);
        final canPrev = _date.isAfter(today);
        final canNext = _date.isBefore(today.add(Duration(days: _maxDays)));
        return Scaffold(
          body: Column(
            children: [
              BusHeader(
                title: '${repo.placeName(widget.fromId)} → ${repo.placeName(widget.toId)}',
                subtitle: app.tr('${results.length} bus(es) found', '${results.length} பேருந்து(கள்) கிடைத்தன'),
                actions: [
                  HeaderButton(
                    tooltip: app.tr('Save this search', 'இந்தத் தேடலைச் சேமி'),
                    icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: fav ? kRed : kInk,
                    onTap: () => repo.toggleFavSearch(_saved),
                  ),
                ],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DateStrip(
                      date: _date,
                      isToday: isToday,
                      canPrev: canPrev,
                      canNext: canNext,
                      onPrev: () => _shift(-1),
                      onNext: () => _shift(1),
                    ),
                    if (isToday || widget.viaId != null) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isToday) HeaderChip(app.tr('From now', 'இப்போதிலிருந்து'), on: _fromNow, onTap: () => setState(() => _fromNow = true)),
                          if (isToday) HeaderChip(app.tr('Whole day', 'நாள் முழுவதும்'), on: !_fromNow, onTap: () => setState(() => _fromNow = false)),
                          if (widget.viaId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(color: Colors.white.withAlpha(40), borderRadius: BorderRadius.circular(30)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.alt_route, size: 15, color: Colors.white),
                                const SizedBox(width: 5),
                                Text('${app.tr('Via', 'வழி')}: ${repo.placeName(widget.viaId!)}', style: ts(12.5, weight: FontWeight.w800, color: Colors.white)),
                              ]),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _empty(isToday, canNext)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: results.length + 1,
                        itemBuilder: (context, i) {
                          if (i == results.length) return _footer();
                          return _ResultCard(result: results[i]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _footer() {
    final text = app.tr(repo.settings['Bus.DisclaimerEn'] ?? '', repo.settings['Bus.DisclaimerTa'] ?? '');
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, textAlign: TextAlign.center, style: ts(12, color: kMuted, height: 1.4)),
    );
  }

  Widget _empty(bool isToday, bool canNext) {
    final hints = <String>[];
    if (widget.viaId != null) {
      hints.add(app.tr('Remove the via stop to see more buses.', 'வழி இடத்தை நீக்கினால் மேலும் பேருந்துகள் தெரியும்.'));
    }
    return EmptyState(
      icon: Icons.directions_bus_outlined,
      title: app.tr('No buses found', 'பேருந்துகள் எதுவும் இல்லை'),
      message: hints.isEmpty
          ? app.tr('No bus is listed for this day and time.', 'இந்த நாள், நேரத்திற்கு பேருந்து பட்டியலில் இல்லை.')
          : hints.join(' '),
      action: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (isToday && _fromNow)
            OutlinedButton(
              onPressed: () => setState(() => _fromNow = false),
              child: Text(app.tr('Show whole day', 'நாள் முழுவதும் காட்டு')),
            ),
          if (canNext)
            FilledButton(
              onPressed: () => _shift(1),
              child: Text(app.tr('Check next day', 'அடுத்த நாள் பார்')),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final BusResult result;

  const _ResultCard({required this.result});

  Widget _stopRow(IconData icon, Color color, String name) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w700))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = result;
    final r = b.route;
    final cancelled = b.status == 'Cancelled';
    final arriveDay = b.arrivesMin ~/ 1440;
    final via = viaText(b.viaIds);
    final tag = b.trip.tag(app.lang);
    final fav = repo.isFavTrip(b.trip.id);
    final accent = r.typeId != null ? typeColor(r.typeId) : kBrand;
    final typeLabel = r.typeId != null ? typeName(r.typeId) : '';
    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(accent.withAlpha(12), Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withAlpha(70)),
        ),
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
                  boardId: b.fromPlaceId,
                  alightId: b.toPlaceId,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: accent.withAlpha(30), shape: BoxShape.circle),
                        child: Icon(Icons.directions_bus_rounded, color: accent, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (typeLabel.isNotEmpty) Text(typeLabel, style: ts(13, weight: FontWeight.w800, color: accent)),
                            const SizedBox(height: 3),
                            _stopRow(Icons.trip_origin, kGreen, repo.placeName(b.fromPlaceId)),
                            Padding(
                              padding: const EdgeInsets.only(left: 7),
                              child: Container(width: 2, height: 9, margin: const EdgeInsets.symmetric(vertical: 1), color: kLine),
                            ),
                            _stopRow(Icons.location_on, kRed, repo.placeName(b.toPlaceId)),
                            if (r.routeNo.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(r.routeNo, style: ts(12.5, weight: FontWeight.w800, color: accent)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmtClock(b.departsMin),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: kBrand,
                              decoration: cancelled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            arriveDay > 0 ? '${fmtClock(b.arrivesMin)} +$arriveDay' : fmtClock(b.arrivesMin),
                            style: ts(14, weight: FontWeight.w600, color: kMuted),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 13, color: kMuted),
                              const SizedBox(width: 3),
                              Text(fmtDur(b.durationMin), style: ts(11.5, color: kMuted, weight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? kRed : kMuted, size: 23),
                        onPressed: () => repo.toggleFavTrip(b.trip.id),
                      ),
                    ],
                  ),
                  if (b.trip.platform.isNotEmpty || b.fare != null || const ['Cancelled', 'Delayed', 'Diverted', 'Info'].contains(b.status))
                    Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (b.trip.platform.isNotEmpty) Pill('${app.tr('Platform', 'நடைமேடை')} ${b.trip.platform}', color: kMuted),
                          if (b.fare != null) Pill(fmtFare(b.fare), color: kGreen, icon: Icons.payments_outlined),
                          StatusBadge(b.status, delay: b.delay),
                        ],
                      ),
                    ),
                  if (via.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Text('${app.tr('via', 'வழி')} $via', style: ts(12.5, color: kMuted, height: 1.35)),
                    ),
                  if (tag.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(tag, style: ts(12.5, color: kBlue, weight: FontWeight.w700)),
                    ),
                  if (b.notice != null && b.notice!.msg(app.lang).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: 8),
                      child: Text(b.notice!.msg(app.lang), style: ts(12.5, color: const Color(0xFFB26A00), height: 1.35)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
