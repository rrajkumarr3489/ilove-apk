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

const Color _cream = Color(0xFFFFF6EC);

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
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 36),
          title: Text(app.tr('Report sent', 'புகார் அனுப்பப்பட்டது')),
          content: Text(app.tr('Thank you! We will look into it and tell you here.', 'நன்றி! நாங்கள் பார்த்து இங்கே தெரிவிப்போம்.')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('OK', 'சரி')))],
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

  Widget _typeChip(String key, String en, String ta, IconData icon) {
    final on = _type == key;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: on ? Colors.white : kBrand),
      label: Text(app.tr(en, ta)),
      selected: on,
      showCheckmark: false,
      selectedColor: kBrand,
      labelStyle: ts(13.5, weight: FontWeight.w700, color: on ? Colors.white : null),
      onSelected: _saving ? null : (_) => setState(() => _type = key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRef = (widget.refText ?? '').isNotEmpty;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: Text(app.tr('Report an issue', 'சிக்கலைத் தெரிவி'), style: ts(19, weight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (hasRef)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.directions_bus, color: Color(0xFF1A56C4), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.refText!, style: ts(13.5, weight: FontWeight.w700, color: const Color(0xFF123F91)))),
              ]),
            ),
          Text(app.tr('What is it about?', 'எதைப் பற்றி?'), style: ts(14, weight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _typeChip('Bug', 'App problem', 'ஆப் சிக்கல்', Icons.bug_report_outlined),
            _typeChip('WrongInfo', 'Wrong information', 'தவறான தகவல்', Icons.error_outline),
            _typeChip('Suggestion', 'Suggestion', 'ஆலோசனை', Icons.lightbulb_outline),
            _typeChip('Other', 'Other', 'மற்றவை', Icons.chat_bubble_outline),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _msg,
            maxLines: 5,
            minLines: 3,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: app.tr('Tell us what happened', 'என்ன நடந்தது என்று எழுதுங்கள்'),
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _saving ? null : _pick,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(color: const Color(0xFFFFF4E6), borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
              clipBehavior: Clip.antiAlias,
              child: _picked != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.file(File(_picked!.path), fit: BoxFit.cover),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          onPressed: () => setState(() => _picked = null),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ),
                    ])
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 34, color: kBrand),
                      const SizedBox(height: 6),
                      Text(app.tr('Add a screenshot (optional)', 'ஸ்கிரீன்ஷாட் சேர்க்கவும் (விருப்பம்)'), style: ts(13.5, color: kMuted)),
                    ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            app.tr('Your phone model, Android version and app version are sent with the report to help us fix it.',
                'சரிசெய்ய உதவ, உங்கள் போன் மாடல், ஆண்ட்ராய்டு மற்றும் ஆப் பதிப்பு புகாருடன் அனுப்பப்படும்.'),
            style: ts(12, color: kMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: kBrand, padding: const EdgeInsets.symmetric(vertical: 15)),
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Text(app.tr('Send', 'அனுப்பு'), style: ts(16, weight: FontWeight.w800, color: Colors.white)),
          ),
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

  Widget _chip(String status) {
    Color bg = const Color(0xFFFFF1D6);
    Color fg = const Color(0xFF9A5B00);
    String text = app.tr('Received', 'பெறப்பட்டது');
    switch (status) {
      case 'Seen':
        text = app.tr('Seen', 'பார்க்கப்பட்டது');
        break;
      case 'InProgress':
        bg = const Color(0xFFE8F0FE);
        fg = const Color(0xFF1A56C4);
        text = app.tr('Working on it', 'சரிசெய்யப்படுகிறது');
        break;
      case 'Fixed':
        bg = const Color(0xFFE6F6EA);
        fg = const Color(0xFF1B7A3A);
        text = app.tr('Fixed', 'சரிசெய்யப்பட்டது');
        break;
      case 'Closed':
        bg = const Color(0xFFEFEFEF);
        fg = const Color(0xFF555555);
        text = app.tr('Closed', 'முடிந்தது');
        break;
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
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        title: Text(app.tr('My reports', 'என் புகார்கள்'), style: ts(19, weight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: () async {
          await openReportIssue(context);
          if (mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(app.tr('New report', 'புதிய புகார்')),
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
                        Center(child: Text(app.tr('You have not sent any report yet.', 'நீங்கள் இன்னும் புகார் எதுவும் அனுப்பவில்லை.'), style: ts(15, color: kMuted))),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                        children: [
                          for (final n in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: kLine)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((n['refText'] ?? '').toString().isNotEmpty)
                                      Text(n['refText'].toString(), style: ts(13.5, weight: FontWeight.w800, color: kBrand)),
                                    if ((n['message'] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text(n['message'].toString(), maxLines: 4, overflow: TextOverflow.ellipsis, style: ts(14.5, height: 1.3)),
                                      ),
                                    if ((n['screenshotFile'] ?? '').toString().isNotEmpty && repo.mediaUrl(n['screenshotFile'].toString()) != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: CachedNetworkImage(imageUrl: repo.mediaUrl(n['screenshotFile'].toString())!, height: 90, width: 90, fit: BoxFit.cover),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    _chip((n['status'] ?? 'New').toString()),
                                    if ((n['adminReply'] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(app.tr('Reply: ', 'பதில்: ') + n['adminReply'].toString(), style: ts(13, color: kMuted, height: 1.35)),
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
