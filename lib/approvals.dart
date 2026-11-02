import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'bus/bus_api.dart';
import 'bus/bus_repo.dart';
import 'theme.dart';

const Color _kCream = Color(0xFFFFF6EC);
const Color _kOk = Color(0xFF1B7A3A);
const Color _kBad = Color(0xFFB3261E);

String _s(Map<String, dynamic> m, String key) => (m[key] ?? '').toString().trim();

String _pick(Map<String, dynamic> m, String base) {
  final ta = _s(m, '${base}Ta');
  final en = _s(m, '${base}En');
  if (app.lang == 'ta') return ta.isNotEmpty ? ta : en;
  return en.isNotEmpty ? en : ta;
}

/// Reasons to pick when rejecting: [English, Tamil]. They come from the server (table dbo.RejectReasons);
/// this list is only used when the server does not send any. The first one is selected by default.
const List<List<String>> _reasons = [
  ['Adult / inappropriate content', 'ஆபாச / பொருத்தமற்ற உள்ளடக்கம்'],
  ['Harmful or violent content', 'வன்முறை / தீங்கு விளைவிக்கும் உள்ளடக்கம்'],
  ['False or misleading information', 'தவறான / பொய்யான தகவல்'],
  ['Spam or advertisement', 'ஸ்பேம் / விளம்பரம்'],
  ['Abusive or hateful language', 'அவதூறு / வெறுப்பு மொழி'],
  ['Other reason', 'வேறு காரணம்'],
];

List<Map<String, dynamic>> _maps(dynamic v) {
  if (v is! List) return <Map<String, dynamic>>[];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

/// For the people who approve: the news and jobs that are waiting, with Approve / Reject buttons.
class ApprovalsScreen extends StatefulWidget {
  /// 0 = News tab, 1 = Jobs tab (the one the alert was about).
  final int initialTab;

  const ApprovalsScreen({super.key, this.initialTab = 0});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _news = [];
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busy = <String>{};
  List<List<String>> _reasonList = _reasons;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab == 1 ? 1 : 0);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if ((app.token ?? '').isEmpty) {
      setState(() {
        _loading = false;
        _error = app.tr('Please log in first (use the same mobile number that gets the alerts).',
            'முதலில் உள்நுழையவும் (அலர்ட் வரும் அதே மொபைல் எண்ணில்).');
      });
      return;
    }
    try {
      final d = await BusApi.get('/approvals/pending');
      if (!mounted) return;
      final m = d is Map ? d : <dynamic, dynamic>{};
      setState(() {
        _news = _maps(m['news']);
        _jobs = _maps(m['jobs']);
        final rs = _maps(m['reasons'])
            .map((r) => <String>[_s(r, 'reasonEn'), _s(r, 'reasonTa').isNotEmpty ? _s(r, 'reasonTa') : _s(r, 'reasonEn')])
            .where((r) => r[0].isNotEmpty)
            .toList();
        if (rs.isNotEmpty) _reasonList = rs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = (e is ApiException && e.status == 403)
            ? app.tr('This mobile number is not allowed to approve.', 'இந்த மொபைல் எண்ணுக்கு ஒப்புதல் அளிக்க அனுமதி இல்லை.')
            : BusApi.friendly(e);
        _loading = false;
      });
    }
  }

  Future<String?> _askReason() async {
    final list = _reasonList;
    var chosen = 0;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
          contentPadding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: _kBad.withAlpha(28), shape: BoxShape.circle),
                child: const Icon(Icons.block, color: _kBad, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(app.tr('Why reject?', 'ஏன் நிராகரிக்கிறீர்கள்?'), style: ts(18, weight: FontWeight.w900))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < list.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setD(() => chosen = i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                      decoration: BoxDecoration(
                        color: chosen == i ? _kBad.withAlpha(18) : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: chosen == i ? _kBad : kLine),
                      ),
                      child: Row(
                        children: [
                          Icon(chosen == i ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: chosen == i ? _kBad : kMuted, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(app.lang == 'ta' ? list[i][1] : list[i][0],
                                style: ts(14.5, weight: chosen == i ? FontWeight.w800 : FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('Cancel', 'வேண்டாம்'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kBad, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12)),
              onPressed: () => Navigator.pop(ctx, '${list[chosen][0]} / ${list[chosen][1]}'),
              child: Text(app.tr('Reject', 'நிராகரி')),
            ),
          ],
        ),
      ),
    );
    return r;
  }

  Future<void> _act(String kind, Map<String, dynamic> item, bool approve) async {
    final id = _s(item, kind == 'news' ? 'newsId' : 'jobId');
    if (id.isEmpty || _busy.contains('$kind$id')) return;
    String? note;
    if (!approve) {
      note = await _askReason();
      if (note == null) return;
    }
    setState(() => _busy.add('$kind$id'));
    try {
      await BusApi.post('/approvals/$kind/$id/${approve ? 'approve' : 'reject'}', <String, dynamic>{'note': note ?? ''});
      if (!mounted) return;
      setState(() {
        if (kind == 'news') {
          _news.remove(item);
        } else {
          _jobs.remove(item);
        }
        _busy.remove('$kind$id');
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? app.tr('Approved. It is live now.', 'ஒப்புதல் அளிக்கப்பட்டது. இப்போது அனைவருக்கும் தெரியும்.') : app.tr('Rejected.', 'நிராகரிக்கப்பட்டது.')),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove('$kind$id'));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(BusApi.friendly(e))));
    }
  }

  Widget _buttons(String kind, Map<String, dynamic> item) {
    final id = _s(item, kind == 'news' ? 'newsId' : 'jobId');
    final busy = _busy.contains('$kind$id');
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _kBad, side: const BorderSide(color: _kBad)),
            onPressed: busy ? null : () => _act(kind, item, false),
            icon: const Icon(Icons.close),
            label: Text(app.tr('Reject', 'நிராகரி')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _kOk),
            onPressed: busy ? null : () => _act(kind, item, true),
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(app.tr('Approve', 'ஒப்புதல்')),
          ),
        ),
      ],
    );
  }

  Widget _by(Map<String, dynamic> item) {
    final name = _s(item, 'submittedByName');
    final mobile = _s(item, 'submittedByMobile');
    final who = [name, mobile].where((x) => x.isNotEmpty).join(' · ');
    if (who.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(app.tr('From: $who', 'அனுப்பியவர்: $who'), style: ts(12.5, color: kMuted)),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kLine),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _newsCard(Map<String, dynamic> n) {
    final file = _s(n, 'imageFile');
    final img = file.isEmpty ? null : repo.mediaUrl(file);
    final link = _s(n, 'linkUrl');
    return _card(children: [
      if (img != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: img,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (c, u, e) => const SizedBox(height: 60, child: Center(child: Icon(Icons.image_not_supported_outlined))),
            ),
          ),
        ),
      Text(_pick(n, 'title'), style: ts(16, weight: FontWeight.w800)),
      _by(n),
      if (link.isNotEmpty)
        InkWell(
          onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12.5, color: const Color(0xFF1565C0))),
          ),
        ),
      const SizedBox(height: 12),
      _buttons('news', n),
    ]);
  }

  Widget _line(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: kMuted),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: ts(13.5))),
        ],
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> j) {
    final type = app.lang == 'ta'
        ? (_s(j, 'typeNameTa').isNotEmpty ? _s(j, 'typeNameTa') : _s(j, 'typeNameEn'))
        : (_s(j, 'typeNameEn').isNotEmpty ? _s(j, 'typeNameEn') : _s(j, 'typeNameTa'));
    final contact = [_s(j, 'contactName'), _s(j, 'contactPhone')].where((x) => x.isNotEmpty).join(' · ');
    final desc = _pick(j, 'description');
    return _card(children: [
      Text(_pick(j, 'title'), style: ts(16, weight: FontWeight.w800)),
      if (type.isNotEmpty) Text(type, style: ts(12.5, weight: FontWeight.w700, color: const Color(0xFF1565C0))),
      _by(j),
      _line(Icons.business_outlined, _s(j, 'company')),
      _line(Icons.place_outlined, _s(j, 'locationText')),
      _line(Icons.currency_rupee, _s(j, 'salaryText')),
      _line(Icons.call_outlined, contact),
      _line(Icons.link, _s(j, 'applyUrl')),
      if (desc.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(desc, maxLines: 4, overflow: TextOverflow.ellipsis, style: ts(13, color: kMuted)),
        ),
      const SizedBox(height: 12),
      _buttons('jobs', j),
    ]);
  }

  /// One tab: pull down to refresh; shows a spinner, the error, "nothing waiting" or the cards.
  Widget _tabBody(List<Map<String, dynamic>> items, Widget Function(Map<String, dynamic>) card) {
    return RefreshIndicator(
      color: kBrand,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          if (_loading && items.isEmpty)
            const Padding(padding: EdgeInsets.only(top: 100), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Text(_error!, textAlign: TextAlign.center, style: ts(15, color: kMuted)),
            )
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, size: 54, color: _kOk),
                  const SizedBox(height: 10),
                  Text(app.tr('Nothing is waiting for approval.', 'ஒப்புதலுக்கு எதுவும் காத்திருக்கவில்லை.'),
                      textAlign: TextAlign.center, style: ts(15, color: kMuted)),
                ],
              ),
            )
          else
            for (final i in items) card(i),
        ],
      ),
    );
  }

  /// One big switch button: icon, name and how many are waiting.
  Widget _pill(int index, IconData icon, String label, int count) {
    final on = _tabs.index == index;
    final dark = Color.lerp(kBrand, Colors.black, 0.2)!;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabs.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            gradient: on ? LinearGradient(colors: [kBrand, dark], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
            color: on ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: on ? [BoxShadow(color: kBrand.withAlpha(90), blurRadius: 12, offset: const Offset(0, 5))] : const [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: on ? Colors.white : kMuted),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(14.5, weight: FontWeight.w800, color: on ? Colors.white : kMuted)),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: on ? Colors.white : (count > 0 ? kBrand : kLine),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count',
                    textAlign: TextAlign.center,
                    style: ts(12.5, weight: FontWeight.w900, color: on ? kBrand : (count > 0 ? Colors.white : kMuted))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kCream,
        title: Text(app.tr('Approvals', 'ஒப்புதல்கள்'), style: ts(19, weight: FontWeight.w900)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kLine),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              children: [
                _pill(0, Icons.newspaper, app.tr('News', 'செய்திகள்'), _news.length),
                const SizedBox(width: 4),
                _pill(1, Icons.work_outline, app.tr('Jobs', 'வேலை வாய்ப்புகள்'), _jobs.length),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _tabBody(_news, _newsCard),
          _tabBody(_jobs, _jobCard),
        ],
      ),
    );
  }
}
