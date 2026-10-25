import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'art.dart';
import 'auth/auth_service.dart';
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

  List<String> _bannerUrls() {
    var base = repo.settings['Media.BaseUrl'] ?? '';
    final names = (repo.settings['Home.Banners'] ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (base.isNotEmpty && !base.endsWith('/')) base = '$base/';
    final out = <String>[];
    for (final n in names) {
      if (n.startsWith('http')) {
        out.add(n);
      } else if (base.isNotEmpty) {
        out.add('$base$n');
      }
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

  @override
  Widget build(BuildContext context) {
    final urls = _bannerUrls();
    final noticeCount = repo.activeNotices(DateTime.now()).length;
    final name = auth.name;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandMark(size: 30),
                  Text(
                    name.isEmpty
                        ? 'I Love Aruppukottai'
                        : app.tr('Hello, $name', 'வணக்கம், $name'),
                    style: ts(14, weight: FontWeight.w600, color: kMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onOpenUpdates,
              icon: Badge(
                isLabelVisible: noticeCount > 0,
                label: Text('$noticeCount'),
                child: const Icon(Icons.notifications_none, size: 28),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        urls.isEmpty ? const _HeroBanner() : BannerCarousel(key: ValueKey(urls.join(',')), urls: urls),
        const _NextBusCard(),
        SectionTitle(app.tr('Services', 'சேவைகள்')),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.18,
          children: [for (final t in kTiles) _TileCard(tile: t, onTap: () => _open(context, t))],
        ),
      ],
    );
  }
}

/// Used when no banner pictures are set on the server: a clean gradient, no image files needed.
class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return TempleBanner(
      height: 170,
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
          const SizedBox(height: 10),
          Text(app.tr('Our town, our people, our app', 'நம் ஊர் • நம் மக்கள் • நம் ஆப்'),
              style: ts(13, color: Colors.white.withAlpha(235), height: 1.3)),
        ],
      ),
    );
  }
}

/// Banner pictures come from the server (small download, remembered on the phone), so the APK itself stays small.
class BannerCarousel extends StatefulWidget {
  final List<String> urls;

  const BannerCarousel({super.key, required this.urls});

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
    if (widget.urls.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_pc.hasClients) return;
        final next = (_i + 1) % widget.urls.length;
        _pc.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 160,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pc,
              itemCount: widget.urls.length,
              onPageChanged: (v) => setState(() => _i = v),
              itemBuilder: (context, index) => CachedNetworkImage(
                imageUrl: widget.urls[index],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (c, u) => Container(color: kLine),
                errorWidget: (c, u, e) => const _HeroBanner(),
              ),
            ),
            if (widget.urls.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var k = 0; k < widget.urls.length; k++)
                      Container(
                        width: k == _i ? 18 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: k == _i ? Colors.white : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
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

class _TileCard extends StatelessWidget {
  final TileInfo tile;
  final VoidCallback onTap;

  const _TileCard({required this.tile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = app.lang == 'ta' ? tile.titleTa : tile.title;
    final secondary = app.lang == 'ta' ? tile.title : tile.titleTa;
    return Opacity(
      opacity: tile.live ? 1 : 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kLine),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -14,
                  bottom: -14,
                  child: Icon(tile.icon, size: 84, color: tile.color.withAlpha(18)),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [tile.color.withAlpha(230), tile.color],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: tile.color.withAlpha(70), blurRadius: 8, offset: const Offset(0, 4))],
                            ),
                            child: Icon(tile.icon, color: Colors.white, size: 26),
                          ),
                          const Spacer(),
                          if (tile.live) Pill(app.tr('Open', 'திற'), color: kGreen, filled: true),
                        ],
                      ),
                      const Spacer(),
                      Text(primary, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, color: kMuted)),
                    ],
                  ),
                ),
              ],
            ),
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
          message: app.tr('We are building this section for Aruppukottai. Bus Timings is ready to use.',
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
