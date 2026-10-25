import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../auth/auth_guard.dart';
import '../auth/auth_service.dart';
import '../theme.dart';
import 'bus_api.dart';
import 'bus_models.dart';
import 'bus_repo.dart';
import 'bus_widgets.dart';
import 'place_picker_screen.dart';

/// Entry points. Both ask a guest to register first; if the guest cancels, nothing opens.
Future<void> openAddBus(BuildContext context) async {
  final ok = await requireLogin(context);
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AddBusScreen()));
}

Future<void> openAddTiming(BuildContext context, int routeId) async {
  final ok = await requireLogin(context,
      whyEn: 'To add a timing for this bus you must be registered, so we know who added it. '
          'You can still view all bus timings as a guest.',
      whyTa: 'இந்த பேருந்துக்கு நேரம் சேர்க்க நீங்கள் பதிவு செய்திருக்க வேண்டும் - யார் சேர்த்தார்கள் என்பது தெரிய வேண்டும். '
          'விருந்தினராக அனைத்து பேருந்து நேரங்களையும் பார்க்கலாம்.');
  if (!ok || !context.mounted) return;
  await Navigator.push(
      context, MaterialPageRoute<void>(builder: (_) => AddTimingScreen(routeId: routeId)));
}

Future<void> openMyEntries(BuildContext context) async {
  final ok = await requireLogin(context,
      whyEn: 'Login to see the bus details you have sent.',
      whyTa: 'நீங்கள் அனுப்பிய பேருந்து விவரங்களைப் பார்க்க உள்நுழையுங்கள்.');
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MySubmissionsScreen()));
}

// ------------------------------------------------------------------ helpers

String _two(int n) => n.toString().padLeft(2, '0');
String _hhmm(int m) => '${_two(m ~/ 60)}:${_two(m % 60)}';

const List<String> _dEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _dTa = ['திங்', 'செவ்', 'புத', 'வியா', 'வெள்', 'சனி', 'ஞாயி'];

String daysLabel(int mask) {
  if (mask == 127) return app.tr('Every day', 'தினமும்');
  if (mask == 31) return app.tr('Mon-Fri', 'திங்-வெள்');
  final names = <String>[];
  for (var i = 0; i < 7; i++) {
    if ((mask & (1 << i)) != 0) names.add(app.lang == 'ta' ? _dTa[i] : _dEn[i]);
  }
  return names.join(', ');
}

class TripDraft {
  int minutes;
  int mask;
  TripDraft(this.minutes, this.mask);
}

/// Days of the week as chips. Used for new timings and when editing one.
class DaysPicker extends StatelessWidget {
  final int mask;
  final ValueChanged<int> onChanged;

  const DaysPicker({super.key, required this.mask, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 2,
      children: [
        for (var i = 0; i < 7; i++)
          FilterChip(
            label: Text(app.lang == 'ta' ? _dTa[i] : _dEn[i]),
            selected: (mask & (1 << i)) != 0,
            visualDensity: VisualDensity.compact,
            onSelected: (v) {
              final m = v ? (mask | (1 << i)) : (mask & ~(1 << i));
              onChanged(m);
            },
          ),
      ],
    );
  }
}

/// List of departure times (from the starting place) with their running days.
class TripsEditor extends StatefulWidget {
  final List<TripDraft> trips;
  final VoidCallback onChanged;

  const TripsEditor({super.key, required this.trips, required this.onChanged});

  @override
  State<TripsEditor> createState() => _TripsEditorState();
}

class _TripsEditorState extends State<TripsEditor> {
  int _mask = 127;

  Future<void> _add() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
      helpText: app.tr('Departure time', 'புறப்படும் நேரம்'),
    );
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    if (_mask == 0) {
      if (mounted) showMsg(context, app.tr('Choose at least one day.', 'குறைந்தது ஒரு நாளைத் தேர்வு செய்யுங்கள்.'));
      return;
    }
    if (widget.trips.any((e) => e.minutes == m && e.mask == _mask)) {
      if (mounted) showMsg(context, app.tr('That time is already added.', 'அந்த நேரம் ஏற்கனவே சேர்க்கப்பட்டுள்ளது.'));
      return;
    }
    widget.trips.add(TripDraft(m, _mask));
    widget.trips.sort((a, b) => a.minutes.compareTo(b.minutes));
    widget.onChanged();
    setState(() {});
  }

  Future<void> _editDays(TripDraft t) async {
    var m = t.mask;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${_hhmm(t.minutes)} - ${app.tr('runs on', 'ஓடும் நாட்கள்')}'),
          content: DaysPicker(mask: m, onChanged: (v) => setD(() => m = v)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.tr('Cancel', 'ரத்து'))),
            FilledButton(
              onPressed: m == 0 ? null : () => Navigator.pop(ctx, true),
              child: Text(app.tr('OK', 'சரி')),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      t.mask = m;
      widget.onChanged();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(app.tr('Runs on (for the time you add next)', 'ஓடும் நாட்கள் (அடுத்து சேர்க்கும் நேரத்திற்கு)'),
            style: ts(12.5, color: kMuted)),
        const SizedBox(height: 4),
        DaysPicker(mask: _mask, onChanged: (v) => setState(() => _mask = v)),
        const SizedBox(height: 8),
        if (widget.trips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(app.tr('No time added yet.', 'இன்னும் நேரம் சேர்க்கவில்லை.'), style: ts(13.5, color: kMuted)),
          ),
        for (final t in widget.trips)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule, color: kBrand),
            title: Text(fmtClock(t.minutes), style: ts(16, weight: FontWeight.w800)),
            subtitle: Text(daysLabel(t.mask), style: ts(12.5, color: kMuted)),
            onTap: () => _editDays(t),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: kRed),
              onPressed: () {
                widget.trips.remove(t);
                widget.onChanged();
                setState(() {});
              },
            ),
          ),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(app.tr('Add departure time', 'புறப்படும் நேரத்தைச் சேர்')),
        ),
      ],
    );
  }
}

List<Map<String, dynamic>> _tripsJson(List<TripDraft> trips) => [
      for (final t in trips) <String, dynamic>{'departTime': _hhmm(t.minutes), 'daysMask': t.mask},
    ];

/// Sends the entry. Returns true when it was saved.
Future<bool> _send(BuildContext context, Map<String, dynamic> body) async {
  try {
    body['deviceId'] = app.deviceId;
    await BusApi.post('/bus/submissions', body);
    return true;
  } on ApiException catch (e) {
    if (e.status == 401) {
      await auth.expire();
      if (context.mounted) {
        showMsg(context, app.tr('Your login has expired. Please login again and press Send.',
            'உங்கள் உள்நுழைவு காலாவதியானது. மீண்டும் உள்நுழைந்து அனுப்பவும்.'));
        await requireLogin(context);
      }
      return false;
    }
    if (context.mounted) showMsg(context, e.message);
    return false;
  } catch (e) {
    if (context.mounted) showMsg(context, BusApi.friendly(e));
    return false;
  }
}

Future<void> _thanks(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: kGreen, size: 36),
      title: Text(app.tr('Thank you!', 'நன்றி!')),
      content: Text(
        app.tr(
          'Your details were sent. They will appear in the app after our team checks them. '
              'You can follow the status in "My entries".',
          'உங்கள் விவரங்கள் அனுப்பப்பட்டன. எங்கள் குழு சரிபார்த்த பிறகு ஆப்பில் தெரியும். '
              '"என் பதிவுகள்" பகுதியில் நிலையைப் பார்க்கலாம்.',
        ),
        style: ts(14.5, height: 1.4),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('OK', 'சரி')))],
    ),
  );
}

InputDecoration _dec(String label, {String? hint, IconData? icon}) => InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );

// ------------------------------------------------------------------ new bus

class _ViaDraft {
  Place? place;
  final TextEditingController minutes = TextEditingController();
}

class AddBusScreen extends StatefulWidget {
  const AddBusScreen({super.key});

  @override
  State<AddBusScreen> createState() => _AddBusScreenState();
}

class _AddBusScreenState extends State<AddBusScreen> {
  Place? _from;
  Place? _to;
  int? _typeId;
  final _routeNo = TextEditingController();
  final _hours = TextEditingController();
  final _mins = TextEditingController();
  final _fare = TextEditingController();
  final _note = TextEditingController();
  final List<_ViaDraft> _via = [];
  final List<TripDraft> _trips = [];
  bool _busy = false;

  @override
  void dispose() {
    _routeNo.dispose();
    _hours.dispose();
    _mins.dispose();
    _fare.dispose();
    _note.dispose();
    for (final v in _via) {
      v.minutes.dispose();
    }
    super.dispose();
  }

  Future<Place?> _pick(String title) => Navigator.push<Place>(
      context, MaterialPageRoute<Place>(builder: (_) => PlacePickerScreen(title: title, allPlaces: true)));

  int get _duration => (int.tryParse(_hours.text.trim()) ?? 0) * 60 + (int.tryParse(_mins.text.trim()) ?? 0);

  String? _check() {
    if (_from == null) return app.tr('Choose the From place.', 'புறப்படும் இடத்தைத் தேர்வு செய்யுங்கள்.');
    if (_to == null) return app.tr('Choose the To place.', 'சேரும் இடத்தைத் தேர்வு செய்யுங்கள்.');
    if (_from!.id == _to!.id) return app.tr('From and To cannot be the same.', 'புறப்படும் இடமும் சேரும் இடமும் ஒன்றாக இருக்கக்கூடாது.');
    final d = _duration;
    if (d < 1) return app.tr('Enter the journey time (hours and minutes).', 'பயண நேரத்தை (மணி, நிமிடம்) உள்ளிடவும்.');
    if (d > 2000) return app.tr('Journey time is too long.', 'பயண நேரம் மிக அதிகமாக உள்ளது.');
    final seen = <int>{};
    var last = 0;
    for (final v in _via) {
      if (v.place == null) return app.tr('Choose a place for every via stop, or remove the empty row.', 'ஒவ்வொரு வழி நிறுத்தத்திற்கும் இடத்தைத் தேர்வு செய்யுங்கள் அல்லது காலி வரிசையை நீக்குங்கள்.');
      final m = int.tryParse(v.minutes.text.trim()) ?? 0;
      if (m < 1 || m >= d) {
        return app.tr('${v.place!.nameEn}: minutes after start must be more than 0 and less than the journey time.',
            '${v.place!.nameTa.isEmpty ? v.place!.nameEn : v.place!.nameTa}: புறப்பட்ட பின் நிமிடங்கள் 0-க்கு மேல், பயண நேரத்திற்குள் இருக்க வேண்டும்.');
      }
      if (m <= last) return app.tr('Via stops must be in travel order with increasing minutes.', 'வழி நிறுத்தங்கள் பயண வரிசையில், நிமிடங்கள் கூடிக்கொண்டே இருக்க வேண்டும்.');
      last = m;
      if (!seen.add(v.place!.id) || v.place!.id == _from!.id || v.place!.id == _to!.id) {
        return app.tr('A place is repeated (or same as From/To).', 'ஓர் இடம் மீண்டும் வருகிறது (அல்லது From/To-வுடன் ஒன்றாக உள்ளது).');
      }
    }
    if (_trips.isEmpty) return app.tr('Add at least one departure time.', 'குறைந்தது ஒரு புறப்படும் நேரத்தைச் சேர்க்கவும்.');
    return null;
  }

  Future<void> _submit() async {
    final problem = _check();
    if (problem != null) {
      showMsg(context, problem);
      return;
    }
    if (!await requireLogin(context)) return; // login may have expired meanwhile
    if (!mounted) return;
    setState(() => _busy = true);
    final fare = double.tryParse(_fare.text.trim());
    final ok = await _send(context, <String, dynamic>{
      'kind': 'NewRoute',
      'fromPlaceId': _from!.id,
      'toPlaceId': _to!.id,
      'busTypeId': _typeId,
      'routeNo': _routeNo.text.trim(),
      'durationMinutes': _duration,
      'fareTotal': fare,
      'note': _note.text.trim(),
      'stops': [
        for (var i = 0; i < _via.length; i++)
          <String, dynamic>{
            'stopSeq': i + 1,
            'placeId': _via[i].place!.id,
            'minutesFromStart': int.parse(_via[i].minutes.text.trim()),
          },
      ],
      'trips': _tripsJson(_trips),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await _thanks(context);
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _placeButton(String label, Place? p, VoidCallback onTap, {IconData icon = Icons.place_outlined}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        decoration: _dec(label, icon: icon),
        child: Text(
          p == null ? app.tr('Tap to choose', 'தேர்வு செய்ய தட்டவும்') : p.name(app.lang),
          style: ts(15.5, weight: p == null ? FontWeight.w400 : FontWeight.w700, color: p == null ? kMuted : kInk),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final types = repo.types.values.where((t) => t.active).toList()..sort((a, b) => a.sort.compareTo(b.sort));
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('Add a new bus', 'புதிய பேருந்தைச் சேர்'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          SoftCard(
            color: kBlue.withAlpha(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, color: kBlue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.tr(
                        'Added as ${auth.name}. Our team checks every entry before it appears in the app.',
                        '${auth.name} என்ற பெயரில் சேர்க்கப்படும். ஆப்பில் வருவதற்கு முன் எங்கள் குழு ஒவ்வொன்றையும் சரிபார்க்கும்.'),
                    style: ts(13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          SectionTitle(app.tr('Route', 'வழித்தடம்')),
          _placeButton(app.tr('From', 'புறப்படும் இடம்'), _from, () async {
            final p = await _pick(app.tr('From', 'புறப்படும் இடம்'));
            if (p != null) setState(() => _from = p);
          }, icon: Icons.trip_origin),
          const SizedBox(height: 12),
          _placeButton(app.tr('To', 'சேரும் இடம்'), _to, () async {
            final p = await _pick(app.tr('To', 'சேரும் இடம்'));
            if (p != null) setState(() => _to = p);
          }, icon: Icons.flag_outlined),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _typeId,
            decoration: _dec(app.tr('Bus type (optional)', 'பேருந்து வகை (விருப்பம்)'), icon: Icons.directions_bus_outlined),
            items: [
              for (final t in types) DropdownMenuItem<int>(value: t.id, child: Text(t.name(app.lang))),
            ],
            onChanged: (v) => setState(() => _typeId = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _routeNo,
            maxLength: 20,
            decoration: _dec(app.tr('Route / bus number (optional)', 'வழித்தட / பேருந்து எண் (விருப்பம்)'), icon: Icons.confirmation_number_outlined).copyWith(counterText: ''),
          ),
          SectionTitle(app.tr('Journey', 'பயணம்')),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hours,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: _dec(app.tr('Hours', 'மணி')).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _mins,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 2,
                  decoration: _dec(app.tr('Minutes', 'நிமிடம்')).copyWith(counterText: ''),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fare,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 6,
                  decoration: _dec(app.tr('Fare ₹', 'கட்டணம் ₹')).copyWith(counterText: ''),
                ),
              ),
            ],
          ),
          SectionTitle(app.tr('Via stops (optional)', 'வழி நிறுத்தங்கள் (விருப்பம்)')),
          Text(
            app.tr('Enter them in travel order. Minutes = time after the bus leaves the From place.',
                'பயண வரிசையில் உள்ளிடவும். நிமிடம் = பேருந்து புறப்பட்ட பின் ஆகும் நேரம்.'),
            style: ts(12.5, color: kMuted, height: 1.35),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _via.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _placeButton(app.tr('Via ${i + 1}', 'வழி ${i + 1}'), _via[i].place, () async {
                      final p = await _pick(app.tr('Via stop', 'வழி நிறுத்தம்'));
                      if (p != null) setState(() => _via[i].place = p);
                    }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _via[i].minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      decoration: _dec(app.tr('Min', 'நிமி')).copyWith(counterText: ''),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kRed),
                    onPressed: () => setState(() {
                      _via[i].minutes.dispose();
                      _via.removeAt(i);
                    }),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _via.add(_ViaDraft())),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(app.tr('Add via stop', 'வழி நிறுத்தத்தைச் சேர்')),
          ),
          SectionTitle(app.tr('Departure times', 'புறப்படும் நேரங்கள்')),
          Text(
            app.tr('Time the bus leaves ${_from == null ? 'the From place' : _from!.nameEn}.',
                'பேருந்து ${_from == null ? 'புறப்படும் இடத்திலிருந்து' : _from!.name(app.lang)} புறப்படும் நேரம்.'),
            style: ts(12.5, color: kMuted),
          ),
          const SizedBox(height: 6),
          TripsEditor(trips: _trips, onChanged: () => setState(() {})),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
            decoration: _dec(app.tr('Note for our team (optional)', 'எங்கள் குழுவுக்கு குறிப்பு (விருப்பம்)'), icon: Icons.notes),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kBrand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(app.tr('Send for checking', 'சரிபார்க்க அனுப்பு'), style: ts(16, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ extra timing

class AddTimingScreen extends StatefulWidget {
  final int routeId;

  const AddTimingScreen({super.key, required this.routeId});

  @override
  State<AddTimingScreen> createState() => _AddTimingScreenState();
}

class _AddTimingScreenState extends State<AddTimingScreen> {
  final List<TripDraft> _trips = [];
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_trips.isEmpty) {
      showMsg(context, app.tr('Add at least one departure time.', 'குறைந்தது ஒரு புறப்படும் நேரத்தைச் சேர்க்கவும்.'));
      return;
    }
    final existing = repo.tripsByRoute[widget.routeId] ?? const <Trip>[];
    final fresh = _trips.where((d) => !existing.any((t) => t.departMin == d.minutes && t.mask == d.mask)).toList();
    if (fresh.isEmpty) {
      showMsg(context, app.tr('These timings are already listed for this bus.', 'இந்த நேரங்கள் ஏற்கனவே இந்த பேருந்துக்கு உள்ளன.'));
      return;
    }
    if (!await requireLogin(context)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final ok = await _send(context, <String, dynamic>{
      'kind': 'AddTiming',
      'busRouteId': widget.routeId,
      'note': _note.text.trim(),
      'trips': _tripsJson(fresh),
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      await _thanks(context);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = repo.routes[widget.routeId];
    final existing = [...(repo.tripsByRoute[widget.routeId] ?? const <Trip>[])]
      ..sort((a, b) => a.departMin.compareTo(b.departMin));
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('Add a timing', 'நேரத்தைச் சேர்'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
        children: [
          if (r != null)
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(routeTitle(r), style: ts(17, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${typeName(r.typeId)} ${r.routeNo}'.trim(), style: ts(13, color: kMuted)),
                  const SizedBox(height: 10),
                  Text(app.tr('Already listed', 'ஏற்கனவே உள்ளவை'), style: ts(12.5, color: kMuted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final t in existing) Pill(fmtClock(t.departMin), color: kBlue)],
                  ),
                ],
              ),
            ),
          SectionTitle(app.tr('New departure times', 'புதிய புறப்படும் நேரங்கள்')),
          TripsEditor(trips: _trips, onChanged: () => setState(() {})),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 300,
            maxLines: 2,
            decoration: _dec(app.tr('Note for our team (optional)', 'எங்கள் குழுவுக்கு குறிப்பு (விருப்பம்)'), icon: Icons.notes),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: kBrand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send),
              label: Text(app.tr('Send for checking', 'சரிபார்க்க அனுப்பு'), style: ts(16, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ my entries

class MySubmissionsScreen extends StatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  State<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends State<MySubmissionsScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _items = null;
    });
    try {
      final r = await BusApi.get('/bus/submissions/mine') as List<dynamic>;
      if (!mounted) return;
      setState(() => _items = [for (final e in r) Map<String, dynamic>.from(e as Map)]);
    } on ApiException catch (e) {
      if (e.status == 401) await auth.expire();
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = BusApi.friendly(e));
    }
  }

  String _place(Map<String, dynamic> m, String key) {
    final ta = jStr(m['${key}Ta']);
    final en = jStr(m['${key}En']);
    return (app.lang == 'ta' && ta.isNotEmpty) ? ta : en;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_error != null) {
      body = EmptyState(
        icon: Icons.cloud_off,
        title: app.tr('Could not load', 'ஏற்ற முடியவில்லை'),
        message: _error!,
      );
    } else if (_items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items!.isEmpty) {
      body = EmptyState(
        icon: Icons.inbox_outlined,
        title: app.tr('Nothing sent yet', 'இன்னும் எதுவும் அனுப்பவில்லை'),
        message: app.tr('Bus details you add will be listed here with their status.',
            'நீங்கள் சேர்க்கும் பேருந்து விவரங்கள் நிலையுடன் இங்கே தெரியும்.'),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _items!.length,
          separatorBuilder: (c, i) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final m = _items![i];
            final status = jStr(m['status']);
            final color = status == 'Approved' ? kGreen : (status == 'Rejected' ? kRed : kAmber);
            final label = status == 'Approved'
                ? app.tr('Approved', 'ஏற்கப்பட்டது')
                : (status == 'Rejected' ? app.tr('Rejected', 'நிராகரிக்கப்பட்டது') : app.tr('Waiting for check', 'சரிபார்ப்புக்காக காத்திருக்கிறது'));
            final isNew = jStr(m['kind']) == 'NewRoute';
            final note = jStr(m['reviewNote']);
            return SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${_place(m, 'from')} → ${_place(m, 'to')}', style: ts(16, weight: FontWeight.w800)),
                      ),
                      Pill(label, color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isNew ? app.tr('New bus', 'புதிய பேருந்து') : app.tr('Extra timing', 'கூடுதல் நேரம்')} · '
                    '${jInt(m['tripCount'])} ${app.tr('timings', 'நேரங்கள்')}',
                    style: ts(13, color: kMuted),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(note, style: ts(13, color: kRed, height: 1.35)),
                    ),
                ],
              ),
            );
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(app.tr('My entries', 'என் பதிவுகள்'))),
      body: body,
    );
  }
}
