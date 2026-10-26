import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'art.dart';
import 'auth/auth_service.dart';
import 'bus/bus_submit_screens.dart';
import 'bus/bus_home_screen.dart';
import 'bus/bus_repo.dart';
import 'bus/bus_widgets.dart';
import 'bus/departures_screen.dart';
import 'bus/notices_screen.dart';
import 'tabs.dart';
import 'theme.dart';
import 'tiles.dart';
import 'widgets.dart';

/// Bottom tabs: Home, Favorites, Updates, Settings.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, repo, auth]),
      builder: (context, _) {
        final noticeCount = repo.activeNotices(DateTime.now()).length;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: [
                HomeTab(onOpenUpdates: () => setState(() => _tab = 2)),
                const FavoritesTab(),
                const UpdatesTab(),
                const SettingsTab(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: app.tr('Home', 'முகப்பு'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.favorite_border),
                selectedIcon: const Icon(Icons.favorite),
                label: app.tr('Favorites', 'பிடித்தவை'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: noticeCount > 0,
                  label: Text('$noticeCount'),
                  child: const Icon(Icons.notifications_none),
                ),
                selectedIcon: const Icon(Icons.notifications),
                label: app.tr('Updates', 'தகவல்கள்'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: app.tr('Settings', 'அமைப்புகள்'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenUpdates;

  const HomeTab({super.key, required this.onOpenUpdates});

  /// Banner list from the server. Each entry: "File1.jpg" or "File1.jpg|English caption|தமிழ் caption".
  List<_BannerItem> _banners() {
    var base = repo.settings['Media.BaseUrl'] ?? '';
    if (base.isNotEmpty && !base.endsWith('/')) base = '$base/';
    final out = <_BannerItem>[];
    for (final raw in (repo.settings['Home.Banners'] ?? '').split(',')) {
      final parts = raw.split('|').map((e) => e.trim()).toList();
      final file = parts.isEmpty ? '' : parts[0];
      if (file.isEmpty) continue;
      String url;
      if (file.startsWith('http')) {
        url = file;
      } else if (base.isNotEmpty) {
        url = '$base$file';
      } else {
        continue;
      }
      final en = parts.length > 1 ? parts[1] : '';
      final ta = parts.length > 2 ? parts[2] : '';
      out.add(_BannerItem(url, app.tr(en, ta)));
    }
    return out;
  }

  void _open(BuildContext context, TileInfo t) {
    if (t.live) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => UnderConstructionScreen(tile: t)));
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return app.tr('Good morning', 'காலை வணக்கம்');
    if (h < 17) return app.tr('Good afternoon', 'மதிய வணக்கம்');
    return app.tr('Good evening', 'மாலை வணக்கம்');
  }

  @override
  Widget build(BuildContext context) {
    final banners = _banners();
    final noticeCount = repo.activeNotices(DateTime.now()).length;
    final name = auth.name;
    final tagline = app.tr(repo.settings['App.TaglineEn'] ?? '', repo.settings['App.TaglineTa'] ?? '');
    final tiles = currentTiles();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Row(
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? _greeting() : '${_greeting()}, $name',
                    style: ts(15, weight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    tagline.isEmpty ? app.tr('Our town, in your pocket', 'நம்ம ஊர், உங்கள் கையில்') : tagline,
                    style: ts(12, color: kMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              onPressed: onOpenUpdates,
              icon: Badge(
                isLabelVisible: noticeCount > 0,
                label: Text('$noticeCount'),
                child: const Icon(Icons.notifications_none),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        banners.isEmpty
            ? const _HeroBanner()
            : BannerCarousel(key: ValueKey(banners.map((e) => e.url).join(',')), items: banners),
        const SizedBox(height: 14),
        _WhereToCard(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()))),
        const SizedBox(height: 14),
        const _QuickActions(),
        const _NextBusCard(),
        SectionTitle(app.tr('Explore Aruppukottai', 'அருப்புக்கோட்டையை அறிவோம்')),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.92,
          children: [for (final t in tiles) _ServiceTile(tile: t, onTap: () => _open(context, t))],
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            app.tr('Made with love for Aruppukottai', 'அருப்புக்கோட்டைக்காக அன்புடன்'),
            style: ts(12, color: kMuted),
          ),
        ),
      ],
    );
  }
}

class _BannerItem {
  final String url;
  final String caption;

  const _BannerItem(this.url, this.caption);
}

/// Used when no banner pictures are set on the server: a clean illustration, no image files needed.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return TempleBanner(
      height: 190,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('அருப்புக்கோட்டை', maxLines: 1, style: ts(26, weight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Text('ARUPPUKOTTAI',
              style: TextStyle(
                  fontSize: 13, letterSpacing: 3.5, fontWeight: FontWeight.w700, color: Colors.white.withAlpha(225))),
        ],
      ),
    );
  }
}

/// Banner pictures come from the server (small download, remembered on the phone), so the APK itself stays small.
class BannerCarousel extends StatefulWidget {
  final List<_BannerItem> items;

  const BannerCarousel({super.key, required this.items});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final PageController _pc = PageController();
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    if (widget.items.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_pc.hasClients) return;
        final next = (_i + 1) % widget.items.length;
        _pc.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cap = widget.items[_i].caption;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pc,
                itemCount: widget.items.length,
                onPageChanged: (v) => setState(() => _i = v),
                itemBuilder: (context, index) => CachedNetworkImage(
                  imageUrl: widget.items[index].url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (c, u) => Container(color: kLine),
                  errorWidget: (c, u, e) => const _HeroBanner(),
                ),
              ),
              // dark fade at the bottom so the text and dots stay readable on any picture
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xB3000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        cap,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(15, weight: FontWeight.w800, color: Colors.white, height: 1.25),
                      ),
                    ),
                    if (widget.items.length > 1)
                      Row(
                        children: [
                          for (var k = 0; k < widget.items.length; k++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: k == _i ? 18 : 7,
                              height: 7,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                color: k == _i ? Colors.white : Colors.white54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Where do you want to go?" - the main thing most people come for.
class _WhereToCard extends StatelessWidget {
  final VoidCallback onTap;

  const _WhereToCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kNavy, kBlue], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.tr('Where do you want to go?', 'எங்கே செல்ல வேண்டும்?'),
                          style: ts(16.5, weight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(app.tr('Search buses From - To', 'எங்கிருந்து - எங்கு பேருந்து தேடுங்கள்'),
                          style: ts(12.5, color: Colors.white70)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  Widget _item(BuildContext context, IconData icon, Color color, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: color.withAlpha(28), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, maxLines: 2, style: ts(12, weight: FontWeight.w700, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _item(context, Icons.alt_route, kBrand, app.tr('Bus search', 'பேருந்து தேடல்'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()))),
        _item(context, Icons.departure_board, kBlue, app.tr('Bus stand board', 'நிலைய பலகை'), () {
          final home = repo.placeByName('Aruppukottai');
          if (home == null) {
            showMsg(context, app.tr('Timetable is not downloaded yet.', 'நேரங்கள் இன்னும் பதிவிறக்கப்படவில்லை.'));
            return;
          }
          Navigator.push(context, MaterialPageRoute(builder: (_) => DeparturesScreen(placeId: home.id)));
        }),
        _item(context, Icons.campaign_outlined, kRed, app.tr('Notices', 'அறிவிப்புகள்'),
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoticesScreen()))),
        _item(context, Icons.add_road, kGreen, app.tr('Add bus', 'பேருந்து சேர்'), () => openAddBus(context)),
      ],
    );
  }
}

class _NextBusCard extends StatelessWidget {
  const _NextBusCard();

  @override
  Widget build(BuildContext context) {
    if (!repo.hasData) return const SizedBox.shrink();
    final home = repo.placeByName('Aruppukottai');
    if (home == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final list = repo.departures(placeId: home.id, date: now, afterMin: now.hour * 60 + now.minute);
    final shown = list.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: kBrand, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(app.tr('Next buses from Aruppukottai', 'அருப்புக்கோட்டையிலிருந்து அடுத்த பேருந்துகள்'),
                      style: ts(14.5, weight: FontWeight.w800)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DeparturesScreen(placeId: home.id)),
                  ),
                  child: Text(app.tr('See all', 'அனைத்தும்')),
                ),
              ],
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Text(app.tr('No more buses today. Tap "See all" to check tomorrow.',
                    'இன்று மேலும் பேருந்து இல்லை. நாளைய நேரங்களுக்கு "அனைத்தும்" தொடவும்.'),
                    style: ts(13, color: kMuted)),
              ),
            for (final b in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 82,
                      child: Text(fmtClock(b.departsMin), style: ts(14, weight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(repo.placeName(b.toPlaceId),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14)),
                    ),
                    const SizedBox(width: 6),
                    if (b.route.typeId != null)
                      Pill(typeName(b.route.typeId), color: typeColor(b.route.typeId)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final TileInfo tile;
  final VoidCallback onTap;

  const _ServiceTile({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = app.lang == 'ta' ? tile.titleTa : tile.title;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tile.live ? tile.color.withAlpha(120) : kLine),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [tile.color.withAlpha(215), tile.color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: tile.color.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Icon(tile.icon, color: Colors.white, size: 27),
                    ),
                    const SizedBox(height: 8),
                    Text(primary,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(12.5, weight: FontWeight.w800, height: 1.2)),
                  ],
                ),
              ),
              if (!tile.live)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: kAmber.withAlpha(40), borderRadius: BorderRadius.circular(8)),
                    child: Text(app.tr('Soon', 'விரைவில்'), style: ts(9.5, weight: FontWeight.w800, color: const Color(0xFF8A5A00))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for every tile that is not built yet.
class UnderConstructionScreen extends StatelessWidget {
  final TileInfo tile;

  const UnderConstructionScreen({super.key, required this.tile});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(app.lang == 'ta' ? tile.titleTa : tile.title)),
        body: EmptyState(
          icon: Icons.construction,
          title: app.tr('Under construction', 'கட்டுமானத்தில் உள்ளது'),
          message: (app.lang == 'ta' ? tile.taglineTa : tile.tagline).isNotEmpty
              ? (app.lang == 'ta' ? tile.taglineTa : tile.tagline)
              : app.tr('We are building this section for Aruppukottai. Bus Timings is ready to use.',
              'இந்தப் பகுதி அருப்புக்கோட்டைக்காக உருவாக்கப்படுகிறது. பேருந்து நேரங்கள் இப்போது பயன்படுத்தலாம்.'),
          action: FilledButton.icon(
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const BusHomeScreen())),
            icon: const Icon(Icons.directions_bus),
            label: Text(app.tr('Open Bus Timings', 'பேருந்து நேரங்களைத் திற')),
          ),
        ),
      ),
    );
  }
}
