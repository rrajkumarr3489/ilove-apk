import 'package:flutter/material.dart';

import 'app_state.dart';
import 'approvals.dart';
import 'auth/auth_guard.dart';
import 'bus/bus_api.dart';
import 'push_service.dart';
import 'reports_admin.dart';
import 'theme.dart';

const Color _cream = Color(0xFFFFF6EC);

/// Number of notifications the person has not opened yet (red number on the bell).
class Inbox extends ChangeNotifier {
  int unread = 0;

  bool get _loggedIn {
    final t = app.token;
    return t != null && t.isNotEmpty;
  }

  Future<void> refresh() async {
    if (!_loggedIn) {
      if (unread != 0) {
        unread = 0;
        notifyListeners();
      }
      return;
    }
    try {
      final d = await BusApi.get('/notifications/unread');
      final n = d is Map ? (d['unread'] as num?)?.toInt() ?? 0 : 0;
      if (n != unread) {
        unread = n;
        notifyListeners();
      }
    } catch (_) {}
  }

  void setUnread(int n) {
    if (n < 0) n = 0;
    if (n != unread) {
      unread = n;
      notifyListeners();
    }
  }
}

final Inbox inbox = Inbox();

Future<void> openNotifications(BuildContext context) async {
  final ok = await requireLogin(
    context,
    whyEn: 'Please log in to see your notifications.',
    whyTa: 'உங்கள் அறிவிப்புகளைப் பார்க்க உள்நுழையுங்கள்.',
  );
  if (!ok || !context.mounted) return;
  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()));
  inbox.refresh();
}

class _Look {
  final IconData icon;
  final Color color;
  const _Look(this.icon, this.color);
}

_Look _lookOf(String kind) {
  switch (kind) {
    case 'approved_news':
    case 'approved_jobs':
      return const _Look(Icons.check_circle_rounded, Color(0xFF2E7D32));
    case 'rejected_news':
    case 'rejected_jobs':
      return const _Look(Icons.cancel_rounded, Color(0xFFE53935));
    case 'news':
      return const _Look(Icons.newspaper_rounded, Color(0xFFE8590C));
    case 'jobs':
      return const _Look(Icons.work_rounded, Color(0xFF1565C0));
    case 'report_update':
      return const _Look(Icons.support_agent_rounded, Color(0xFF1A56C4));
    case 'report':
      return const _Look(Icons.flag_rounded, Color(0xFF6A1B9A));
    default:
      return const _Look(Icons.notifications_rounded, Color(0xFF6B6B76));
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  int _pendingNews = -1;
  int _pendingJobs = -1;
  int _newReports = 0;

  bool get _isApprover => _pendingNews >= 0;

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
      final d = await BusApi.get('/notifications');
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
      inbox.setUnread(list.where((e) => e['isRead'] != true).length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
    // Approvers also see how many items are waiting (other people get an error here, which is fine).
    try {
      final p = await BusApi.get('/approvals/pending');
      if (p is Map && mounted) {
        setState(() {
          _pendingNews = (p['news'] is List) ? (p['news'] as List).length : 0;
          _pendingJobs = (p['jobs'] is List) ? (p['jobs'] as List).length : 0;
        });
      }
    } catch (_) {
      if (mounted && _pendingNews != -1) setState(() => _pendingNews = _pendingJobs = -1);
    }
    if (_isApprover) {
      try {
        final r = await BusApi.get('/approvals/reports');
        if (r is List && mounted) setState(() => _newReports = r.where((e) => e is Map && e['status'] == 'New').length);
      } catch (_) {}
    }
  }

  Future<void> _readAll() async {
    try {
      await BusApi.post('/notifications/read-all', {});
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['isRead'] = true;
        }
      });
      inbox.setUnread(0);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _open(Map<String, dynamic> n) async {
    final id = (n['notificationId'] as num?)?.toInt();
    if (n['isRead'] != true && id != null) {
      setState(() => n['isRead'] = true);
      inbox.setUnread(_items.where((e) => e['isRead'] != true).length);
      try {
        await BusApi.post('/notifications/$id/read', {});
      } catch (_) {}
    }
    PushService.openKind((n['kind'] ?? '').toString(), (n['url'] ?? '').toString());
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
    return '${l.day} ${_mon[l.month - 1]}';
  }

  Widget _approvalsBanner() {
    final total = _pendingNews + _pendingJobs;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ApprovalsScreen(initialTab: _pendingNews == 0 && _pendingJobs > 0 ? 1 : 0)),
      ).then((_) => _load()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF7A1A), kBrand]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: kBrand.withAlpha(70), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: Colors.white.withAlpha(60), shape: BoxShape.circle),
            child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.tr('Approvals', 'அங்கீகாரங்கள்'), style: ts(16, weight: FontWeight.w900, color: Colors.white)),
              Text(
                total == 0
                    ? app.tr('Nothing is waiting', 'எதுவும் காத்திருக்கவில்லை')
                    : app.tr('$_pendingNews news · $_pendingJobs jobs waiting', '$_pendingNews செய்தி · $_pendingJobs வேலை காத்திருக்கிறது'),
                style: ts(12.5, color: Colors.white.withAlpha(235)),
              ),
            ]),
          ),
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Text('$total', style: ts(14, weight: FontWeight.w900, color: kBrand)),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: Colors.white),
        ]),
      ),
    );
  }

  Widget _reportsBanner() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ReportsAdminScreen())).then((_) => _load()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6A1B9A).withAlpha(80)),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFF6A1B9A).withAlpha(28), shape: BoxShape.circle),
            child: const Icon(Icons.flag_rounded, color: Color(0xFF6A1B9A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(app.tr('Reports', 'புகார்கள்'), style: ts(16, weight: FontWeight.w900)),
              Text(
                _newReports == 0 ? app.tr('No new reports', 'புதிய புகார் இல்லை') : app.tr('$_newReports new', '$_newReports புதியவை'),
                style: ts(12.5, color: kMuted),
              ),
            ]),
          ),
          if (_newReports > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF6A1B9A), borderRadius: BorderRadius.circular(14)),
              child: Text('$_newReports', style: ts(14, weight: FontWeight.w900, color: Colors.white)),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: kMuted),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> n) {
    final look = _lookOf((n['kind'] ?? '').toString());
    final unread = n['isRead'] != true;
    final body = (n['body'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: unread ? Colors.white : Colors.white.withAlpha(190),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: unread ? kBrand.withAlpha(120) : kLine),
        boxShadow: unread ? [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: look.color.withAlpha(30), shape: BoxShape.circle),
              child: Icon(look.icon, color: look.color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text((n['title'] ?? '').toString(), style: ts(14.5, weight: unread ? FontWeight.w900 : FontWeight.w700, height: 1.25)),
                if (body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: ts(13.5, color: kMuted, height: 1.35)),
                  ),
                const SizedBox(height: 6),
                Text(_when(n['createdAt']), style: ts(11.5, color: kMuted)),
              ]),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(top: 4, left: 6),
                width: 11,
                height: 11,
                decoration: const BoxDecoration(color: kBrand, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(children: [
      if (_isApprover) Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 0), child: Column(children: [_approvalsBanner(), _reportsBanner()])),
      const SizedBox(height: 70),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(color: kBrand.withAlpha(28), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_none_rounded, size: 48, color: kBrand),
        ),
      ),
      const SizedBox(height: 18),
      Center(child: Text(app.tr('No notifications yet', 'அறிவிப்புகள் எதுவும் இல்லை'), style: ts(18, weight: FontWeight.w900))),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(app.tr('New alerts will be kept here for 30 days.', 'புதிய அறிவிப்புகள் இங்கே 30 நாட்கள் இருக்கும்.'),
            textAlign: TextAlign.center, style: ts(13.5, color: kMuted, height: 1.4)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _items.any((e) => e['isRead'] != true);
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _cream,
        surfaceTintColor: _cream,
        title: Text(app.tr('Notifications', 'அறிவிப்புகள்'), style: ts(19, weight: FontWeight.w900)),
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: _readAll,
              icon: const Icon(Icons.done_all_rounded, size: 19, color: kBrand),
              label: Text(app.tr('Mark all read', 'அனைத்தும் படிக்கப்பட்டது'), style: ts(12.5, weight: FontWeight.w800, color: kBrand)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? ListView(children: const [SizedBox(height: 140), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(children: [const SizedBox(height: 120), Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(_error!, textAlign: TextAlign.center)))])
                : _items.isEmpty
                    ? _empty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                        children: [if (_isApprover) ...[_approvalsBanner(), _reportsBanner()], for (final n in _items) _card(n)],
                      ),
      ),
    );
  }
}
