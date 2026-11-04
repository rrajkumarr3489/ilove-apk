import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'bus/bus_api.dart';
import 'bus/bus_repo.dart';
import 'theme.dart';

const Color _cream = kBg;
const List<Color> _grad = [kBrandLight, kBrand];

List<BoxShadow> get _soft => [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 14, offset: const Offset(0, 5))];

class _St {
  final String key, en, ta;
  final IconData icon;
  final Color color, bg;
  const _St(this.key, this.en, this.ta, this.icon, this.color, this.bg);
}

const List<_St> _statuses = [
  _St('New', 'New', 'புதிய', Icons.fiber_new_rounded, Color(0xFF9A5B00), Color(0xFFFFF1D6)),
  _St('Seen', 'Seen', 'பார்த்தது', Icons.visibility_rounded, Color(0xFF6B6B76), Color(0xFFEFEFEF)),
  _St('InProgress', 'Working on it', 'சரிசெய்கிறோம்', Icons.build_rounded, Color(0xFF1A56C4), Color(0xFFE8F0FE)),
  _St('Fixed', 'Fixed', 'சரிசெய்யப்பட்டது', Icons.check_circle_rounded, Color(0xFF1B7A3A), Color(0xFFE6F6EA)),
  _St('Closed', 'Closed', 'முடிந்தது', Icons.lock_rounded, Color(0xFF555555), Color(0xFFEFEFEF)),
];

_St _stOf(String k) => _statuses.firstWhere((s) => s.key == k, orElse: () => _statuses.first);

class _Ty {
  final String en, ta;
  final IconData icon;
  final Color color;
  const _Ty(this.en, this.ta, this.icon, this.color);
}

_Ty _tyOf(String k) {
  switch (k) {
    case 'Bug':
      return const _Ty('App problem', 'ஆப் சிக்கல்', Icons.bug_report_rounded, Color(0xFFE53935));
    case 'WrongInfo':
      return const _Ty('Wrong information', 'தவறான தகவல்', Icons.report_problem_rounded, Color(0xFFF59E0B));
    case 'Suggestion':
      return const _Ty('Suggestion', 'ஆலோசனை', Icons.lightbulb_rounded, Color(0xFF2E7D32));
    default:
      return const _Ty('Other', 'மற்றவை', Icons.chat_bubble_rounded, Color(0xFF1A56C4));
  }
}

/// For the approvers: all reports sent from the app, with status and reply.
class ReportsAdminScreen extends StatefulWidget {
  const ReportsAdminScreen({super.key});

  @override
  State<ReportsAdminScreen> createState() => _ReportsAdminScreenState();
}

class _ReportsAdminScreenState extends State<ReportsAdminScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final d = await BusApi.get('/approvals/reports');
      final list = <Map<String, dynamic>>[];
      if (d is List) {
        for (final e in d) {
          if (e is Map) list.add(Map<String, dynamic>.from(e));
        }
      }
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  int _count(String s) => _items.where((e) => e['status'] == s).length;

  List<Map<String, dynamic>> get _shown {
    return _items.where((e) {
      final s = (e['status'] ?? 'New').toString();
      if (_filter == 'all') return true;
      if (_filter == 'open') return s == 'New' || s == 'Seen' || s == 'InProgress';
      return s == _filter;
    }).toList();
  }

  static const List<String> _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _when(dynamic v) {
    final raw = (v ?? '').toString();
    final d = DateTime.tryParse(raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z');
    if (d == null) return '';
    final l = d.toLocal();
    final diff = DateTime.now().difference(l);
    if (diff.inMinutes < 1) return app.tr('Just now', 'இப்போது');
    if (diff.inMinutes < 60) return app.tr('${diff.inMinutes} min ago', '${diff.inMinutes} நிமிடம் முன்');
    if (diff.inHours < 24) return app.tr('${diff.inHours} hr ago', '${diff.inHours} மணி முன்');
    if (diff.inDays < 7) return app.tr('${diff.inDays} days ago', '${diff.inDays} நாள் முன்');
    return '${l.day} ${_mon[l.month - 1]} ${l.year}';
  }

  Future<void> _update(Map<String, dynamic> n) async {
    final res = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpdateSheet(report: n),
    );
    if (res == null) return;
    try {
      await BusApi.post('/approvals/reports/${n['reportId']}/status', {'status': res['status'], 'reply': res['reply']});
      _toast(app.tr('Saved. The sender is told.', 'சேமிக்கப்பட்டது. அனுப்பியவருக்குத் தெரிவிக்கப்படும்.'));
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  Future<void> _delete(Map<String, dynamic> n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(app.tr('Delete this report?', 'இந்தப் புகாரை நீக்கவா?'), style: ts(17, weight: FontWeight.w900)),
        content: Text(app.tr('It will be removed from the list.', 'பட்டியலில் இருந்து நீக்கப்படும்.'), style: ts(14, color: kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.tr('No', 'வேண்டாம்'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: Text(app.tr('Delete', 'நீக்கு')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await BusApi.post('/approvals/reports/${n['reportId']}/delete', {});
      await _load();
    } catch (e) {
      _toast(e.toString());
    }
  }

  void _showImage(String file) {
    final url = repo.mediaUrl(file);
    if (url == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          InteractiveViewer(child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain))),
          Positioned(
            right: 6,
            top: 6,
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _call(String mobile) async {
    try {
      await launchUrl(Uri.parse('tel:$mobile'));
    } catch (_) {}
  }

  Widget _stat(String label, int n, Color c, IconData ic) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: _soft),
        child: Column(children: [
          Icon(ic, color: c, size: 20),
          const SizedBox(height: 4),
          Text('$n', style: ts(20, weight: FontWeight.w900, color: c)),
          Text(label, style: ts(11, color: kMuted, weight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _pill(String key, String label) {
    final on = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filter = key),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: on ? const LinearGradient(colors: _grad) : null,
            color: on ? null : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: on ? Colors.transparent : kLine),
          ),
          child: Text(label, style: ts(13, weight: FontWeight.w800, color: on ? Colors.white : kMuted)),
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> n) {
    final st = _stOf((n['status'] ?? 'New').toString());
    final ty = _tyOf((n['reportType'] ?? '').toString());
    final ref = (n['refText'] ?? '').toString();
    final msg = (n['message'] ?? '').toString();
    final shot = (n['screenshotFile'] ?? '').toString();
    final reply = (n['adminReply'] ?? '').toString();
    final name = (n['displayName'] ?? '').toString();
    final mobile = (n['mobile'] ?? '').toString();
    final dev = [
      if ((n['phoneModel'] ?? '').toString().trim().isNotEmpty) n['phoneModel'].toString().trim(),
      if ((n['androidVersion'] ?? '').toString().isNotEmpty) 'Android ${n['androidVersion']}',
      if ((n['appVersion'] ?? '').toString().isNotEmpty) 'App ${n['appVersion']}',
    ].join('  ·  ');
    final isNew = st.key == 'New';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _soft,
        border: Border.all(color: isNew ? const Color(0xFFF5C26B) : Colors.transparent, width: isNew ? 1.6 : 0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: ty.color.withAlpha(30), shape: BoxShape.circle),
              child: Icon(ty.icon, color: ty.color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(app.tr(ty.en, ty.ta), style: ts(14.5, weight: FontWeight.w900)),
                Text(_when(n['createdAt']), style: ts(11.5, color: kMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(st.icon, size: 14, color: st.color),
                const SizedBox(width: 5),
                Text(app.tr(st.en, st.ta), style: ts(11.5, weight: FontWeight.w800, color: st.color)),
              ]),
            ),
          ]),
          if (ref.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.directions_bus_rounded, size: 18, color: Color(0xFF1A56C4)),
                const SizedBox(width: 8),
                Expanded(child: Text(ref, style: ts(13, weight: FontWeight.w800, color: const Color(0xFF123F91), height: 1.3))),
              ]),
            ),
          if (msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(msg, style: ts(15, height: 1.42)),
            ),
          if (shot.isNotEmpty && repo.mediaUrl(shot) != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: InkWell(
                onTap: () => _showImage(shot),
                borderRadius: BorderRadius.circular(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(children: [
                    CachedNetworkImage(imageUrl: repo.mediaUrl(shot)!, height: 120, width: 120, fit: BoxFit.cover),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.zoom_out_map_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kBrand.withAlpha(30),
              child: Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: ts(14, weight: FontWeight.w900, color: kBrand)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isNotEmpty ? name : app.tr('User', 'பயனர்'), style: ts(13.5, weight: FontWeight.w800)),
                if (mobile.isNotEmpty) Text(mobile, style: ts(12, color: kMuted)),
              ]),
            ),
            if (mobile.isNotEmpty)
              IconButton.filledTonal(
                onPressed: () => _call(mobile),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFE6F6EA)),
                icon: const Icon(Icons.call_rounded, size: 19, color: Color(0xFF1B7A3A)),
              ),
          ]),
          if (dev.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.phone_android_rounded, size: 15, color: kMuted),
                const SizedBox(width: 6),
                Expanded(child: Text(dev, style: ts(11.5, color: kMuted))),
              ]),
            ),
          if (reply.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFE6F6EA), borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.reply_rounded, size: 18, color: Color(0xFF1B7A3A)),
                const SizedBox(width: 8),
                Expanded(child: Text(reply, style: ts(13.5, color: const Color(0xFF14532D), height: 1.4))),
              ]),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _update(n),
                style: FilledButton.styleFrom(backgroundColor: kBrand, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                icon: const Icon(Icons.edit_note_rounded, size: 21),
                label: Text(app.tr('Update / Reply', 'நிலை / பதில்'), style: ts(14, weight: FontWeight.w800, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: () => _delete(n),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFFDE8E8), padding: const EdgeInsets.all(12)),
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _empty() {
    return ListView(children: [
      const SizedBox(height: 70),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: kBrand.withAlpha(28), shape: BoxShape.circle),
          child: const Icon(Icons.inbox_rounded, size: 48, color: kBrand),
        ),
      ),
      const SizedBox(height: 18),
      Center(child: Text(app.tr('No reports here', 'புகார்கள் எதுவும் இல்லை'), style: ts(18, weight: FontWeight.w900))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final list = _shown;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        title: Text(app.tr('Reports', 'புகார்கள்'), style: ts(19, weight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 140), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(children: [const SizedBox(height: 120), Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)))])
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                    children: [
                      Row(children: [
                        _stat(app.tr('New', 'புதிய'), _count('New'), kBrand, Icons.fiber_new_rounded),
                        const SizedBox(width: 10),
                        _stat(app.tr('In progress', 'நடப்பில்'), _count('InProgress'), const Color(0xFF1A56C4), Icons.build_rounded),
                        const SizedBox(width: 10),
                        _stat(app.tr('Fixed', 'சரியானது'), _count('Fixed'), const Color(0xFF1B7A3A), Icons.check_circle_rounded),
                      ]),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _pill('open', app.tr('Open', 'திறந்தவை')),
                          _pill('all', app.tr('All', 'அனைத்தும்')),
                          _pill('Fixed', app.tr('Fixed', 'சரியானது')),
                          _pill('Closed', app.tr('Closed', 'முடிந்தது')),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      if (list.isEmpty) SizedBox(height: 300, child: _empty()) else ...list.map(_card),
                    ],
                  ),
      ),
    );
  }
}

class _UpdateSheet extends StatefulWidget {
  final Map<String, dynamic> report;
  const _UpdateSheet({required this.report});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  late String _status;
  final TextEditingController _reply = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = (widget.report['status'] ?? 'New').toString();
    _status = s == 'New' ? 'Seen' : s;
    _reply.text = (widget.report['adminReply'] ?? '').toString();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  List<List<String>> get _quick => [
        [app.tr('We are checking this.', 'இதைப் பார்த்துக்கொண்டிருக்கிறோம்.'), 'InProgress'],
        [app.tr('Fixed. Thank you for telling us!', 'சரிசெய்துவிட்டோம். தெரிவித்ததற்கு நன்றி!'), 'Fixed'],
        [app.tr('Thank you for your suggestion.', 'உங்கள் ஆலோசனைக்கு நன்றி.'), 'Closed'],
      ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: kLine, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              Text(app.tr('Update report', 'புகார் நிலை'), style: ts(19, weight: FontWeight.w900)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in _statuses.where((e) => e.key != 'New'))
                  ChoiceChip(
                    avatar: Icon(s.icon, size: 17, color: _status == s.key ? Colors.white : s.color),
                    label: Text(app.tr(s.en, s.ta)),
                    selected: _status == s.key,
                    showCheckmark: false,
                    selectedColor: s.color,
                    labelStyle: ts(13, weight: FontWeight.w800, color: _status == s.key ? Colors.white : const Color(0xFF1C1B1F)),
                    onSelected: (_) => setState(() => _status = s.key),
                  ),
              ]),
              const SizedBox(height: 16),
              Text(app.tr('Reply to the sender (optional)', 'அனுப்பியவருக்குப் பதில் (விருப்பம்)'), style: ts(13.5, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final q in _quick)
                  ActionChip(
                    label: Text(q[0], style: ts(12, weight: FontWeight.w700)),
                    backgroundColor: kTint,
                    side: BorderSide(color: kBrand.withAlpha(70)),
                    onPressed: () => setState(() {
                      _reply.text = q[0];
                      _status = q[1];
                    }),
                  ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: _reply,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: app.tr('Write a reply...', 'பதில் எழுதுங்கள்...'),
                  filled: true,
                  fillColor: _cream,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: _grad),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: kBrand.withAlpha(80), blurRadius: 12, offset: const Offset(0, 5))],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(context, {'status': _status, 'reply': _reply.text.trim()}),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.check_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(app.tr('Save & tell the sender', 'சேமித்து தெரிவி'), style: ts(15.5, weight: FontWeight.w900, color: Colors.white)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
