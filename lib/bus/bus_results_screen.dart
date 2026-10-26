import 'package:flutter/material.dart';

import '../app_state.dart';
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
          appBar: AppBar(
            title: Text(
              '${repo.placeName(widget.fromId)} → ${repo.placeName(widget.toId)}',
              style: ts(17, weight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: app.tr('Save this search', 'இந்தத் தேடலைச் சேமி'),
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? kRed : null),
                onPressed: () => repo.toggleFavSearch(_saved),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: canPrev ? () => _shift(-1) : null,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(fmtDate(_date), style: ts(16, weight: FontWeight.w800)),
                          if (isToday) Text(app.tr('Today', 'இன்று'), style: ts(12, color: kBrand, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: canNext ? () => _shift(1) : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (isToday)
                      ChoiceChip(
                        label: Text(app.tr('From now', 'இப்போதிலிருந்து')),
                        selected: _fromNow,
                        onSelected: (_) => setState(() => _fromNow = true),
                      ),
                    if (isToday)
                      ChoiceChip(
                        label: Text(app.tr('Whole day', 'நாள் முழுவதும்')),
                        selected: !_fromNow,
                        onSelected: (_) => setState(() => _fromNow = false),
                      ),
                    if (widget.viaId != null)
                      Pill('${app.tr('Via', 'வழி')}: ${repo.placeName(widget.viaId!)}',
                          color: kBlue, icon: Icons.alt_route),
                    Text(
                      app.tr('${results.length} bus(es)', '${results.length} பேருந்து(கள்)'),
                      style: ts(13, color: kMuted, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? _empty(isToday, canNext)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
    return Opacity(
      opacity: cancelled ? 0.6 : 1,
      child: SoftCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fmtClock(b.departsMin),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: kInk,
                            decoration: cancelled ? TextDecoration.lineThrough : null)),
                    Text(app.tr('Departs', 'புறப்பாடு'), style: ts(11.5, color: kMuted)),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(fmtDur(b.durationMin), style: ts(12, color: kMuted, weight: FontWeight.w600)),
                      Row(
                        children: [
                          const SizedBox(width: 8),
                          const Icon(Icons.circle, size: 7, color: kMuted),
                          Expanded(child: Container(height: 1.5, color: kLine)),
                          const Icon(Icons.arrow_forward_ios, size: 11, color: kMuted),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(arriveDay > 0 ? '${fmtClock(b.arrivesMin)} +$arriveDay' : fmtClock(b.arrivesMin),
                        style: ts(16, weight: FontWeight.w800)),
                    Text(app.tr('Arrives', 'வருகை'), style: ts(11.5, color: kMuted)),
                  ],
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? kRed : kMuted, size: 22),
                  onPressed: () => repo.toggleFavTrip(b.trip.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (r.typeId != null) Pill(typeName(r.typeId), color: typeColor(r.typeId), filled: true),
                if (r.routeNo.isNotEmpty) Pill(r.routeNo, color: kNavy, icon: Icons.tag),
                if (b.trip.platform.isNotEmpty)
                  Pill('${app.tr('Platform', 'நடைமேடை')} ${b.trip.platform}', color: kMuted),
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
                child: Text(tag, style: ts(12.5, color: kBlue, weight: FontWeight.w600)),
              ),
            if (b.notice != null && b.notice!.msg(app.lang).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(b.notice!.msg(app.lang), style: ts(12.5, color: const Color(0xFFB26A00), height: 1.35)),
              ),
          ],
        ),
      ),
    );
  }
}
