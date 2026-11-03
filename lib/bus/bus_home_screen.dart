import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
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
    required IconData icon,
    required Color color,
    required String label,
    required int? id,
    required String hint,
    required VoidCallback onTap,
  }) {
    final name = id == null ? '' : repo.placeName(id);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 56, 10),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ts(12, color: kMuted, weight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text(
                    name.isEmpty ? hint : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(17, weight: FontWeight.w800, color: name.isEmpty ? kMuted : kInk),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, int alpha) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: Colors.white.withAlpha(alpha), shape: BoxShape.circle));
  }

  Widget _dateChip(String label, bool on, VoidCallback onTap, {IconData? icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: on ? kBrand : const Color(0xFFFFF4E6),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: on ? kBrand : kBrand.withAlpha(60)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon ?? (on ? Icons.check_rounded : Icons.circle_outlined), size: 17, color: on ? Colors.white : kBrand),
          const SizedBox(width: 6),
          Text(label, style: ts(13.5, weight: FontWeight.w800, color: on ? Colors.white : const Color(0xFF7A3A0A))),
        ]),
      ),
    );
  }

  Widget _searchCard() {
    final today = dayOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final isToday = sameDay(_date, today);
    final isTomorrow = sameDay(_date, tomorrow);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
            child: Stack(
            children: [
              Column(
                children: [
                  _field(
                    icon: Icons.trip_origin,
                    color: kGreen,
                    label: app.tr('From', 'எங்கிருந்து'),
                    id: _fromId,
                    hint: app.tr('Choose starting place', 'தொடங்கும் இடம்'),
                    onTap: _pickFrom,
                  ),
                  const Divider(height: 1, color: kLine),
                  _field(
                    icon: Icons.location_on,
                    color: kRed,
                    label: app.tr('To', 'எங்கு'),
                    id: _toId,
                    hint: app.tr('Choose destination', 'சேருமிடம்'),
                    onTap: _pickTo,
                  ),
                ],
              ),
              Positioned(
                right: 0,
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
          ),
          const SizedBox(height: 4),
          if (_viaId == null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickVia,
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: Text(app.tr('Add a via stop (optional)', 'வழியில் உள்ள இடம் சேர் (விருப்பம்)')),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: kBrand.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.alt_route, color: kBrand, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickVia,
                      child: Text(
                        '${app.tr('Via', 'வழி')}: ${repo.placeName(_viaId!)}',
                        style: ts(15, weight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _viaId = null),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dateChip(app.tr('Today', 'இன்று'), isToday, () => setState(() => _date = today)),
              _dateChip(app.tr('Tomorrow', 'நாளை'), isTomorrow, () => setState(() => _date = tomorrow)),
              _dateChip(!isToday && !isTomorrow ? fmtDate(_date) : app.tr('Pick date', 'தேதி'), !isToday && !isTomorrow, _pickDate,
                  icon: Icons.calendar_month_rounded),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF7A1A), kBrand]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: kBrand.withAlpha(90), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _search,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(app.tr('Search buses', 'பேருந்துகளைத் தேடு'), style: ts(16.5, weight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
                child: Text(app.tr('The server address is not set.', 'சர்வர் முகவரி அமைக்கப்படவில்லை.'),
                    style: ts(15, weight: FontWeight.w700)),
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
            child: Text(app.tr('Getting the latest bus timetable...', 'சமீபத்திய பேருந்து நேரங்களைப் பெறுகிறது...'),
                style: ts(14.5, weight: FontWeight.w600)),
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
              icon: const Icon(Icons.refresh),
              label: Text(app.tr('Try again', 'மீண்டும் முயற்சி')),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Icon(repo.lastError == null ? Icons.check_circle : Icons.cloud_off,
            size: 16, color: repo.lastError == null ? kGreen : kAmber),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            repo.lastError == null
                ? app.tr('Timetable updated ${agoText(repo.lastSync)}', 'நேரங்கள் புதுப்பிக்கப்பட்டது: ${agoText(repo.lastSync)}')
                : '${repo.lastError} ${app.tr('Showing the last saved timetable.', 'கடைசியாகச் சேமித்த நேரங்கள் காட்டப்படுகின்றன.')}',
            style: ts(12.5, color: kMuted),
          ),
        ),
        repo.syncing
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: app.tr('Refresh', 'புதுப்பி'),
                icon: const Icon(Icons.refresh, size: 20),
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
        final top = MediaQuery.of(context).padding.top;
        final notices = repo.activeNotices(DateTime.now());
        final recents = repo.recents
            .where((s) => repo.places[s.fromId] != null && repo.places[s.toId] != null)
            .toList();
        return Scaffold(
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF8A2B), kBrand, Color(0xFFD9480F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
                  boxShadow: [BoxShadow(color: Color(0x55E8590C), blurRadius: 20, offset: Offset(0, 8))],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(right: -40, top: -30, child: _bubble(150, 26)),
                    Positioned(left: -50, bottom: 60, child: _bubble(120, 20)),
                    Positioned(right: 60, bottom: -40, child: _bubble(100, 18)),
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, top + 4, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Container(
                                width: 38,
                                height: 38,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(color: Colors.white.withAlpha(55), shape: BoxShape.circle),
                                child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 22),
                              ),
                              Expanded(
                                child: Text(app.tr('Bus Timings', 'பேருந்து நேரங்கள்'),
                                    style: ts(20, weight: FontWeight.w900, color: Colors.white)),
                              ),
                              const LangToggle(onDark: true),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 2, 8, 16),
                            child: Text(app.tr('Find the next bus from and to Aruppukottai', 'அருப்புக்கோட்டைக்கு வரும், செல்லும் பேருந்துகளைத் தேடுங்கள்'),
                                style: ts(13.5, color: Colors.white.withAlpha(235), height: 1.35)),
                          ),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _searchCard()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _statusCard(),
                    if (notices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SoftCard(
                        color: kAmber.withAlpha(28),
                        onTap: () => Navigator.push(
                            context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
                        child: Row(children: [
                          const Icon(Icons.campaign, color: Color(0xFFB26A00)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              app.tr('${notices.length} notice(s) for today', 'இன்று ${notices.length} அறிவிப்பு(கள்)'),
                              style: ts(14.5, weight: FontWeight.w700),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ]),
                      ),
                    ],
                    if (recents.isNotEmpty) ...[
                      SectionTitle(app.tr('Recent searches', 'சமீபத்திய தேடல்கள்')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final s in recents)
                            ActionChip(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: kBrand.withAlpha(70)),
                              avatar: const Icon(Icons.history_rounded, size: 17, color: kBrand),
                              label: Text('${repo.placeName(s.fromId)} → ${repo.placeName(s.toId)}', style: ts(13, weight: FontWeight.w700)),
                              onPressed: () => _go(s),
                            ),
                        ],
                      ),
                    ],
                    SectionTitle(app.tr('Quick links', 'விரைவு இணைப்புகள்')),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickTile(
                            color: const Color(0xFFE8590C),
                            icon: Icons.departure_board,
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
                            color: const Color(0xFFF59E0B),
                            icon: Icons.campaign_outlined,
                            label: app.tr('Notices', 'அறிவிப்புகள்'),
                            onTap: () => Navigator.push(
                                context, MaterialPageRoute(builder: (_) => const NoticesScreen())),
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
                            icon: Icons.add_road,
                            label: app.tr('Add bus / timing', 'பேருந்து / நேரம் சேர்'),
                            onTap: () => openAddBus(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickTile(
                            color: const Color(0xFF6A1B9A),
                            icon: Icons.history_edu_outlined,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 27),
                ),
                const SizedBox(height: 10),
                Text(label, textAlign: TextAlign.center, style: ts(13.5, weight: FontWeight.w800, height: 1.25)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
