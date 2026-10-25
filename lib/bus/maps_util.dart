import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import 'bus_widgets.dart';

/// Starting view of every map: Aruppukottai.
const LatLng kHomePoint = LatLng(9.5139, 78.1002);

const String kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kTileAgent = 'in.aruppukottai.ilove_apk';

Future<void> _launch(BuildContext context, String url) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (!ok && context.mounted) {
    showMsg(context, app.tr('Could not open Google Maps.', 'Google Maps-ஐத் திறக்க முடியவில்லை.'));
  }
}

/// Opens one place in the Google Maps app (or the browser).
Future<void> openInGoogleMaps(BuildContext context, LatLng point) {
  return _launch(context,
      'https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}');
}

/// Opens driving directions from the first to the last stop (middle stops as waypoints).
Future<void> openDirections(BuildContext context, List<LatLng> points) {
  if (points.length < 2) {
    return Future<void>.value();
  }
  final o = points.first;
  final d = points.last;
  var url = 'https://www.google.com/maps/dir/?api=1&travelmode=driving'
      '&origin=${o.latitude},${o.longitude}&destination=${d.latitude},${d.longitude}';
  if (points.length > 2) {
    final mid = points
        .sublist(1, points.length - 1)
        .map((p) => '${p.latitude},${p.longitude}')
        .join('%7C');
    url = '$url&waypoints=$mid';
  }
  return _launch(context, url);
}
