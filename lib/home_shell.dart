import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'art.dart';
import 'auth/auth_service.dart';
import 'bus/bus_submit_screens.dart';
import 'bus/bus_home_screen.dart';
import 'bus/bus_models.dart';
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
          drawer: _AppDrawer(onTab: (i) => setState(() => _tab = i)),
          body: SafeArea(
            top: _tab != 0,
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: [
                HomeTab(onOpenUpdates: () => setState(() => _tab = 2), onOpenSettings: () => setState(() => _tab = 3)),
                const FavoritesTab(),
                const UpdatesTab(),
                const SettingsTab(),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            indicatorColor: kBrand,
            backgroundColor: Colors.white,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home, color: Colors.white),
                label: app.tr('Home', 'முகப்பு'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.favorite_border),
                selectedIcon: const Icon(Icons.favorite, color: Colors.white),
                label: app.tr('Favorites', 'பிடித்தவை'),
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: noticeCount > 0,
                  label: Text('$noticeCount'),
                  child: const Icon(Icons.notifications_none),
                ),
                selectedIcon: const Icon(Icons.notifications, color: Colors.white),
                label: app.tr('Updates', 'தகவல்கள்'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings, color: Colors.white),
                label: app.tr('Settings', 'அமைப்புகள்'),
              ),
            ],
          ),
        );
      },
    );
  }
}

void openTile(BuildContext context, TileInfo t) {
  if (t.live) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UnderConstructionScreen(tile: t)));
  }
}

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenUpdates;
  final VoidCallback onOpenSettings;

  const HomeTab({super.key, required this.onOpenUpdates, required this.onOpenSettings});

  /// Banner list from the server. Each entry: "File1.jpg" or "File1.jpg|English caption|தமிழ் caption".
  List<_BannerItem> _banners() {
    final out = <_BannerItem>[];
    for (final raw in (repo.settings['Home.Banners'] ?? '').split(',')) {
      final parts = raw.split('|').map((e) => e.trim()).toList();
      final file = parts.isEmpty ? '' : parts[0];
      final url = repo.mediaUrl(file);
      if (url == null) continue;
      final en = parts.length > 1 ? parts[1] : '';
      final ta = parts.length > 2 ? parts[2] : '';
      out.add(_BannerItem(url, app.tr(en, ta)));
    }
    return out;
  }

  void _open(BuildContext context, TileInfo t) => openTile(context, t);

  Widget _header(BuildContext context, int noticeCount) {
    final top = MediaQuery.of(context).padding.top;
    final tagline = app.tr(repo.settings['App.TaglineEn'] ?? '', repo.settings['App.TaglineTa'] ?? '');
    final name = auth.name;
    return Container(
      padding: EdgeInsets.fromLTRB(8, top + 6, 8, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFFF7A1A), kBrand], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
          ),
          Expanded(
            child: Column(
              children: [
                const BrandMark(size: 24, onDark: true),
                Text(
                  name.isNotEmpty
                      ? app.tr('Hello, $name', 'வணக்கம், $name')
                      : (tagline.isEmpty ? app.tr('Our Aruppukottai', 'நம் அருப்புக்கோட்டை') : tagline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(14, weight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpenUpdates,
            icon: Badge(
              isLabelVisible: noticeCount > 0,
              label: Text('$noticeCount'),
              child: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banners = _banners();
    final noticeCount = repo.activeNotices(DateTime.now()).length;
    final tiles = currentTiles();
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        _header(context, noticeCount),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              banners.isEmpty
                  ? const _HeroBanner()
                  : BannerCarousel(key: ValueKey(banners.map((e) => e.url).join(',')), items: banners),
              Positioned(
                left: 12,
                right: 12,
                bottom: -26,
                child: _SearchBar(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
            children: [for (final t in tiles) _ServiceTile(tile: t, onTap: () => _open(context, t))],
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 0), child: _NextBusCard()),
        const _NewsSection(),
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
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
              if (cap.isNotEmpty)
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
                top: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.items.length > 1)
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
              ),
              if (cap.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 34,
                  child: Text(
                    cap,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts(16, weight: FontWeight.w800, color: Colors.white, height: 1.25),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The white search bar that sits across the bottom edge of the banner.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 5,
      shadowColor: const Color(0x44000000),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search, color: kNavy, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.tr('Search buses: From - To', 'பேருந்து தேடுங்கள்: எங்கிருந்து - எங்கு'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(15.5, color: kMuted, weight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.directions_bus, color: kBrand, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today's news" - read from news.json in the media folder (hidden when there is none).
class _NewsSection extends StatelessWidget {
  const _NewsSection();

  @override
  Widget build(BuildContext context) {
    final items = repo.news.take(5).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: kRed, size: 26),
              const SizedBox(width: 8),
              Text(app.tr("Today's news", 'இன்றைய செய்திகள்'), style: ts(19, weight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NewsCard(item: n),
            ),
        ],
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final img = repo.mediaUrl(item.image);
    return SoftCard(
      padding: const EdgeInsets.all(8),
      onTap: item.link.isEmpty
          ? null
          : () => launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 104,
              height: 78,
              child: img == null
                  ? Container(color: kLine, child: const Icon(Icons.image_outlined, color: kMuted))
                  : CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.cover,
                      placeholder: (c, u) => Container(color: kLine),
                      errorWidget: (c, u, e) => Container(color: kLine, child: const Icon(Icons.image_outlined, color: kMuted)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name(app.lang),
                    maxLines: 3, overflow: TextOverflow.ellipsis, style: ts(14.5, weight: FontWeight.w700, height: 1.3)),
                if (item.date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(item.date, style: ts(12, color: kMuted)),
                ],
              ],
            ),
          ),
          if (item.link.isNotEmpty) const Icon(Icons.chevron_right, color: kMuted),
        ],
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
      padding: const EdgeInsets.only(top: 14, bottom: 14),
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

  Widget _icon() {
    final fallback = Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: tile.color.withAlpha(70), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(tile.icon, color: tile.color, size: 36),
    );
    // Picture from the server media folder: tile_<key>.png (for example tile_bus.png). Without it, the icon above is shown.
    final url = repo.mediaUrl('tile_${tile.key}.png');
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      width: 70,
      height: 70,
      fit: BoxFit.contain,
      placeholder: (c, u) => fallback,
      errorWidget: (c, u, e) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = app.lang == 'ta' ? tile.titleTa : tile.title;
    final secondary = app.lang == 'ta' ? tile.title : tile.titleTa;
    return Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(tile.color.withAlpha(24), Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tile.color.withAlpha(tile.live ? 110 : 40)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _icon(),
                    const SizedBox(height: 8),
                    Text(primary,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ts(13, weight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 2),
                    Text(secondary,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(11, color: kMuted)),
                  ],
                ),
              ),
              if (!tile.live)
                Positioned(
                  top: 5,
                  left: 0,
                  right: 0,
                  child: Center(
                      child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: kAmber.withAlpha(60), borderRadius: BorderRadius.circular(8)),
                    child: Text(app.tr('Soon', 'விரைவில்'), style: ts(9.5, weight: FontWeight.w800, color: const Color(0xFF8A5A00))),
                  )),
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

/// Side menu opened from the top-left button: all services, then the app pages.
class _AppDrawer extends StatelessWidget {
  final ValueChanged<int> onTab;

  const _AppDrawer({required this.onTab});

  @override
  Widget build(BuildContext context) {
    final tiles = currentTiles();
    final name = auth.name;
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 22, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF7A1A), kBrand], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(size: 34, onDark: true),
                const SizedBox(height: 10),
                Text(
                  name.isNotEmpty ? app.tr('Hello, $name', 'வணக்கம், $name') : app.tr('Welcome', 'வணக்கம்'),
                  style: ts(17, weight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(app.tr('Our Aruppukottai', 'நம் அருப்புக்கோட்டை'),
                    style: ts(13, color: Colors.white.withAlpha(225))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Text(app.tr('SERVICES', 'சேவைகள்'),
                style: TextStyle(fontSize: 12, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: kMuted)),
          ),
          for (final t in tiles)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: t.color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
                child: Icon(t.icon, color: t.color, size: 24),
              ),
              title: Text(app.lang == 'ta' ? t.titleTa : t.title, style: ts(15, weight: FontWeight.w700)),
              subtitle: Text(app.lang == 'ta' ? t.title : t.titleTa, style: ts(12, color: kMuted)),
              trailing: t.live
                  ? const Icon(Icons.chevron_right, color: kMuted)
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: kAmber.withAlpha(60), borderRadius: BorderRadius.circular(8)),
                      child: Text(app.tr('Soon', 'விரைவில்'),
                          style: ts(10.5, weight: FontWeight.w800, color: const Color(0xFF8A5A00))),
                    ),
              onTap: () {
                Navigator.pop(context);
                openTile(context, t);
              },
            ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Divider()),
          _pageTile(context, Icons.favorite_border, app.tr('Favorites', 'பிடித்தவை'), 1),
          _pageTile(context, Icons.notifications_none, app.tr('Updates', 'தகவல்கள்'), 2),
          _pageTile(context, Icons.settings_outlined, app.tr('Settings', 'அமைப்புகள்'), 3),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _pageTile(BuildContext context, IconData icon, String label, int tab) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: kNavy),
      title: Text(label, style: ts(15, weight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        onTab(tab);
      },
    );
  }
}
