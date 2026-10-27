import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'app_state.dart';
import 'auth/auth_guard.dart';
import 'bus/bus_api.dart';
import 'bus/bus_repo.dart';
import 'theme.dart';
import 'widgets.dart';

/// Opens the "add news" page. Guests are asked to register first.
Future<void> openAddNews(BuildContext context, {Map<String, dynamic>? existing}) async {
  final ok = await requireLogin(
    context,
    whyEn: 'To add news you must be registered, so we know who sent it. You can still read all news as a guest.',
    whyTa: 'செய்தியைச் சேர்க்க நீங்கள் பதிவு செய்திருக்க வேண்டும் - யார் அனுப்பினார்கள் என்பது தெரிய வேண்டும். விருந்தினராக செய்திகளைப் படிக்கலாம்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push<bool>(context, MaterialPageRoute<bool>(builder: (_) => AddNewsScreen(existing: existing)));
}

Future<void> openMyNews(BuildContext context) async {
  final ok = await requireLogin(
    context,
    whyEn: 'Please log in to see the news you sent.',
    whyTa: 'நீங்கள் அனுப்பிய செய்திகளைப் பார்க்க உள்நுழையுங்கள்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MyNewsScreen()));
}

/// Add a news item, or change one you sent earlier. It is only saved; it appears for everybody after approval.
class AddNewsScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const AddNewsScreen({super.key, this.existing});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final TextEditingController _ta = TextEditingController();
  final TextEditingController _en = TextEditingController();
  final TextEditingController _link = TextEditingController();
  String _image = '';
  XFile? _picked;
  bool _saving = false;

  int? get _id => widget.existing == null ? null : (widget.existing!['newsId'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _ta.text = (e['titleTa'] ?? '').toString();
      _en.text = (e['titleEn'] ?? '').toString();
      _link.text = (e['linkUrl'] ?? '').toString();
      _image = (e['imageFile'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _ta.dispose();
    _en.dispose();
    _link.dispose();
    super.dispose();
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _pick() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, maxHeight: 1000, imageQuality: 78);
      if (x != null) setState(() => _picked = x);
    } catch (_) {
      _msg(app.tr('Could not open the gallery.', 'கேலரியைத் திறக்க முடியவில்லை.'));
    }
  }

  Future<void> _save() async {
    if (_ta.text.trim().isEmpty && _en.text.trim().isEmpty) {
      _msg(app.tr('Please write the news title in Tamil or English.', 'செய்தித் தலைப்பை தமிழில் அல்லது ஆங்கிலத்தில் எழுதுங்கள்.'));
      return;
    }
    setState(() => _saving = true);
    try {
      var image = _image;
      if (_picked != null) {
        final bytes = await _picked!.readAsBytes();
        final r = await BusApi.postBytes('/news/image', bytes) as Map<String, dynamic>;
        image = (r['file'] ?? '').toString();
      }
      final body = {'titleTa': _ta.text.trim(), 'titleEn': _en.text.trim(), 'linkUrl': _link.text.trim(), 'imageFile': image};
      await BusApi.post(_id == null ? '/news/mine' : '/news/mine/$_id', body);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 36),
          title: Text(app.tr('News saved', 'செய்தி சேமிக்கப்பட்டது')),
          content: Text(app.tr('Thank you! Your news will appear for everyone after it is approved.',
              'நன்றி! ஒப்புதல் கிடைத்த பிறகு உங்கள் செய்தி அனைவருக்கும் தெரியும்.')),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('OK', 'சரி')))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _msg(e.toString());
      }
    }
  }

  Widget _photo() {
    Widget inner;
    if (_picked != null) {
      inner = FutureBuilder(
        future: _picked!.readAsBytes(),
        builder: (c, snap) => snap.hasData
            ? Image.memory(snap.data!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : const Center(child: CircularProgressIndicator()),
      );
    } else if (_image.isNotEmpty && repo.mediaUrl(_image) != null) {
      inner = CachedNetworkImage(imageUrl: repo.mediaUrl(_image)!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else {
      inner = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 34, color: kBrand),
          const SizedBox(height: 6),
          Text(app.tr('Add a photo (optional)', 'புகைப்படம் சேர்க்கவும் (விருப்பம்)'), style: ts(13.5, color: kMuted)),
        ],
      );
    }
    return InkWell(
      onTap: _saving ? null : _pick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 170,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF4E6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kLine),
        ),
        clipBehavior: Clip.antiAlias,
        child: inner,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF6EC),
        title: Text(_id == null ? app.tr('Add news', 'செய்தி சேர்க்க') : app.tr('Change news', 'செய்தியை மாற்று'),
            style: ts(19, weight: FontWeight.w900)),
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
                    app.tr('Your news is saved first. It is shown to everyone only after approval.',
                        'உங்கள் செய்தி முதலில் சேமிக்கப்படும். ஒப்புதலுக்குப் பிறகே அனைவருக்கும் தெரியும்.'),
                    style: ts(13, color: const Color(0xFF6B4400), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _photo(),
          const SizedBox(height: 16),
          TextField(
            controller: _ta,
            maxLines: 3,
            minLines: 2,
            maxLength: 400,
            decoration: InputDecoration(labelText: app.tr('Title in Tamil', 'தலைப்பு (தமிழ்)'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _en,
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
            decoration: InputDecoration(labelText: app.tr('Title in English', 'தலைப்பு (ஆங்கிலம்)'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _link,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
                labelText: app.tr('Link (optional)', 'இணைப்பு (விருப்பம்)'), hintText: 'https://...', border: const OutlineInputBorder()),
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

/// The news I sent, with the approval status of each.
class MyNewsScreen extends StatefulWidget {
  const MyNewsScreen({super.key});

  @override
  State<MyNewsScreen> createState() => _MyNewsScreenState();
}

class _MyNewsScreenState extends State<MyNewsScreen> {
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
      final d = await BusApi.get('/news/mine');
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
      backgroundColor: const Color(0xFFFFF6EC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF6EC),
        title: Text(app.tr('My news', 'நான் அனுப்பிய செய்திகள்'), style: ts(19, weight: FontWeight.w900)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: () async {
          await openAddNews(context);
          if (mounted) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(app.tr('Add news', 'செய்தி சேர்க்க')),
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
                        Center(child: Text(app.tr('You have not sent any news yet.', 'நீங்கள் இன்னும் செய்தி எதுவும் அனுப்பவில்லை.'), style: ts(15, color: kMuted))),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                        children: [
                          for (final n in _items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SoftCard(
                                onTap: () async {
                                  await openAddNews(context, existing: n);
                                  if (mounted) _load();
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app.lang == 'ta'
                                          ? ((n['titleTa'] ?? '').toString().isNotEmpty ? n['titleTa'].toString() : (n['titleEn'] ?? '').toString())
                                          : ((n['titleEn'] ?? '').toString().isNotEmpty ? n['titleEn'].toString() : (n['titleTa'] ?? '').toString()),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: ts(15, weight: FontWeight.w700, height: 1.3),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _chip((n['status'] ?? 'Pending').toString()),
                                        const Spacer(),
                                        const Icon(Icons.edit_outlined, size: 18, color: kMuted),
                                      ],
                                    ),
                                    if ((n['status'] ?? '') == 'Rejected' && (n['reviewNote'] ?? '').toString().isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(n['reviewNote'].toString(), style: ts(12.5, color: kMuted)),
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
