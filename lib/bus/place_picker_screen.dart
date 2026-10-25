import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../theme.dart';
import 'bus_models.dart';
import 'bus_repo.dart';
import 'bus_widgets.dart';
import 'maps_util.dart';

/// Pick a place from the list or from the map. Returns the chosen [Place].
class PlacePickerScreen extends StatefulWidget {
  final String title;

  /// false = only places that already have buses (search screens); true = every place (adding a new bus).
  final bool allPlaces;

  const PlacePickerScreen({super.key, required this.title, this.allPlaces = false});

  @override
  State<PlacePickerScreen> createState() => _PlacePickerScreenState();
}

class _PlacePickerScreenState extends State<PlacePickerScreen> {
  final TextEditingController _q = TextEditingController();
  bool _map = false;
  Place? _sel;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _subtitle(Place p) {
    final parent = p.parentId == null ? null : repo.places[p.parentId!];
    final t = placeTypeLabel(p.type);
    return parent == null ? t : '$t · ${parent.name(app.lang)}';
  }

  Widget _list(List<Place> places) {
    if (places.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: app.tr('No place found', 'இடம் எதுவும் கிடைக்கவில்லை'),
        message: app.tr('Try a different spelling.', 'வேறு எழுத்துக்கூட்டலில் தேடிப் பாருங்கள்.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: places.length,
      separatorBuilder: (c, i) => const Divider(height: 1, color: kLine),
      itemBuilder: (context, i) {
        final p = places[i];
        final pos = repo.coordOf(p.id);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: kBrand.withAlpha(24), borderRadius: BorderRadius.circular(12)),
            child: Icon(placeIcon(p.type), color: kBrand, size: 22),
          ),
          title: Text(p.name(app.lang), style: ts(15.5, weight: FontWeight.w700)),
          subtitle: Text(_subtitle(p), style: ts(12.5, color: kMuted)),
          trailing: pos == null
              ? null
              : IconButton(
                  tooltip: 'Google Maps',
                  icon: const Icon(Icons.map_outlined, color: kBlue),
                  onPressed: () => openInGoogleMaps(context, pos),
                ),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }

  Widget _mapView(List<Place> places) {
    final withPos = places.where((p) => p.lat != null && p.lng != null).toList();
    final markers = <Marker>[
      for (final p in withPos)
        Marker(
          point: LatLng(p.lat!, p.lng!),
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => setState(() => _sel = p),
            child: Icon(Icons.location_on, size: 40, color: identical(_sel, p) ? kBrand : kBlue),
          ),
        ),
    ];
    final sel = _sel;
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: kHomePoint,
            initialZoom: 9,
            onTap: (tapPos, point) => setState(() => _sel = null),
          ),
          children: [
            TileLayer(urlTemplate: kTileUrl, userAgentPackageName: kTileAgent),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          left: 6,
          bottom: sel == null ? 4 : 120,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Colors.white70,
            child: Text('© OpenStreetMap contributors', style: ts(10, color: kMuted)),
          ),
        ),
        if (sel != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SoftCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sel.name(app.lang), style: ts(17, weight: FontWeight.w800)),
                  Text(_subtitle(sel), style: ts(13, color: kMuted)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, sel),
                          style: FilledButton.styleFrom(backgroundColor: kBrand),
                          child: Text(app.tr('Select', 'தேர்வு செய்')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => openInGoogleMaps(context, LatLng(sel.lat!, sel.lng!)),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text('Google Maps'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: busListen,
      builder: (context, _) {
        final places = repo.servedPlaces(_q.text, all: widget.allPlaces);
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            actions: [
              IconButton(
                tooltip: _map ? app.tr('List', 'பட்டியல்') : app.tr('Map', 'வரைபடம்'),
                icon: Icon(_map ? Icons.list : Icons.map_outlined),
                onPressed: () => setState(() {
                  _map = !_map;
                  _sel = null;
                }),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: TextField(
                  controller: _q,
                  autofocus: !_map,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: app.tr('Search place', 'இடத்தைத் தேடுங்கள்'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: kLine),
                    ),
                  ),
                ),
              ),
              Expanded(child: _map ? _mapView(places) : _list(places)),
            ],
          ),
        );
      },
    );
  }
}
