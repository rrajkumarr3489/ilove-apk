import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../ui.dart';
import '../widgets.dart';
import 'bus_models.dart';
import 'bus_repo.dart';
import 'bus_submit_screens.dart';
import 'bus_results_screen.dart';
import 'bus_widgets.dart';
import 'departures_screen.dart';
import 'notices_screen.dart';
import 'place_picker_screen.dart';

/// Bus Timings home: From / To / optional Via, date, and search.
class BusHomeScreen extends StatefulWidget {
  const BusHomeScreen({super.key});

  @override
  State<BusHomeScreen> createState() => _BusHomeScreenState();
}

class _BusHomeScreenState extends State<BusHomeScreen> {
  int? _fromId;
  int? _toId;
  int? _viaId;
  DateTime _date = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _fromId = int.tryParse(app.getString('bus.lastFrom') ?? '');
    _toId = int.tryParse(app.getString('bus.lastTo') ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      repo.logEvent('open_bus');
      repo.autoSync();
    });
  }

  int get _maxDays => int.tryParse(repo.settings['Bus.SearchDaysAhead'] ?? '') ?? 14;

  /// Aruppukottai is the natural starting point for most people.
  void _ensureDefaults() {
    if (_fromId == null || repo.places[_fromId!] == null) {
      _fromId = repo.placeByName('Aruppukottai')?.id;
    }
    if (_toId != null && repo.places[_toId!] == null) _toId = null;
    if (_viaId != null && repo.places[_viaId!] == null) _viaId = null;
  }

  Future<Place?> _pick(String title) {
    return Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => PlacePickerScreen(title: title)),
    );
  }

  Future<void> _pickFrom() async {
    final p = await _pick(app.tr('From', 'எங்கிருந்து'));
    if (p != null) setState(() => _fromId = p.id);
  }

  Future<void> _pickTo() async {
    final p = await _pick(app.tr('To', 'எங்கு'));
    if (p != null) setState(() => _toId = p.id);
  }

  Future<void> _pickVia() async {
    final p = await _pick(app.tr('Via (optional)', 'வழி (விருப்பம்)'));
    if (p != null) setState(() => _viaId = p.id);
  }

  void _swap() {
    setState(() {
      final t = _fromId;
      _fromId = _toId;
      _toId = t;
    });
  }

  Future<void> _pickDate() async {
    final today = dayOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(Duration(days: _maxDays)),
    );
    if (d != null) setState(() => _date = dayOnly(d));
  }

  void _search() {
    final from = _fromId;
    final to = _toId;
    if (from == null || to == null) {
      showMsg(context, app.tr('Choose both From and To.', 'எங்கிருந்து, எங்கு இரண்டையும் தேர்வு செய்யுங்கள்.'));
      return;
    }
    if (from == to) {
      showMsg(context, app.tr('From and To must be different.', 'தொடக்கமும் சேருமிடமும் வேறுபட வேண்டும்.'));
      return;
    }
    _go(SavedSearch(from, to, _viaId));
  }

  void _go(SavedSearch s) {
    setState(() {
      _fromId = s.fromId;
      _toId = s.toId;
      _viaId = s.viaId;
    });
    app.setString('bus.lastFrom', s.fromId.toString());
    app.setString('bus.lastTo', s.toId.toString());
    repo.addRecent(s);
    repo.logEvent('bus_search', entityType: 'search', detail: '${s.fromId}>${s.toId}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusResultsScreen(fromId: s.fromId, toId: s.toId, viaId: s.viaId, date: _date),
      ),
    );
  }

  Future<void> _serverDialog() async {
    final r = await showFieldsDialog(
      context,
      title: app.tr('Server address', 'சர்வர் முகவரி'),
      note: app.tr('Example: https://api.yoursite.com', 'எ.கா: https://api.yoursite.com'),
      fields: [FieldSpec(app.tr('Address', 'முகவரி'), initial: app.serverText, keyboard: TextInputType.url)],
      okLabel: app.tr('Save', 'சேமி'),
    );
    if (r == null) return;
    await app.setServer(r[0]);
    repo.sync();
  }

  Widget _field({
    required String label,
    required int? id,
    required String hint,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool active,
    Widget? trailing,
  }) {
    final name = id == null ? '' : repo.placeName(id);
    return Container(
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFEFF2F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? kBrand : Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: ts(bs(12), color: kMuted)),
                    Text(
                      name.isEmpty ? hint : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts(bs(17), weight: FontWeight.w800, color: name.isEmpty ? kMuted : kInk),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _day(String label, IconData icon, bool on, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 44,
          decoration: BoxDecoration(
            color: on ? kBrand : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            boxShadow: on ? [BoxShadow(color: kBrand.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))] : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: on ? Colors.white : kBrand),
              const SizedBox(width: 7),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(bs(15), weight: FontWeight.w800, color: on ? Colors.white : kInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchCard() {
    final today = dayOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = sameDay(_date, today);
    final isTomorrow = sameDay(_date, tomorrow);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(app.tr('Plan your trip', 'பயணத்தைத் திட்டமிடுங்கள்'), style: ts(bs(19), weight: FontWeight.w800)),
        const SizedBox(height: 14),
        Stack(
          children: [
            Column(
              children: [
                _field(
                  label: app.tr('From', 'எங்கிருந்து'),
                  id: _fromId,
                  hint: app.tr('Choose starting place', 'தொடங்கும் இடம்'),
                  icon: Icons.trip_origin,
                  color: kGreen,
                  active: false,
                  onTap: _pickFrom,
                  trailing: IconButton(
                    tooltip: app.tr('Aruppukottai', 'அருப்புக்கோட்டை'),
                    icon: const Icon(Icons.my_location_rounded, color: kBrand, size: 22),
                    onPressed: () => setState(() => _fromId = repo.placeByName('Aruppukottai')?.id ?? _fromId),
                  ),
                ),
                SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(width: 2.5, height: 2.5, margin: const EdgeInsets.symmetric(vertical: 1.2), decoration: const BoxDecoration(color: Color(0xFFB8C6E0), shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  ),
                ),
                _field(
                  label: app.tr('To', 'எங்கு'),
                  id: _toId,
                  hint: app.tr('Choose destination', 'சேருமிடம்'),
                  icon: Icons.location_on,
                  color: kRed,
                  active: true,
                  onTap: _pickTo,
                ),
              ],
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  shadowColor: kBrand.withAlpha(90),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: app.tr('Swap', 'மாற்று'),
                    icon: const Icon(Icons.swap_vert_rounded, color: kBrand),
                    onPressed: _swap,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_viaId == null)
          DashedBox(
            onTap: _pickVia,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 19, color: kBrand),
                  const SizedBox(width: 8),
                  Flexible(child: Text(app.tr('Add a via stop (optional)', 'வழியில் உள்ள இடம் சேர் (விருப்பம்)'), style: ts(bs(14), weight: FontWeight.w700, color: kBrand))),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(color: kBrand.withAlpha(20), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.alt_route, color: kBrand, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickVia,
                    child: Text(
                      '${app.tr('Via', 'வழி')}: ${repo.placeName(_viaId!)}',
                      style: ts(bs(15), weight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => setState(() => _viaId = null)),
              ],
            ),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFE8EDF6), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              _day(app.tr('Today', 'இன்று'), isToday ? Icons.check_rounded : Icons.radio_button_unchecked, isToday, () => setState(() => _date = today)),
              _day(app.tr('Tomorrow', 'நாளை'), isTomorrow ? Icons.check_rounded : Icons.radio_button_unchecked, isTomorrow, () => setState(() => _date = tomorrow)),
              _day(!isToday && !isTomorrow ? fmtDate(_date) : app.tr('Pick date', 'தேதி'), Icons.calendar_month_rounded, !isToday && !isTomorrow, _pickDate),
            ],
          ),
        ),
        const SizedBox(height: 16),
        BusPrimaryButton(label: app.tr('Search buses', 'பேருந்துகளைத் தேடு'), icon: Icons.search_rounded, onTap: _search),
      ],
    );
  }

  /// Well-known places people travel to from Aruppukottai. Only those that exist in the timetable are shown.
  List<Place> _popular() {
    const names = ['Madurai', 'Virudhunagar', 'Sivakasi', 'Rajapalayam', 'Tirunelveli', 'Coimbatore', 'Chennai', 'Thoothukudi', 'Rameswaram', 'Kovilpatti'];
    final out = <Place>[];
    for (final n in names) {
      final p = repo.placeByName(n);
      if (p != null && p.id != _fromId) out.add(p);
      if (out.length >= 8) break;
    }
    return out;
  }

  Widget _statusCard() {
    if (!app.serverConfigured) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.link_off, color: kRed),
              const SizedBox(width: 10),
              Expanded(
                child: Text(app.tr('The server address is not set.', 'சர்வர் முகவரி அமைக்கப்படவில்லை.'), style: ts(15, weight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 10),
            FilledButton(onPressed: _serverDialog, child: Text(app.tr('Set server address', 'சர்வர் முகவரியை அமை'))),
          ],
        ),
      );
    }
    if (repo.syncing && !repo.hasData) {
      return SoftCard(
        child: Row(children: [
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(app.tr('Getting the latest bus timetable...', 'சமீபத்திய பேருந்து நேரங்களைப் பெறுகிறது...'), style: ts(14.5, weight: FontWeight.w600)),
          ),
        ]),
      );
    }
    if (!repo.hasData) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cloud_off, color: kMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  repo.lastError ?? app.tr('No bus timetable yet.', 'பேருந்து நேரங்கள் இன்னும் இல்லை.'),
                  style: ts(14, color: kMuted, height: 1.35),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => repo.sync(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(app.tr('Try again', 'மீண்டும் முயற்சி')),
            ),
          ],
        ),
      );
    }
    final ok = repo.lastError == null;
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: ok ? kGreen : const Color(0xFFB26A00), shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ok
                ? app.tr('Timetable updated ${agoText(repo.lastSync)}', 'நேரங்கள் புதுப்பிக்கப்பட்டது: ${agoText(repo.lastSync)}')
                : '${repo.lastError} ${app.tr('Showing the last saved timetable.', 'கடைசியாகச் சேமித்த நேரங்கள் காட்டப்படுகின்றன.')}',
            style: ts(bs(13), color: kMuted, weight: FontWeight.w600),
          ),
        ),
        repo.syncing
            ? const Padding(padding: EdgeInsets.all(10), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
            : IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: app.tr('Refresh', 'புதுப்பி'),
                icon: const Icon(Icons.refresh_rounded, size: 22, color: kInk),
                onPressed: () => repo.sync(),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: busListen,
      builder: (context, _) {
        _ensureDefaults();
        final notices = repo.activeNotices(DateTime.now());
        final recents = repo.recents.where((s) => repo.places[s.fromId] != null && repo.places[s.toId] != null).toList();
        final popular = _popular();
        return Scaffold(
          backgroundColor: kBusBg,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              BusHeader(
                title: app.tr('Bus Timings', 'பேருந்து நேரங்கள்'),
                subtitle: app.tr('Find the next bus from and to Aruppukottai', 'அருப்புக்கோட்டைக்கு வரும், செல்லும் பேருந்துகளைத் தேடுங்கள்'),
                actions: const [LangToggle()],
              ),
              const SizedBox(height: 18),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _searchCard()),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusCard(),
                    if (notices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SoftCard(
                        color: const Color(0xFFFFF1D6),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                        child: Row(children: [
                          const IconBubble(Icons.campaign_rounded, color: Color(0xFFB26A00), size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              app.tr('${notices.length} notice(s) for today', 'இன்று ${notices.length} அறிவிப்பு(கள்)'),
                              style: ts(14.5, weight: FontWeight.w800),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ]),
                      ),
                    ],
                    if (recents.isNotEmpty) ...[
                      SectionTitle(app.tr('Recent searches', 'சமீபத்திய தேடல்கள்')),
                      for (final s in recents)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE3EAF6))),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _go(s),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.history_rounded, size: 20, color: kBrand),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text('${repo.placeName(s.fromId)} → ${repo.placeName(s.toId)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(bs(14.5), weight: FontWeight.w700)),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: kMuted),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (popular.isNotEmpty) ...[
                      SectionTitle(app.tr('Popular from Aruppukottai', 'அருப்புக்கோட்டையிலிருந்து பிரபலமானவை')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in popular)
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() => _toId = p.id);
                                _search();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD5E2F7))),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.near_me_rounded, size: 16, color: kBrand),
                                    const SizedBox(width: 7),
                                    Text(p.name(app.lang), style: ts(bs(14), weight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    SectionTitle(app.tr('Quick links', 'விரைவு இணைப்புகள்')),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickTile(
                            color: kBrand,
                            icon: Icons.departure_board_rounded,
                            label: app.tr('Bus stand board', 'பேருந்து நிலைய பலகை'),
                            onTap: () {
                              final id = _fromId ?? repo.placeByName('Aruppukottai')?.id;
                              if (id == null) {
                                showMsg(context, app.tr('Timetable is not downloaded yet.', 'நேரங்கள் இன்னும் பதிவிறக்கப்படவில்லை.'));
                                return;
                              }
                              Navigator.push(context, MaterialPageRoute(builder: (_) => DeparturesScreen(placeId: id)));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickTile(
                            color: kBrandLight,
                            icon: Icons.campaign_rounded,
                            label: app.tr('Notices', 'அறிவிப்புகள்'),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickTile(
                            color: const Color(0xFF2E7D32),
                            icon: Icons.add_road_rounded,
                            label: app.tr('Add bus / timing', 'பேருந்து / நேரம் சேர்'),
                            onTap: () => openAddBus(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickTile(
                            color: const Color(0xFF6A1B9A),
                            icon: Icons.history_edu_rounded,
                            label: app.tr('My entries', 'என் பதிவுகள்'),
                            onTap: () => openMyEntries(context),
                          ),
                        ),
                      ],
                    ),
                    if ((repo.settings['Bus.DisclaimerEn'] ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          app.tr(repo.settings['Bus.DisclaimerEn'] ?? '', repo.settings['Bus.DisclaimerTa'] ?? ''),
                          textAlign: TextAlign.center,
                          style: ts(12, color: kMuted, height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickTile({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          IconBubble(icon, color: color, size: 54),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: ts(13, weight: FontWeight.w700, height: 1.25)),
        ],
      ),
    );
  }
}
