import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth/auth_guard.dart';
import 'auth/auth_service.dart';
import 'bus/bus_api.dart';
import 'bus/bus_models.dart';
import 'bus/bus_repo.dart';
import 'bus/bus_results_screen.dart';
import 'bus/bus_submit_screens.dart';
import 'bus/bus_widgets.dart';
import 'bus/notices_screen.dart';
import 'bus/route_detail_screen.dart';
import 'config.dart';
import 'theme.dart';
import 'widgets.dart';

Widget _pageTitle(String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Expanded(child: Text(text, style: ts(24, weight: FontWeight.w900))),
          if (trailing != null) trailing,
        ],
      ),
    );

// ---------------------------------------------------------------- favorites

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final routes = [for (final id in repo.favRoutes) if (repo.routes[id] != null) repo.routes[id]!];
        final searches = repo.favSearches;
        final trips = [for (final id in repo.favTrips) if (repo.tripById(id) != null && repo.routes[repo.tripById(id)!.routeId] != null) repo.tripById(id)!];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageTitle(app.tr('Favorites', 'பிடித்தவை')),
            Expanded(
              child: (routes.isEmpty && searches.isEmpty && trips.isEmpty)
                  ? EmptyState(
                      icon: Icons.favorite_border,
                      title: app.tr('Nothing saved yet', 'இன்னும் எதுவும் சேமிக்கவில்லை'),
                      message: app.tr('Tap the heart on a bus or a search to keep it here.',
                          'பேருந்து அல்லது தேடலில் இதய குறியைத் தட்டினால் இங்கே இருக்கும்.'),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        if (searches.isNotEmpty) SectionTitle(app.tr('Saved searches', 'சேமித்த தேடல்கள்')),
                        for (final s in searches)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => BusResultsScreen(
                                      fromId: s.fromId, toId: s.toId, viaId: s.viaId, date: DateTime.now()),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.search, color: kBrand),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${repo.placeName(s.fromId)} → ${repo.placeName(s.toId)}',
                                      style: ts(15.5, weight: FontWeight.w700),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.favorite, color: kRed),
                                    onPressed: () => repo.toggleFavSearch(s),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (trips.isNotEmpty) SectionTitle(app.tr('Saved timings', 'சேமித்த நேரங்கள்')),
                        for (final t in trips)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => RouteDetailScreen(routeId: t.routeId, date: DateTime.now())),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_filled, color: kBrand),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(routeTitle(repo.routes[t.routeId]!), style: ts(15.5, weight: FontWeight.w700)),
                                        Text(app.tr('Departs ', 'புறப்பாடு ') + fmtClock(t.departMin), style: ts(12.5, color: kMuted)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.favorite, color: kRed),
                                    onPressed: () => repo.toggleFavTrip(t.id),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (routes.isNotEmpty) SectionTitle(app.tr('Saved buses', 'சேமித்த பேருந்துகள்')),
                        for (final r in routes)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => RouteDetailScreen(routeId: r.id, date: DateTime.now())),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_bus, color: kBlue),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(routeTitle(r), style: ts(15.5, weight: FontWeight.w700)),
                                        Text('${typeName(r.typeId)} ${r.routeNo}'.trim(), style: ts(12.5, color: kMuted)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.favorite, color: kRed),
                                    onPressed: () => repo.toggleFavRoute(r.id),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- updates

class UpdatesTab extends StatelessWidget {
  const UpdatesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pageTitle(
              app.tr('Updates', 'அறிவிப்புகள்'),
              trailing: IconButton(
                tooltip: app.tr('Refresh', 'புதுப்பி'),
                icon: repo.syncing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                    : const Icon(Icons.refresh),
                onPressed: repo.syncing ? null : () => repo.sync(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(
                app.tr('Bus timings updated: ${agoText(repo.lastSync)}', 'பேருந்து நேரங்கள் புதுப்பிக்கப்பட்டது: ${agoText(repo.lastSync)}'),
                style: ts(12.5, color: kMuted),
              ),
            ),
            const Expanded(child: NoticeList()),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- settings

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  Widget _row(IconData icon, String title, {String? sub, VoidCallback? onTap, Color? color, Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: color ?? kBlue),
      title: Text(title, style: ts(15.5, weight: FontWeight.w700, color: color ?? kInk)),
      subtitle: sub == null ? null : Text(sub, style: ts(12.5, color: kMuted)),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right, color: kMuted)),
      onTap: onTap,
    );
  }

  Widget _group(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: children),
        ),
      );

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
    repo.sync(full: true);
  }

  Future<void> _editProfile() async {
    final r = await showFieldsDialog(
      context,
      title: app.tr('Edit profile', 'சுயவிவரத்தை மாற்று'),
      fields: [
        FieldSpec(app.tr('Name', 'பெயர்'), initial: auth.name),
        FieldSpec(app.tr('E-mail (optional)', 'மின்னஞ்சல் (விருப்பம்)'), initial: auth.email, keyboard: TextInputType.emailAddress),
      ],
      okLabel: app.tr('Save', 'சேமி'),
    );
    if (r == null) return;
    if (r[0].length < 2) {
      if (mounted) showMsg(context, app.tr('Enter your name.', 'உங்கள் பெயரை உள்ளிடவும்.'));
      return;
    }
    try {
      await auth.updateProfile(r[0], r[1]);
      if (mounted) showMsg(context, app.tr('Saved.', 'சேமிக்கப்பட்டது.'));
    } catch (e) {
      if (mounted) showMsg(context, BusApi.friendly(e));
    }
  }

  Future<void> _changePassword() async {
    final r = await showFieldsDialog(
      context,
      title: app.tr('Change password', 'கடவுச்சொல்லை மாற்று'),
      fields: [
        FieldSpec(app.tr('Current password', 'தற்போதைய கடவுச்சொல்'), obscure: true),
        FieldSpec(app.tr('New password (6+ characters)', 'புதிய கடவுச்சொல் (6+ எழுத்துகள்)'), obscure: true),
      ],
      okLabel: app.tr('Change', 'மாற்று'),
    );
    if (r == null) return;
    if (r[1].length < 6) {
      if (mounted) showMsg(context, app.tr('New password must be at least 6 characters.', 'புதிய கடவுச்சொல் குறைந்தது 6 எழுத்துகள் இருக்க வேண்டும்.'));
      return;
    }
    try {
      await auth.changePassword(r[0], r[1]);
      if (mounted) showMsg(context, app.tr('Password changed.', 'கடவுச்சொல் மாற்றப்பட்டது.'));
    } catch (e) {
      if (mounted) showMsg(context, BusApi.friendly(e));
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, app.tr('Logout?', 'வெளியேறவா?'),
        app.tr('You can still view bus timings as a guest.', 'விருந்தினராக பேருந்து நேரங்களைத் தொடர்ந்து பார்க்கலாம்.'),
        okLabel: app.tr('Logout', 'வெளியேறு'));
    if (ok) await auth.logout();
  }

  Future<void> _deleteAccount() async {
    final r = await showFieldsDialog(
      context,
      title: app.tr('Delete my account', 'என் கணக்கை நீக்கு'),
      note: app.tr('This cannot be undone. Enter your password to confirm.',
          'இதை மீட்க முடியாது. உறுதிசெய்ய கடவுச்சொல்லை உள்ளிடவும்.'),
      fields: [FieldSpec(app.tr('Password', 'கடவுச்சொல்'), obscure: true)],
      okLabel: app.tr('Delete', 'நீக்கு'),
    );
    if (r == null) return;
    try {
      await auth.deleteAccount(r[0]);
      if (mounted) showMsg(context, app.tr('Your account was deleted.', 'உங்கள் கணக்கு நீக்கப்பட்டது.'));
    } catch (e) {
      if (mounted) showMsg(context, BusApi.friendly(e));
    }
  }

  Future<void> _redownload() async {
    final ok = await confirmDialog(
        context,
        app.tr('Download again?', 'மீண்டும் பதிவிறக்கவா?'),
        app.tr('The bus timetable is fetched fresh from the server and replaces the copy saved on this phone.',
            'பேருந்து நேரங்கள் சர்வரிலிருந்து புதிதாக எடுக்கப்பட்டு, இந்த போனில் சேமித்த நகலை மாற்றும்.'));
    if (!ok) return;
    final done = await repo.sync(full: true);
    if (mounted) showMsg(context, done ? app.tr('Timetable updated.', 'நேரங்கள் புதுப்பிக்கப்பட்டன.') : (repo.lastError ?? ''));
  }

  Widget _account() {
    if (!auth.loggedIn) {
      return SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 22, backgroundColor: kLine, child: Icon(Icons.person_outline, color: kMuted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.tr('Guest', 'விருந்தினர்'), style: ts(17, weight: FontWeight.w800)),
                      Text(app.tr('You can view all bus timings.', 'அனைத்து பேருந்து நேரங்களையும் பார்க்கலாம்.'),
                          style: ts(12.5, color: kMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              app.tr('Register to add new buses and timings.', 'புதிய பேருந்து, நேரங்களைச் சேர்க்க பதிவு செய்யுங்கள்.'),
              style: ts(13.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: () => requireLogin(context,
                  whyEn: 'Register (or login) to add new buses and timings, and to follow your entries.',
                  whyTa: 'புதிய பேருந்து, நேரங்களைச் சேர்க்கவும், உங்கள் பதிவுகளைப் பார்க்கவும் பதிவு செய்யுங்கள் அல்லது உள்நுழையுங்கள்.'),
              style: FilledButton.styleFrom(backgroundColor: kBrand),
              child: Text(app.tr('Register / Login', 'பதிவு / உள்நுழை')),
            ),
          ],
        ),
      );
    }
    return SoftCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: kBrand,
            child: Text(
              auth.name.isEmpty ? '?' : auth.name.characters.first.toUpperCase(),
              style: ts(20, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(auth.name, style: ts(17, weight: FontWeight.w800)),
                Text('+91 ${auth.mobile}', style: ts(13, color: kMuted)),
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
      listenable: Listenable.merge([app, auth, repo]),
      builder: (context, _) {
        final disc = app.tr(repo.settings['Bus.DisclaimerEn'] ?? '', repo.settings['Bus.DisclaimerTa'] ?? '');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          children: [
            _pageTitle(app.tr('Settings', 'அமைப்புகள்')),
            _account(),
            const SizedBox(height: 14),
            if (auth.loggedIn)
              _group([
                _row(Icons.add_road, app.tr('Add a new bus', 'புதிய பேருந்தைச் சேர்'), onTap: () => openAddBus(context)),
                _row(Icons.history_edu_outlined, app.tr('My entries', 'என் பதிவுகள்'), onTap: () => openMyEntries(context)),
                _row(Icons.edit_outlined, app.tr('Edit profile', 'சுயவிவரத்தை மாற்று'), onTap: _editProfile),
                _row(Icons.lock_reset, app.tr('Change password', 'கடவுச்சொல்லை மாற்று'), onTap: _changePassword),
              ])
            else
              _group([
                _row(Icons.add_road, app.tr('Add a new bus', 'புதிய பேருந்தைச் சேர்'),
                    sub: app.tr('Registration needed', 'பதிவு தேவை'), onTap: () => openAddBus(context)),
              ]),
            _group([
              ListTile(
                leading: const Icon(Icons.translate, color: kBlue),
                title: Text(app.tr('Language', 'மொழி'), style: ts(15.5, weight: FontWeight.w700)),
                trailing: const LangToggle(),
              ),
              _row(Icons.sync, app.tr('Bus timetable', 'பேருந்து நேரங்கள்'),
                  sub: repo.syncing
                      ? app.tr('Updating...', 'புதுப்பிக்கிறது...')
                      : app.tr('Updated ${agoText(repo.lastSync)}', 'புதுப்பிக்கப்பட்டது: ${agoText(repo.lastSync)}'),
                  onTap: repo.syncing ? null : () => repo.sync(),
                  trailing: repo.syncing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                      : const Icon(Icons.refresh, color: kMuted)),
              _row(Icons.cloud_download_outlined, app.tr('Download timetable again', 'நேரங்களை மீண்டும் பதிவிறக்கு'),
                  onTap: repo.syncing ? null : _redownload),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                app.tr(
                    'Timings always come from our server. This phone only keeps the last copy it downloaded, so you can still see timings when there is no internet.',
                    'நேரங்கள் எப்போதும் எங்கள் சர்வரிலிருந்தே வருகின்றன. இணையம் இல்லாதபோதும் பார்க்க, கடைசியாக பதிவிறக்கிய நகலை மட்டும் இந்த போன் வைத்திருக்கும்.'),
                style: ts(12, color: kMuted, height: 1.4),
              ),
            ),
            _group([
              _row(Icons.campaign_outlined, app.tr('Notices', 'அறிவிப்புகள்'),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const NoticesScreen()))),
              _row(Icons.info_outline, app.tr('About', 'பற்றி'),
                  sub: 'I Love Aruppukottai  v$kAppVersion',
                  onTap: () => showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('I Love Aruppukottai'),
                          content: Text(
                            disc.isEmpty ? app.tr('Our town, our people, our app.', 'நம் ஊர், நம் மக்கள், நம் ஆப்.') : disc,
                            style: ts(14, height: 1.4),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(app.tr('OK', 'சரி')))],
                        ),
                      )),
            ]),
            if (auth.loggedIn)
              _group([
                _row(Icons.logout, app.tr('Logout', 'வெளியேறு'), onTap: _logout),
                _row(Icons.delete_outline, app.tr('Delete my account', 'என் கணக்கை நீக்கு'), color: kRed, onTap: _deleteAccount),
              ]),
          ],
        );
      },
    );
  }
}
