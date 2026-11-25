import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: places.length,
      itemBuilder: (context, i) {
        final p = places[i];
        final pos = repo.coordOf(p.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: kSoftShadow),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.pop(context, p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                child: Row(
                  children: [
                    IconBubble(placeIcon(p.type), size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name(app.lang), style: ts(15.5, weight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(_subtitle(p), style: ts(12.5, color: kMuted)),
                        ],
                      ),
                    ),
                    if (pos != null)
                      IconButton(
                        tooltip: 'Google Maps',
                        icon: const Icon(Icons.map_rounded, color: kBrand),
                        onPressed: () => openInGoogleMaps(context, pos),
                      )
                    else
                      const Padding(padding: EdgeInsets.only(right: 10), child: Icon(Icons.chevron_right_rounded, color: kMuted)),
                  ],
                ),
              ),
            ),
          ),
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
            child: Icon(Icons.location_on, size: 40, color: identical(_sel, p) ? kGreen : kBrand),
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
                        icon: const Icon(Icons.map_rounded, size: 18),
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
          body: Column(
            children: [
              AppHeader(
                radius: 28,
                padding: const EdgeInsets.fromLTRB(4, 2, 10, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text(widget.title, style: ts(19, weight: FontWeight.w900, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          decoration: BoxDecoration(color: Colors.white.withAlpha(46), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _modeBtn(Icons.list_rounded, !_map, () => setState(() {
                                    _map = false;
                                    _sel = null;
                                  })),
                              _modeBtn(Icons.map_rounded, _map, () => setState(() {
                                    _map = true;
                                    _sel = null;
                                  })),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 5))],
                        ),
                        child: TextField(
                          controller: _q,
                          autofocus: !_map,
                          onChanged: (_) => setState(() {}),
                          style: ts(16, weight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: app.tr('Search place', 'இடத்தைத் தேடுங்கள்'),
                            hintStyle: ts(15, color: kMuted),
                            prefixIcon: const Icon(Icons.search_rounded, color: kBrand),
                            suffixIcon: _q.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20, color: kMuted),
                                    onPressed: () => setState(() => _q.clear()),
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _map ? _mapView(places) : _list(places)),
            ],
          ),
        );
      },
    );
  }

  Widget _modeBtn(IconData icon, bool on, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 21, color: on ? kBrand : Colors.white),
      ),
    );
  }
}
