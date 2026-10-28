import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'auth/auth_guard.dart';
import 'bus/bus_api.dart';
import 'share_util.dart';
import 'theme.dart';

const Color _kCream = Color(0xFFFFF6EC);
const Color _kJobBlue = Color(0xFF1565C0);

/// Picks the Tamil or English text of a field (falls back to the other language when empty).
String _pick(Map<String, dynamic> m, String base) {
  final ta = (m['${base}Ta'] ?? '').toString().trim();
  final en = (m['${base}En'] ?? '').toString().trim();
  if (app.lang == 'ta') return ta.isNotEmpty ? ta : en;
  return en.isNotEmpty ? en : ta;
}

String _s(Map<String, dynamic> m, String key) => (m[key] ?? '').toString().trim();

String _empLabel(String e) {
  switch (e) {
    case 'PartTime':
      return app.tr('Part time', 'பகுதி நேரம்');
    case 'Daily':
      return app.tr('Daily wages', 'தினக்கூலி');
    case 'Internship':
      return app.tr('Internship', 'பயிற்சி');
    default:
      return app.tr('Full time', 'முழு நேரம்');
  }
}

String _date(String iso) => iso.length >= 10 ? '${iso.substring(8, 10)}-${iso.substring(5, 7)}-${iso.substring(0, 4)}' : iso;

List<Map<String, dynamic>> _maps(dynamic d) {
  final out = <Map<String, dynamic>>[];
  if (d is List) {
    for (final e in d) {
      if (e is Map) out.add(Map<String, dynamic>.from(e));
    }
  }
  return out;
}

/// The text that is shared for one job (WhatsApp, Facebook ...).
String jobShareText(Map<String, dynamic> j) {
  final b = StringBuffer();
  b.writeln('💼 ${_pick(j, 'title')}');
  final company = _s(j, 'company');
  final place = _s(j, 'locationText');
  if (company.isNotEmpty) b.writeln(company);
  if (place.isNotEmpty) b.writeln('📍 $place');
  final salary = _s(j, 'salaryText');
  if (salary.isNotEmpty) b.writeln('💰 $salary');
  final phone = _s(j, 'contactPhone');
  if (phone.isNotEmpty) b.writeln('📞 $phone');
  final link = _s(j, 'applyUrl');
  if (link.isNotEmpty) b.writeln(link);
  b.writeln();
  b.write(shareFooter());
  return b.toString();
}

/// The text that is shared for one news item.
String newsShareText(String title, String link) {
  final b = StringBuffer();
  b.writeln('📰 $title');
  if (link.isNotEmpty) b.writeln(link);
  b.writeln();
  b.write(shareFooter());
  return b.toString();
}

Future<void> openAddJob(BuildContext context, {Map<String, dynamic>? existing}) async {
  final ok = await requireLogin(
    context,
    whyEn: 'To add a job you must be registered, so we know who sent it. You can still see all jobs as a guest.',
    whyTa: 'வேலையைச் சேர்க்க நீங்கள் பதிவு செய்திருக்க வேண்டும் - யார் அனுப்பினார்கள் என்பது தெரிய வேண்டும். விருந்தினராக வேலைகளைப் பார்க்கலாம்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push<bool>(context, MaterialPageRoute<bool>(builder: (_) => AddJobScreen(existing: existing)));
}

Future<void> openMyJobs(BuildContext context) async {
  final ok = await requireLogin(
    context,
    whyEn: 'Please log in to see the jobs you sent.',
    whyTa: 'நீங்கள் அனுப்பிய வேலைகளைப் பார்க்க உள்நுழையுங்கள்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MyJobsScreen()));
}

// ---------------------------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------------------------

/// Classifieds - Jobs: filter by type, search, open a job, share, add your own.
class ClassifiedsScreen extends StatefulWidget {
  const ClassifiedsScreen({super.key});

  @override
  State<ClassifiedsScreen> createState() => _ClassifiedsScreenState();
}

class _ClassifiedsScreenState extends State<ClassifiedsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _types = [];
  int? _typeId;
  String _query = '';
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadCached();
    _load();
  }

  void _loadCached() {
    try {
      final j = app.getString('jobs.json');
      final t = app.getString('jobtypes.json');
      if (j != null) _jobs = _maps(jsonDecode(j));
      if (t != null) _types = _maps(jsonDecode(t));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final t = await BusApi.get('/jobs/types');
      final j = await BusApi.get('/jobs', query: {'top': '100'});
      await app.setString('jobtypes.json', jsonEncode(t));
      await app.setString('jobs.json', jsonEncode(j));
      if (!mounted) return;
      setState(() {
        _types = _maps(t);
        _jobs = _maps(j);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = _jobs.isEmpty;
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _shown {
    final q = _query.trim().toLowerCase();
    return _jobs.where((j) {
      if (_typeId != null && (j['jobTypeId'] as num?)?.toInt() != _typeId) return false;
      if (q.isNotEmpty) {
        final hay = '${_s(j, 'titleEn')} ${_s(j, 'titleTa')} ${_s(j, 'company')} ${_s(j, 'locationText')}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: ts(13, weight: FontWeight.w700, color: on ? Colors.white : kInk)),
        selected: on,
        showCheckmark: false,
        selectedColor: _kJobBlue,
        backgroundColor: Colors.white,
        side: BorderSide(color: on ? _kJobBlue : kLine),
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final list = _shown;
        return Scaffold(
          backgroundColor: _kCream,
          appBar: AppBar(
            backgroundColor: _kCream,
            title: Text(app.tr('Jobs', 'வேலை வாய்ப்புகள்'), style: ts(19, weight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: app.tr('My jobs', 'நான் அனுப்பிய வேலைகள்'),
                icon: const Icon(Icons.list_alt),
                onPressed: () => openMyJobs(context),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: kBrand,
            foregroundColor: Colors.white,
            onPressed: () => openAddJob(context),
            icon: const Icon(Icons.add),
            label: Text(app.tr('Add job', 'வேலை சேர்க்க')),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: app.tr('Search jobs, shops, places', 'வேலை, கடை, இடம் தேடுங்கள்'),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: kLine)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide(color: kLine)),
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    _chip(app.tr('All', 'அனைத்தும்'), _typeId == null, () => setState(() => _typeId = null)),
                    for (final t in _types)
                      _chip(_pick(t, 'name'), _typeId == (t['jobTypeId'] as num?)?.toInt(),
                          () => setState(() => _typeId = (t['jobTypeId'] as num?)?.toInt())),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: list.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 110),
                            Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 30),
                                      child: Text(
                                        _failed
                                            ? app.tr('Could not load jobs. Pull down to try again.', 'வேலைகளை ஏற்ற முடியவில்லை. கீழே இழுத்து மீண்டும் முயற்சிக்கவும்.')
                                            : app.tr('No jobs here yet.', 'இங்கே வேலைகள் இன்னும் இல்லை.'),
                                        textAlign: TextAlign.center,
                                        style: ts(15, color: kMuted),
                                      ),
                                    ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                          itemCount: list.length,
                          itemBuilder: (c, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _JobCard(job: list[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _pill(String text, {Color bg = const Color(0xFFF1EDE6), Color? fgColor, IconData? icon}) {
  final fg = fgColor ?? kInk;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 3)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11.5, weight: FontWeight.w700, color: fg))),
      ],
    ),
  );
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const _JobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final company = _s(job, 'company');
    final place = _s(job, 'locationText');
    final salary = _s(job, 'salaryText');
    final sub = [company, place].where((e) => e.isNotEmpty).join(' • ');
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => JobDetailScreen(job: job))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: _kJobBlue.withAlpha(24), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.work_outline, color: _kJobBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pick(job, 'title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w800, height: 1.25)),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, color: kMuted)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (salary.isNotEmpty) _pill(salary, bg: const Color(0xFFE6F6EA), fgColor: const Color(0xFF1B7A3A), icon: Icons.currency_rupee),
                    _pill(_empLabel(_s(job, 'employmentType'))),
                    _pill(_pick(job, 'typeName'), bg: _kJobBlue.withAlpha(20), fgColor: _kJobBlue),
                    _pill(_date(_s(job, 'postedOn')), icon: Icons.schedule),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: app.tr('Share', 'பகிர்'),
            icon: const Icon(Icons.share_outlined, size: 20, color: kNavy),
            onPressed: () => showShareSheet(context, text: jobShareText(job), link: _s(job, 'applyUrl')),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------------------------

class JobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  String _digits(String phone) {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 10) d = '91$d';
    return d;
  }

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(app.tr('Could not open it.', 'திறக்க முடியவில்லை.'))));
  }

  Widget _row(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: kBrand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ts(11.5, color: kMuted, weight: FontWeight.w700)),
                const SizedBox(height: 1),
                Text(value, style: ts(14.5, weight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final phone = _s(job, 'contactPhone');
        final link = _s(job, 'applyUrl');
        final desc = _pick(job, 'description');
        final isAuto = job['isAuto'] == true;
        final cname = _s(job, 'contactName');
        return Scaffold(
          backgroundColor: _kCream,
          appBar: AppBar(
            backgroundColor: _kCream,
            title: Text(app.tr('Job details', 'வேலை விவரம்'), style: ts(19, weight: FontWeight.w900)),
            actions: [
              IconButton(
                tooltip: app.tr('Share', 'பகிர்'),
                icon: const Icon(Icons.share_outlined),
                onPressed: () => showShareSheet(context, text: jobShareText(job), link: link),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            children: [
              Text(_pick(job, 'title'), style: ts(21, weight: FontWeight.w900, height: 1.25)),
              if (_s(job, 'company').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(_s(job, 'company'), style: ts(15, color: kMuted, weight: FontWeight.w600)),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill(_pick(job, 'typeName'), bg: _kJobBlue.withAlpha(20), fgColor: _kJobBlue),
                  _pill(_empLabel(_s(job, 'employmentType'))),
                  if (isAuto) _pill(app.tr('From news', 'செய்தி மூலம்'), bg: const Color(0xFFE8F0FE), fgColor: const Color(0xFF1A56C4)),
                ],
              ),
              const SizedBox(height: 16),
              SoftCard(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    _row(Icons.currency_rupee, app.tr('Salary', 'சம்பளம்'), _s(job, 'salaryText')),
                    _row(Icons.place_outlined, app.tr('Place', 'இடம்'), _s(job, 'locationText')),
                    _row(Icons.person_outline, app.tr('Contact person', 'தொடர்புக்கு'), cname),
                    _row(Icons.call_outlined, app.tr('Phone', 'தொலைபேசி'), phone),
                    _row(Icons.schedule, app.tr('Posted on', 'பதிவு செய்த நாள்'), _date(_s(job, 'postedOn'))),
                    _row(Icons.event_busy_outlined, app.tr('Valid till', 'கடைசி நாள்'), _date(_s(job, 'expiresOn'))),
                  ],
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 14),
                SoftCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.tr('Details', 'விவரங்கள்'), style: ts(14, weight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(desc, style: ts(14.5, height: 1.45)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (phone.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(context, 'tel:${phone.replaceAll(' ', '')}'),
                        style: FilledButton.styleFrom(backgroundColor: kBrand, padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: const Icon(Icons.call),
                        label: Text(app.tr('Call', 'அழை'), style: ts(15, weight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _open(context, 'https://wa.me/${_digits(phone)}'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 14)),
                        icon: const Icon(Icons.chat),
                        label: Text('WhatsApp', style: ts(15, weight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              if (link.isNotEmpty) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _open(context, link),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.open_in_new),
                  label: Text(isAuto ? app.tr('Open original post', 'மூலச் செய்தியைத் திற') : app.tr('Apply / more details', 'விண்ணப்பிக்க / மேலும்'),
                      style: ts(15, weight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFF9A5B00), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        app.tr('Be careful: never pay money to get a job. Check the employer before you go.',
                            'கவனம்: வேலை கிடைக்க ஒருபோதும் பணம் செலுத்த வேண்டாம். செல்வதற்கு முன் நிறுவனத்தைச் சரிபார்க்கவும்.'),
                        style: ts(12.5, color: const Color(0xFF6B4400), height: 1.35),
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

// ---------------------------------------------------------------------------------------------
// Add / change a job
// ---------------------------------------------------------------------------------------------

final RegExp _tamilChars = RegExp(r'[஀-௿]');

class AddJobScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AddJobScreen({super.key, this.existing});

  @override
  State<AddJobScreen> createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _place = TextEditingController(text: 'அருப்புக்கோட்டை');
  final TextEditingController _salary = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _cname = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _link = TextEditingController();
  List<Map<String, dynamic>> _types = [];
  int? _typeId;
  String _emp = 'FullTime';
  bool _saving = false;

  int? get _id => widget.existing == null ? null : (widget.existing!['jobId'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _title.text = _pick(e, 'title');
      _company.text = _s(e, 'company');
      _place.text = _s(e, 'locationText');
      _salary.text = _s(e, 'salaryText');
      _desc.text = _pick(e, 'description');
      _cname.text = _s(e, 'contactName');
      _phone.text = _s(e, 'contactPhone');
      _link.text = _s(e, 'applyUrl');
      _typeId = (e['jobTypeId'] as num?)?.toInt();
      final emp = _s(e, 'employmentType');
      if (emp.isNotEmpty) _emp = emp;
    }
    _loadTypes();
  }

  @override
  void dispose() {
    for (final c in [_title, _company, _place, _salary, _desc, _cname, _phone, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTypes() async {
    try {
      final cached = app.getString('jobtypes.json');
      if (cached != null && _types.isEmpty) _types = _maps(jsonDecode(cached));
    } catch (_) {}
    if (mounted) setState(() {});
    try {
      final t = _maps(await BusApi.get('/jobs/types'));
      if (!mounted) return;
      setState(() => _types = t);
    } catch (_) {}
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _save() async {
    final title = _title.text.trim();
    final phone = _phone.text.trim();
    final link = _link.text.trim();
    if (title.isEmpty) {
      _msg(app.tr('Please write the job title.', 'வேலையின் தலைப்பை எழுதுங்கள்.'));
      return;
    }
    if (_typeId == null) {
      _msg(app.tr('Please choose the job type.', 'வேலை வகையைத் தேர்ந்தெடுங்கள்.'));
      return;
    }
    if (phone.isEmpty && link.isEmpty) {
      _msg(app.tr('Give a phone number or an apply link.', 'தொலைபேசி எண் அல்லது இணைப்பைக் கொடுங்கள்.'));
      return;
    }
    // One box for the title and one for the details: they are saved under Tamil or English by the letters used.
    final titleIsTamil = _tamilChars.hasMatch(title);
    final desc = _desc.text.trim();
    final descIsTamil = _tamilChars.hasMatch(desc);
    setState(() => _saving = true);
    try {
      final body = {
        'jobTypeId': _typeId,
        'titleTa': titleIsTamil ? title : '',
        'titleEn': titleIsTamil ? '' : title,
        'company': _company.text.trim(),
        'locationText': _place.text.trim(),
        'salaryText': _salary.text.trim(),
        'employmentType': _emp,
        'descriptionTa': descIsTamil ? desc : '',
        'descriptionEn': descIsTamil ? '' : desc,
        'contactName': _cname.text.trim(),
        'contactPhone': phone,
        'applyUrl': link,
      };
      await BusApi.post(_id == null ? '/jobs/mine' : '/jobs/mine/$_id', body);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 36),
          title: Text(app.tr('Job saved', 'வேலை சேமிக்கப்பட்டது')),
          content: Text(app.tr('Thank you! Your job will appear for everyone after it is approved.',
              'நன்றி! ஒப்புதல் கிடைத்த பிறகு உங்கள் வேலை அனைவருக்கும் தெரியும்.')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('OK', 'சரி')))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _msg(BusApi.friendly(e));
      }
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kCream,
        title: Text(_id == null ? app.tr('Add job', 'வேலை சேர்க்க') : app.tr('Change job', 'வேலையை மாற்று'), style: ts(19, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFF9A5B00), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.tr('Your job is saved first. It is shown to everyone only after approval.',
                        'உங்கள் வேலை முதலில் சேமிக்கப்படும். ஒப்புதலுக்குப் பிறகே அனைவருக்கும் தெரியும்.'),
                    style: ts(13, color: const Color(0xFF6B4400), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: _dec(app.tr('Job type', 'வேலை வகை')),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _types.any((t) => (t['jobTypeId'] as num?)?.toInt() == _typeId) ? _typeId : null,
                isExpanded: true,
                isDense: true,
                hint: Text(app.tr('Choose', 'தேர்ந்தெடுங்கள்')),
                items: [
                  for (final t in _types)
                    DropdownMenuItem<int>(value: (t['jobTypeId'] as num?)?.toInt(), child: Text(_pick(t, 'name'), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _typeId = v),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 200,
            decoration: _dec(app.tr('Job title', 'வேலையின் தலைப்பு'), hint: app.tr('Example: Shop assistant', 'எ.கா: கடை உதவியாளர்')),
          ),
          const SizedBox(height: 4),
          TextField(controller: _company, maxLength: 200, decoration: _dec(app.tr('Shop / company name', 'கடை / நிறுவனத்தின் பெயர்'))),
          const SizedBox(height: 4),
          TextField(controller: _place, maxLength: 200, decoration: _dec(app.tr('Place', 'இடம்'))),
          const SizedBox(height: 4),
          TextField(
            controller: _salary,
            maxLength: 100,
            decoration: _dec(app.tr('Salary (optional)', 'சம்பளம் (விருப்பம்)'), hint: app.tr('12,000 per month', 'மாதம் 12,000')),
          ),
          const SizedBox(height: 4),
          Text(app.tr('Work type', 'வேலை நேரம்'), style: ts(13, weight: FontWeight.w700, color: kMuted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final e in const ['FullTime', 'PartTime', 'Daily', 'Internship'])
                ChoiceChip(
                  label: Text(_empLabel(e), style: ts(13, weight: FontWeight.w700, color: _emp == e ? Colors.white : kInk)),
                  selected: _emp == e,
                  showCheckmark: false,
                  selectedColor: kBrand,
                  onSelected: (_) => setState(() => _emp = e),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: _dec(app.tr('Details (optional)', 'விவரங்கள் (விருப்பம்)'), hint: app.tr('Qualification, timing, how to apply', 'தகுதி, நேரம், எப்படி விண்ணப்பிப்பது')),
          ),
          const SizedBox(height: 4),
          TextField(controller: _cname, maxLength: 100, decoration: _dec(app.tr('Contact person', 'தொடர்பு கொள்ள வேண்டியவர்'))),
          const SizedBox(height: 4),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 20,
            decoration: _dec(app.tr('Contact phone', 'தொலைபேசி எண்')),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: _dec(app.tr('Apply link (optional)', 'விண்ணப்ப இணைப்பு (விருப்பம்)'), hint: 'https://...'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: kBrand, padding: const EdgeInsets.symmetric(vertical: 15)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(app.tr('Save', 'சேமி'), style: ts(16, weight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------------------------
// My jobs
// ---------------------------------------------------------------------------------------------

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await BusApi.get('/jobs/mine');
      if (!mounted) return;
      setState(() {
        _items = _maps(d);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = BusApi.friendly(e);
        _loading = false;
      });
    }
  }

  Widget _chip(String status) {
    late Color bg;
    late Color fg;
    late String text;
    switch (status) {
      case 'Approved':
        bg = const Color(0xFFE6F6EA);
        fg = const Color(0xFF1B7A3A);
        text = app.tr('Approved', 'ஒப்புதல் கிடைத்தது');
        break;
      case 'Rejected':
        bg = const Color(0xFFFDE8E8);
        fg = const Color(0xFFB3261E);
        text = app.tr('Not approved', 'ஒப்புதல் இல்லை');
        break;
      default:
        bg = const Color(0xFFFFF1D6);
        fg = const Color(0xFF9A5B00);
        text = app.tr('Waiting for approval', 'ஒப்புதலுக்காக காத்திருக்கிறது');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: ts(11.5, weight: FontWeight.w800, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kCream,
        title: Text(app.tr('My jobs', 'நான் அனுப்பிய வேலைகள்'), style: ts(19, weight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: () async {
          await openAddJob(context);
          if (mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(app.tr('Add job', 'வேலை சேர்க்க')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 140), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(children: [const SizedBox(height: 120), Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)))])
                : _items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Center(child: Text(app.tr('You have not sent any job yet.', 'நீங்கள் இன்னும் வேலை எதுவும் அனுப்பவில்லை.'), style: ts(15, color: kMuted))),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                        children: [
                          for (final j in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SoftCard(
                                onTap: () async {
                                  await openAddJob(context, existing: j);
                                  if (mounted) _load();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_pick(j, 'title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w700, height: 1.3)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _chip(_s(j, 'status')),
                                        const Spacer(),
                                        const Icon(Icons.edit_outlined, size: 18, color: kMuted),
                                      ],
                                    ),
                                    if (_s(j, 'status') == 'Rejected' && _s(j, 'reviewNote').isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(_s(j, 'reviewNote'), style: ts(12.5, color: kMuted)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}
