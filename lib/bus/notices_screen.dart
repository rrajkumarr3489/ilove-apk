import 'package:flutter/material.dart';

import '../app_state.dart';
import 'bus_repo.dart';
import 'bus_widgets.dart';
import 'route_detail_screen.dart';

/// Cancelled / delayed / diverted buses and other bus notices for today.
class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: busListen,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(app.tr('Bus notices', 'பேருந்து அறிவிப்புகள்'))),
        body: const NoticeList(),
      ),
    );
  }
}

/// The notice list itself (also used inside the Updates tab).
class NoticeList extends StatelessWidget {
  const NoticeList({super.key});

  @override
  Widget build(BuildContext context) {
    final list = repo.activeNotices(DateTime.now());
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.verified_outlined,
        title: app.tr('No notices', 'அறிவிப்புகள் இல்லை'),
        message: app.tr('All buses are running as per the timetable.', 'எல்லா பேருந்துகளும் அட்டவணைப்படி இயங்குகின்றன.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final n in list)
          NoticeTile(
            n,
            routeLabel: _label(n.routeId, n.tripId),
            onTap: () {
              final id = n.routeId ?? _routeOfTrip(n.tripId);
              if (id == null || repo.routes[id] == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RouteDetailScreen(routeId: id, tripId: n.tripId, date: DateTime.now())),
              );
            },
          ),
      ],
    );
  }

  static int? _routeOfTrip(int? tripId) {
    if (tripId == null) return null;
    for (final e in repo.tripsByRoute.entries) {
      for (final t in e.value) {
        if (t.id == tripId) return e.key;
      }
    }
    return null;
  }

  static String _label(int? routeId, int? tripId) {
    final id = routeId ?? _routeOfTrip(tripId);
    final r = id == null ? null : repo.routes[id];
    return r == null ? '' : routeTitle(r);
  }
}
