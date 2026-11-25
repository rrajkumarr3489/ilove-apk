import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_state.dart';
import 'auth/auth_guard.dart';
import 'bus/bus_api.dart';
import 'bus/bus_repo.dart';
import 'config.dart';
import 'theme.dart';

const Color _cream = kBg;

/// Opens the "Report an issue" form. Only logged-in people can report.
/// [refKind]/[refText] are filled when the report is about one item (e.g. a bus time).
Future<void> openReportIssue(BuildContext context, {String? refKind, int? refId, String? refText, String type = 'Bug'}) async {
  final ok = await requireLogin(
    context,
    whyEn: 'To report a problem you must be registered, so we can tell you when it is fixed.',
    whyTa: 'சிக்கலைத் தெரிவிக்க நீங்கள் பதிவு செய்திருக்க வேண்டும் - சரிசெய்ததும் உங்களுக்குத் தெரிவிக்க முடியும்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(builder: (_) => ReportIssueScreen(refKind: refKind, refId: refId, refText: refText, type: type)),
  );
}

Future<void> openMyReports(BuildContext context) async {
  final ok = await requireLogin(
    context,
    whyEn: 'Please log in to see your reports.',
    whyTa: 'உங்கள் புகார்களைப் பார்க்க உள்நுழையுங்கள்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MyReportsScreen()));
}

const List<Color> _grad = [kBrandLight, kBrand];

class _TypeInfo {
  final String key, en, ta;
  final IconData icon;
  final Color color;
  const _TypeInfo(this.key, this.en, this.ta, this.icon, this.color);
}

const List<_TypeInfo> _types = [
  _TypeInfo('Bug', 'App problem', 'ஆப் சிக்கல்', Icons.bug_report_rounded, Color(0xFFE53935)),
  _TypeInfo('WrongInfo', 'Wrong information', 'தவறான தகவல்', Icons.report_problem_rounded, Color(0xFFF59E0B)),
  _TypeInfo('Suggestion', 'Suggestion', 'ஆலோசனை', Icons.lightbulb_rounded, Color(0xFF2E7D32)),
  _TypeInfo('Other', 'Other', 'மற்றவை', Icons.chat_bubble_rounded, Color(0xFF1A56C4)),
];

_TypeInfo _typeOf(String key) => _types.firstWhere((t) => t.key == key, orElse: () => _types.last);

List<BoxShadow> get _soft => [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 14, offset: const Offset(0, 5))];

class ReportIssueScreen extends StatefulWidget {
  final String? refKind;
  final int? refId;
  final String? refText;
  final String type;

  const ReportIssueScreen({super.key, this.refKind, this.refId, this.refText, this.type = 'Bug'});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final TextEditingController _msg = TextEditingController();
  late String _type = widget.type;
  XFile? _picked;
  bool _saving = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  void _toast(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 75);
      if (x != null) setState(() => _picked = x);
    } catch (_) {
      _toast(app.tr('Could not open the gallery.', 'கேலரியைத் திறக்க முடியவில்லை.'));
    }
  }

  Future<Map<String, String>> _device() async {
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      return {'phoneModel': '${a.manufacturer} ${a.model}', 'androidVersion': a.version.release};
    } catch (_) {
      return {'phoneModel': '', 'androidVersion': ''};
    }
  }

  Future<void> _send() async {
    final hasRef = (widget.refText ?? '').isNotEmpty;
    if (_msg.text.trim().length < 3 && !hasRef) {
      _toast(app.tr('Please write a few words about the problem.', 'சிக்கலைப் பற்றி சில வார்த்தைகள் எழுதுங்கள்.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      String? shot;
      if (_picked != null) {
        final bytes = await _picked!.readAsBytes();
        final r = await BusApi.postBytes('/reports/image', bytes) as Map<String, dynamic>;
        shot = (r['file'] ?? '').toString();
      }
      final d = await _device();
      await BusApi.post('/reports', {
        'reportType': _type,
        'message': _msg.text.trim(),
        'screenshotFile': shot,
        'refKind': widget.refKind,
        'refId': widget.refId,
        'refText': widget.refText,
        'appVersion': kAppVersion,
        'phoneModel': d['phoneModel'],
        'androidVersion': d['androidVersion'],
        'lang': app.lang,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(color: Color(0xFFE6F6EA), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 44),
              ),
              const SizedBox(height: 16),
              Text(app.tr('Report sent', 'புகார் அனுப்பப்பட்டது'), style: ts(19, weight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(app.tr('Thank you! We will look into it and tell you here.', 'நன்றி! நாங்கள் பார்த்து இங்கே தெரிவிப்போம்.'),
                  textAlign: TextAlign.center, style: ts(14, color: kMuted, height: 1.4)),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: kBrand, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(app.tr('OK', 'சரி'), style: ts(15, weight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _toast(e.toString());
      }
    }
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: kBrand.withAlpha(70), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(color: Colors.white.withAlpha(60), shape: BoxShape.circle),
          child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.tr('Help us make it better', 'இன்னும் சிறப்பாக்க உதவுங்கள்'), style: ts(17, weight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            Text(app.tr('Found a problem? Tell us - we will fix it.', 'சிக்கல் உள்ளதா? சொல்லுங்கள் - சரிசெய்கிறோம்.'),
                style: ts(13, color: Colors.white.withAlpha(235), height: 1.35)),
          ]),
        ),
      ]),
    );
  }

  Widget _typeTile(_TypeInfo t) {
    final on = _type == t.key;
    return InkWell(
      onTap: _saving ? null : () => setState(() => _type = t.key),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: on ? t.color.withAlpha(24) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: on ? t.color : kLine, width: on ? 2 : 1),
          boxShadow: on ? null : _soft,
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: t.color.withAlpha(on ? 45 : 30), shape: BoxShape.circle),
            child: Icon(t.icon, color: t.color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(app.tr(t.en, t.ta), maxLines: 2, style: ts(13.5, weight: FontWeight.w800, height: 1.2))),
          if (on) Icon(Icons.check_circle_rounded, color: t.color, size: 19),
        ]),
      ),
    );
  }

  Widget _shot() {
    if (_picked != null) {
      return Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: _soft),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          Image.file(File(_picked!.path), fit: BoxFit.cover),
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _saving ? null : () => setState(() => _picked = null),
                child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.close_rounded, color: Colors.white, size: 20)),
              ),
            ),
          ),
        ]),
      );
    }
    return InkWell(
      onTap: _saving ? null : _pick,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        width: double.infinity,
        decoration: BoxDecoration(color: kTint, borderRadius: BorderRadius.circular(20), border: Border.all(color: kBrand.withAlpha(90), width: 1.4)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_photo_alternate_rounded, size: 30, color: kBrand),
          const SizedBox(width: 12),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.tr('Add a screenshot', 'ஸ்கிரீன்ஷாட் சேர்க்கவும்'), style: ts(14.5, weight: FontWeight.w800)),
              Text(app.tr('Optional - helps us understand faster', 'விருப்பம் - விரைவாகப் புரிந்துகொள்ள உதவும்'), style: ts(12, color: kMuted)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8, top: 18, left: 4), child: Text(t, style: ts(14, weight: FontWeight.w900)));

  @override
  Widget build(BuildContext context) {
    final hasRef = (widget.refText ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        title: Text(app.tr('Report an issue', 'சிக்கலைத் தெரிவி'), style: ts(19, weight: FontWeight.w900)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _grad),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: kBrand.withAlpha(80), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _saving ? null : _send,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (_saving)
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    else ...[
                      const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(app.tr('Send report', 'புகாரை அனுப்பு'), style: ts(16, weight: FontWeight.w900, color: Colors.white)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _hero(),
          if (hasRef)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.directions_bus_rounded, color: Color(0xFF1A56C4), size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.refText!, style: ts(13.5, weight: FontWeight.w800, color: const Color(0xFF123F91), height: 1.3))),
              ]),
            ),
          _label(app.tr('What is it about?', 'எதைப் பற்றி?')),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.25,
            children: [for (final t in _types) _typeTile(t)],
          ),
          _label(app.tr('Tell us what happened', 'என்ன நடந்தது என்று எழுதுங்கள்')),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: _soft),
            child: TextField(
              controller: _msg,
              maxLines: 6,
              minLines: 4,
              maxLength: 1000,
              style: ts(15, height: 1.4),
              decoration: InputDecoration(
                hintText: app.tr('Write here...', 'இங்கே எழுதுங்கள்...'),
                hintStyle: ts(15, color: kMuted),
                contentPadding: const EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
          _label(app.tr('Screenshot', 'ஸ்கிரீன்ஷாட்')),
          _shot(),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.phone_android_rounded, size: 16, color: kMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                app.tr('Your phone model, Android version and app version are sent with the report to help us fix it.',
                    'சரிசெய்ய உதவ, உங்கள் போன் மாடல், ஆண்ட்ராய்டு மற்றும் ஆப் பதிப்பு புகாருடன் அனுப்பப்படும்.'),
                style: ts(12, color: kMuted, height: 1.4),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// The reports I sent, with their status and the reply.
class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
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
      final d = await BusApi.get('/reports/mine');
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

  static const List<String> _mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _date(dynamic v) {
    final raw = (v ?? '').toString();
    final d = DateTime.tryParse(raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z');
    if (d == null) return '';
    final l = d.toLocal();
    return '${l.day} ${_mon[l.month - 1]} ${l.year}';
  }

  Widget _chip(String status) {
    Color bg = const Color(0xFFFFF1D6);
    Color fg = const Color(0xFF9A5B00);
    IconData ic = Icons.schedule_rounded;
    String text = app.tr('Received', 'பெறப்பட்டது');
    switch (status) {
      case 'Seen':
        ic = Icons.visibility_rounded;
        text = app.tr('Seen', 'பார்க்கப்பட்டது');
        break;
      case 'InProgress':
        bg = const Color(0xFFE8F0FE);
        fg = const Color(0xFF1A56C4);
        ic = Icons.build_rounded;
        text = app.tr('Working on it', 'சரிசெய்யப்படுகிறது');
        break;
      case 'Fixed':
        bg = const Color(0xFFE6F6EA);
        fg = const Color(0xFF1B7A3A);
        ic = Icons.check_circle_rounded;
        text = app.tr('Fixed', 'சரிசெய்யப்பட்டது');
        break;
      case 'Closed':
        bg = const Color(0xFFEFEFEF);
        fg = const Color(0xFF555555);
        ic = Icons.lock_rounded;
        text = app.tr('Closed', 'முடிந்தது');
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 14, color: fg),
        const SizedBox(width: 5),
        Text(text, style: ts(11.5, weight: FontWeight.w800, color: fg)),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> n) {
    final t = _typeOf((n['reportType'] ?? 'Other').toString());
    final ref = (n['refText'] ?? '').toString();
    final msg = (n['message'] ?? '').toString();
    final shot = (n['screenshotFile'] ?? '').toString();
    final reply = (n['adminReply'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: _soft),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: t.color.withAlpha(30), shape: BoxShape.circle),
            child: Icon(t.icon, color: t.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.tr(t.en, t.ta), style: ts(14, weight: FontWeight.w900)),
              Text(_date(n['createdAt']), style: ts(11.5, color: kMuted)),
            ]),
          ),
          _chip((n['status'] ?? 'New').toString()),
        ]),
        if (ref.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(ref, style: ts(13.5, weight: FontWeight.w800, color: kBrand, height: 1.3)),
          ),
        if (msg.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(msg, maxLines: 5, overflow: TextOverflow.ellipsis, style: ts(14.5, height: 1.4)),
          ),
        if (shot.isNotEmpty && repo.mediaUrl(shot) != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(imageUrl: repo.mediaUrl(shot)!, height: 96, width: 96, fit: BoxFit.cover),
            ),
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
      ]),
    );
  }

  Widget _empty() {
    return ListView(children: [
      const SizedBox(height: 90),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: kBrand.withAlpha(28), shape: BoxShape.circle),
          child: const Icon(Icons.flag_rounded, size: 46, color: kBrand),
        ),
      ),
      const SizedBox(height: 18),
      Center(child: Text(app.tr('No reports yet', 'புகார் எதுவும் இல்லை'), style: ts(18, weight: FontWeight.w900))),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(app.tr('If you find any problem in the app, tap the button below and tell us.', 'ஆப்பில் ஏதாவது சிக்கல் இருந்தால், கீழே உள்ள பட்டனை அழுத்தி சொல்லுங்கள்.'),
            textAlign: TextAlign.center, style: ts(13.5, color: kMuted, height: 1.4)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        title: Text(app.tr('My reports', 'என் புகார்கள்'), style: ts(19, weight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: () async {
          await openReportIssue(context);
          if (mounted) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(app.tr('New report', 'புதிய புகார்'), style: ts(14.5, weight: FontWeight.w800, color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 140), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(children: [const SizedBox(height: 120), Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)))])
                : _items.isEmpty
                    ? _empty()
                    : ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 90), children: [for (final n in _items) _card(n)]),
      ),
    );
  }
}
