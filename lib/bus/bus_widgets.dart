import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import 'bus_models.dart';
import 'bus_repo.dart';

Color hexColor(String? hex, [Color fallback = kBlue]) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return fallback;
  final v = int.tryParse(hex.substring(1), radix: 16);
  if (v == null) return fallback;
  return Color(0xFF000000 | v);
}

/// 375 -> "06:15 AM"
String fmtClock(int minutes) {
  final m = minutes % 1440;
  final h = m ~/ 60;
  final mm = m % 60;
  final ap = h >= 12 ? 'PM' : 'AM';
  var h12 = h % 12;
  if (h12 == 0) h12 = 12;
  return '${h12.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')} $ap';
}

/// 90 -> "1 h 30 m" / "1 மணி 30 நிமி"
String fmtDur(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final hs = app.tr('h', 'மணி');
  final ms = app.tr('m', 'நிமி');
  if (h == 0) return '$m $ms';
  if (m == 0) return '$h $hs';
  return '$h $hs $m $ms';
}

String fmtFare(double? fare) {
  if (fare == null) return '';
  final r = fare.roundToDouble();
  return r == fare ? '₹${fare.toInt()}' : '₹${fare.toStringAsFixed(2)}';
}

const List<String> _wdEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _wdTa = ['திங்', 'செவ்', 'புத', 'வியா', 'வெள்', 'சனி', 'ஞாயி'];
const List<String> _moEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const List<String> _moTa = [
  'ஜன', 'பிப்', 'மார்', 'ஏப்', 'மே', 'ஜூன்', 'ஜூலை', 'ஆக', 'செப்', 'அக்', 'நவ', 'டிச'
];

/// "Fri, 23 Oct"
String fmtDate(DateTime d) {
  final wd = app.lang == 'ta' ? _wdTa[d.weekday - 1] : _wdEn[d.weekday - 1];
  final mo = app.lang == 'ta' ? _moTa[d.month - 1] : _moEn[d.month - 1];
  return '$wd, ${d.day} $mo';
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String viaText(List<int> ids, {int max = 4}) {
  if (ids.isEmpty) return '';
  final names = ids.map((e) => repo.placeName(e)).where((e) => e.isNotEmpty).toList();
  if (names.length <= max) return names.join(', ');
  return '${names.take(max).join(', ')} +${names.length - max}';
}

String typeName(int? id) {
  if (id == null) return '';
  final t = repo.types[id];
  return t == null ? '' : t.name(app.lang);
}

Color typeColor(int? id) {
  final t = id == null ? null : repo.types[id];
  return hexColor(t?.colorHex, kBlue);
}

IconData placeIcon(String type) {
  switch (type) {
    case 'Town':
      return Icons.location_city;
    case 'Village':
      return Icons.holiday_village;
    case 'BusStand':
    case 'BusStop':
      return Icons.directions_bus;
    case 'RailwayStation':
      return Icons.train;
    default:
      return Icons.place;
  }
}

String placeTypeLabel(String type) {
  switch (type) {
    case 'Town':
      return app.tr('Town', 'நகரம்');
    case 'Village':
      return app.tr('Village', 'கிராமம்');
    case 'BusStand':
      return app.tr('Bus stand', 'பேருந்து நிலையம்');
    case 'BusStop':
      return app.tr('Bus stop', 'பேருந்து நிறுத்தம்');
    case 'RailwayStation':
      return app.tr('Railway station', 'ரயில் நிலையம்');
    default:
      return app.tr('Place', 'இடம்');
  }
}

/// Small coloured label (bus type, route number, platform...).
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  const Pill(this.text, {super.key, this.color = kBlue, this.icon, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text, style: ts(11.5, weight: FontWeight.w700, color: fg)),
        ],
      ),
    );
  }
}

/// On time / Delayed / Cancelled / Diverted / Info badge for a bus.
class StatusBadge extends StatelessWidget {
  final String status;
  final int? delay;

  const StatusBadge(this.status, {super.key, this.delay});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'Cancelled':
        return Pill(app.tr('Cancelled', 'ரத்து'), color: kRed, icon: Icons.block, filled: true);
      case 'Delayed':
        final d = delay == null ? '' : ' +${delay}m';
        return Pill('${app.tr('Delayed', 'தாமதம்')}$d',
            color: const Color(0xFFB26A00), icon: Icons.schedule);
      case 'Diverted':
        return Pill(app.tr('Diverted', 'பாதை மாற்றம்'),
            color: const Color(0xFF6A1B9A), icon: Icons.alt_route);
      case 'Info':
        return Pill(app.tr('Notice', 'அறிவிப்பு'), color: kBlue, icon: Icons.info_outline);
      default:
        return const SizedBox.shrink();
    }
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: kBrand.withAlpha(24),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: kBrand),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: ts(17, weight: FontWeight.w800)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: ts(14, color: kMuted, height: 1.4)),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: ts(16, weight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A notice strip (cancelled / delayed / diverted / info).
class NoticeTile extends StatelessWidget {
  final Notice notice;
  final String? routeLabel;
  final VoidCallback? onTap;

  const NoticeTile(this.notice, {super.key, this.routeLabel, this.onTap});

  @override
  Widget build(BuildContext context) {
    Color c;
    IconData icon;
    switch (notice.kind) {
      case 'Cancelled':
        c = kRed;
        icon = Icons.block;
        break;
      case 'Delayed':
        c = const Color(0xFFB26A00);
        icon = Icons.schedule;
        break;
      case 'Diverted':
        c = const Color(0xFF6A1B9A);
        icon = Icons.alt_route;
        break;
      default:
        c = kBlue;
        icon = Icons.info_outline;
    }
    final msg = notice.msg(app.lang);
    final title = notice.kind == 'Delayed' && notice.delay != null
        ? '${app.tr('Delayed', 'தாமதம்')} +${notice.delay} ${app.tr('min', 'நிமி')}'
        : _kindLabel(notice.kind);
    return SoftCard(
      onTap: onTap,
      color: c.withAlpha(16),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(14, weight: FontWeight.w800, color: c)),
                if (routeLabel != null && routeLabel!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(routeLabel!, style: ts(13, weight: FontWeight.w600)),
                  ),
                if (msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(msg, style: ts(13, color: kMuted, height: 1.35)),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    notice.from == notice.to ? notice.from : '${notice.from} → ${notice.to}',
                    style: ts(12, color: kMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _kindLabel(String kind) {
    switch (kind) {
      case 'Cancelled':
        return app.tr('Cancelled', 'ரத்து செய்யப்பட்டது');
      case 'Delayed':
        return app.tr('Delayed', 'தாமதம்');
      case 'Diverted':
        return app.tr('Diverted', 'பாதை மாற்றம்');
      default:
        return app.tr('Notice', 'அறிவிப்பு');
    }
  }
}

/// "Aruppukottai → Madurai" for a route, in the chosen language.
String routeTitle(BusRoute r) =>
    '${repo.placeName(r.fromId)} → ${repo.placeName(r.toId)}';

/// "5 min ago" style text for the last sync time.
String agoText(DateTime? t) {
  if (t == null) return app.tr('never', 'இதுவரை இல்லை');
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return app.tr('just now', 'இப்போது');
  if (d.inMinutes < 60) {
    return app.tr('${d.inMinutes} min ago', '${d.inMinutes} நிமிடம் முன்');
  }
  if (d.inHours < 24) {
    return app.tr('${d.inHours} h ago', '${d.inHours} மணி முன்');
  }
  return app.tr('${d.inDays} days ago', '${d.inDays} நாள் முன்');
}

void showMsg(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Rebuilds a screen when the language or the bus data changes.
Listenable get busListen => Listenable.merge([app, repo]);
