import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
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
              AppHeader(
                radius: 30,
                padding: const EdgeInsets.fromLTRB(4, 2, 10, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${repo.placeName(widget.fromId)} → ${repo.placeName(widget.toId)}',
                                style: ts(19, weight: FontWeight.w900, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                app.tr('${results.length} bus(es) found', '${results.length} பேருந்து(கள்) கிடைத்தன'),
                                style: ts(12.5, color: Colors.white.withAlpha(225), weight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: app.tr('Save this search', 'இந்தத் தேடலைச் சேமி'),
                          icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? const Color(0xFFFFD0D0) : Colors.white),
                          onPressed: () => repo.toggleFavSearch(_saved),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: DateStrip(
                        date: _date,
                        isToday: isToday,
                        canPrev: canPrev,
                        canNext: canNext,
                        onPrev: () => _shift(-1),
                        onNext: () => _shift(1),
                      ),
                    ),
                    if (isToday || widget.viaId != null) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Wrap(
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
    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), boxShadow: kSoftShadow),
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
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 6, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fmtClock(b.departsMin),
                                    style: TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      color: kInk,
                                      decoration: cancelled ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  Text(app.tr('Departs', 'புறப்பாடு'), style: ts(11.5, color: kMuted)),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Column(
                                    children: [
                                      Text(fmtDur(b.durationMin), style: ts(12, color: kMuted, weight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.circle, size: 7, color: kBrand),
                                          Expanded(child: Container(height: 2, color: kBrand.withAlpha(60))),
                                          Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(color: kBrand.withAlpha(26), shape: BoxShape.circle),
                                            child: const Icon(Icons.directions_bus_rounded, size: 15, color: kBrand),
                                          ),
                                          Expanded(child: Container(height: 2, color: kBrand.withAlpha(60))),
                                          const Icon(Icons.circle, size: 7, color: kBrand),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    arriveDay > 0 ? '${fmtClock(b.arrivesMin)} +$arriveDay' : fmtClock(b.arrivesMin),
                                    style: ts(16.5, weight: FontWeight.w800),
                                  ),
                                  Text(app.tr('Arrives', 'வருகை'), style: ts(11.5, color: kMuted)),
                                ],
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: fav ? kRed : kMuted, size: 23),
                                onPressed: () => repo.toggleFavTrip(b.trip.id),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (r.typeId != null) Pill(typeName(r.typeId), color: typeColor(r.typeId), filled: true),
                              if (r.routeNo.isNotEmpty) Pill(r.routeNo, color: kNavy, icon: Icons.tag),
                              if (b.trip.platform.isNotEmpty) Pill('${app.tr('Platform', 'நடைமேடை')} ${b.trip.platform}', color: kMuted),
                              if (b.fare != null) Pill(fmtFare(b.fare), color: kGreen, icon: Icons.payments_outlined),
                              StatusBadge(b.status, delay: b.delay),
                            ],
                          ),
                          if (via.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, right: 8),
                              child: Text('${app.tr('via', 'வழி')} $via', style: ts(13, color: kMuted, height: 1.35)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
