import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const Color kCream = Color(0xFFFFF6EC);

/// Bottom tabs: Home, Favorites, All services, Me.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _openUpdates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Expanded(child: UpdatesTab()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, repo, auth]),
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_tab != 0) {
              setState(() => _tab = 0);
              return;
            }
            final exit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(app.tr('Exit app?', 'வெளியேறவா?')),
                content: Text(app.tr('Are you sure you want to exit the app?', 'நீங்கள் ஆப்பிலிருந்து வெளியேற விரும்புகிறீர்களா?')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(app.tr('Cancel', 'இல்லை'))),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(app.tr('Exit', 'வெளியேறு'))),
                ],
              ),
            );
            if (exit == true) SystemNavigator.pop();
          },
          child: Scaffold(
          drawer: _AppDrawer(onTab: (i) => setState(() => _tab = i), onUpdates: _openUpdates),
          body: SafeArea(
            top: _tab != 0,
            bottom: false,
            child: IndexedStack(
              index: _tab,
              children: [
                HomeTab(onOpenUpdates: _openUpdates, onAllServices: () => setState(() => _tab = 2)),
                const FavoritesTab(),
                const AllServicesTab(),
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
                icon: const Icon(Icons.star_border),
                selectedIcon: const Icon(Icons.star, color: Colors.white),
                label: app.tr('Favorites', 'பிடித்தவை'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view),
                selectedIcon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                label: app.tr('All services', 'அனைத்து சேவைகள்'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                selectedIcon: const Icon(Icons.person, color: Colors.white),
                label: app.tr('Me', 'எனது'),
              ),
            ],
          ),
        ));
      },
    );
  }
}

void openTile(BuildContext context, TileInfo t) {
  if (t.key == 'news') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsListScreen()));
  } else if (t.live) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UnderConstructionScreen(tile: t)));
  }
}

/// The wavy lower edge of the orange header.
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..lineTo(0, h - 26)
      ..cubicTo(w * 0.28, h - 30, w * 0.34, h, w * 0.58, h)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class HomeTab extends StatelessWidget {
  final VoidCallback onOpenUpdates;
  final VoidCallback onAllServices;

  const HomeTab({super.key, required this.onOpenUpdates, required this.onAllServices});

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

  Widget _header(BuildContext context, double height, int noticeCount) {
    final top = MediaQuery.of(context).padding.top;
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        height: height,
        padding: EdgeInsets.only(top: top + 2, left: 6, right: 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFFFF7A1A), kBrand], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                ),
                const Expanded(child: Center(child: _HeaderLogo())),
                IconButton(
                  onPressed: onOpenUpdates,
                  icon: Badge(
                    isLabelVisible: noticeCount > 0,
                    label: Text('$noticeCount'),
                    child: const Icon(Icons.notifications, color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
            Text(
              app.tr('Our Aruppukottai', 'நம் அருப்புக்கோட்டை'),
              style: ts(15, weight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banners = _banners();
    final noticeCount = repo.activeNotices(DateTime.now()).length;
    final all = currentTiles();
    // Home shows the main six services (same order as the design); the rest are under "All services".
    const mainKeys = ['bus', 'news', 'food', 'shops', 'parcel', 'services'];
    final main = <TileInfo>[];
    for (final k in mainKeys) {
      for (final t in all) {
        if (t.key == k) main.add(t);
      }
    }
    final tiles = main.isEmpty ? all.take(6).toList() : main;
    final headerH = MediaQuery.of(context).padding.top + 112;
    const bannerH = 250.0;
    return Container(
      color: kCream,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(top: headerH - 34),
                child: banners.isEmpty
                    ? const _HeroBanner(height: bannerH)
                    : BannerCarousel(key: ValueKey(banners.map((e) => e.url).join(',')), items: banners, height: bannerH),
              ),
              Positioned(top: 0, left: 0, right: 0, child: _header(context, headerH, noticeCount)),
              Positioned(
                left: 14,
                right: 14,
                bottom: -28,
                child: _SearchBar(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceSearchScreen()))),
              ),
            ],
          ),
          const SizedBox(height: 44),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.9,
              children: [for (final t in tiles) _ServiceTile(tile: t, onTap: () => openTile(context, t))],
            ),
          ),
          const SizedBox(height: 16),
          _NewsSection(onMore: onAllServices),
        ],
      ),
    );
  }
}

class _BannerItem {
  final String url;
  final String caption;

  const _BannerItem(this.url, this.caption);
}

/// Used when no banner pictures are set on the server.
class _HeroBanner extends StatelessWidget {
  final double height;

  const _HeroBanner({this.height = 200});

  @override
  Widget build(BuildContext context) {
    return TempleBanner(
      height: height,
      radius: 0,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('அருப்புக்கோட்டை', maxLines: 1, style: ts(26, weight: FontWeight.w900, color: Colors.white)),
              Text('ARUPPUKOTTAI',
                  style: TextStyle(
                      fontSize: 13, letterSpacing: 3.5, fontWeight: FontWeight.w700, color: Colors.white.withAlpha(225))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width banner pictures from the server media folder (downloaded once, then remembered on the phone).
class BannerCarousel extends StatefulWidget {
  final List<_BannerItem> items;
  final double height;

  const BannerCarousel({super.key, required this.items, this.height = 250});

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
        _pc.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
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
    return SizedBox(
      height: widget.height,
      width: double.infinity,
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
              errorWidget: (c, u, e) => _HeroBanner(height: widget.height),
            ),
          ),
          // soft fade into the page colour, like the design
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFF6EC), kCream],
                ),
              ),
            ),
          ),
          if (cap.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 40,
              child: Text(
                cap,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ts(16, weight: FontWeight.w800, color: kNavy, height: 1.25),
              ),
            ),
        ],
      ),
    );
  }
}

/// The white search bar across the bottom edge of the banner.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Color(0x40FF8A1F), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.search, color: kNavy, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app.tr('What are you looking for?', 'எதை தேடுகிறீர்கள்?'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ts(16, color: kInk, weight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.mic, color: kNavy, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today's news" - read from news.json in the media folder (hidden when there is none).
class _NewsSection extends StatelessWidget {
  final VoidCallback onMore;

  const _NewsSection({required this.onMore});

  @override
  Widget build(BuildContext context) {
    final items = repo.news.take(5).toList();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: kRed, size: 30),
              const SizedBox(width: 8),
              Expanded(child: Text(app.tr("Today's news", 'இன்றைய செய்திகள்'), style: ts(19, weight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Row(
                  children: [
                    const Icon(Icons.newspaper, color: kMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(app.tr('News will appear here soon', 'செய்திகள் விரைவில் இங்கே வரும்'),
                          style: ts(14, color: kMuted, weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
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
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 110,
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
          if (item.link.isNotEmpty) const Icon(Icons.chevron_right, color: kNavy),
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
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: tile.color.withAlpha(70), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(tile.icon, color: tile.color, size: 30),
    );
    // Picture from the server media folder: tile_<key>.png (for example tile_bus.png). Without it, the icon above is shown.
    final url = repo.mediaUrl('tile_${tile.key}.png');
    if (url == null) return fallback;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (c, u) => Center(child: fallback),
      errorWidget: (c, u, e) => Center(child: fallback),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = app.lang == 'ta' ? tile.titleTa : tile.title;
    final secondary = app.lang == 'ta' ? tile.title : tile.titleTa;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color.alphaBlend(tile.color.withAlpha(40), Colors.white), Color.alphaBlend(tile.color.withAlpha(14), Colors.white)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Center(child: _icon())),
                const SizedBox(height: 4),
                Text(primary, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(13, weight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(secondary, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, color: kInk)),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: kNavy),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every service in one list (the third bottom tab).
class AllServicesTab extends StatelessWidget {
  const AllServicesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = currentTiles();
    return Container(
      color: kCream,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
        children: [
          Text(app.tr('All services', 'அனைத்து சேவைகள்'), style: ts(22, weight: FontWeight.w900)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.9,
            children: [for (final t in tiles) _ServiceTile(tile: t, onTap: () => openTile(context, t))],
          ),
        ],
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
  final VoidCallback onUpdates;

  const _AppDrawer({required this.onTab, required this.onUpdates});

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
                const SizedBox(height: 44, child: _HeaderLogo(alignLeft: true)),
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
          _pageTile(context, Icons.star_border, app.tr('Favorites', 'பிடித்தவை'), 1),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.notifications_none, color: kNavy),
            title: Text(app.tr('Updates', 'தகவல்கள்'), style: ts(15, weight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              onUpdates();
            },
          ),
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

/// "I ♥ APK" on one line, white, red heart (header of the home page).
class _HeaderLogo extends StatelessWidget {
  final bool alignLeft;

  const _HeaderLogo({this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0, letterSpacing: 1);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('I', style: style),
          SizedBox(width: 6),
          Icon(Icons.favorite, color: Color(0xFFE50914), size: 50),
          SizedBox(width: 6),
          Text('APK', style: style),
        ],
      ),
    );
  }
}

/// Search page: type to filter the services (Tamil or English).
class ServiceSearchScreen extends StatefulWidget {
  const ServiceSearchScreen({super.key});

  @override
  State<ServiceSearchScreen> createState() => _ServiceSearchScreenState();
}

class _ServiceSearchScreenState extends State<ServiceSearchScreen> {
  final TextEditingController _c = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool _match(TileInfo t) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = '${t.title} ${t.titleTa} ${t.tagline} ${t.taglineTa} ${t.key}'.toLowerCase();
    return hay.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final list = currentTiles().where(_match).toList();
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kCream,
        titleSpacing: 0,
        title: TextField(
          controller: _c,
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          style: ts(16),
          decoration: InputDecoration(
            hintText: app.tr('Search services', 'சேவைகளை தேடுங்கள்'),
            border: InputBorder.none,
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _c.clear();
                      setState(() => _q = '');
                    },
                  ),
          ),
        ),
      ),
      body: list.isEmpty
          ? Center(child: Text(app.tr('No service found', 'சேவை எதுவும் இல்லை'), style: ts(15, color: kMuted)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
              children: [
                for (final t in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftCard(
                      onTap: () => openTile(context, t),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(color: t.color.withAlpha(30), borderRadius: BorderRadius.circular(14)),
                            child: Icon(t.icon, color: t.color, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.lang == 'ta' ? t.titleTa : t.title, style: ts(15.5, weight: FontWeight.w800)),
                                Text(app.lang == 'ta' ? t.title : t.titleTa, style: ts(12.5, color: kMuted)),
                              ],
                            ),
                          ),
                          if (!t.live)
                            Text(app.tr('Soon', 'விரைவில்'), style: ts(11, weight: FontWeight.w800, color: const Color(0xFF8A5A00)))
                          else
                            const Icon(Icons.chevron_right, color: kNavy),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// All news (Tamil / English as the person chose), newest first.
class NewsListScreen extends StatefulWidget {
  const NewsListScreen({super.key});

  @override
  State<NewsListScreen> createState() => _NewsListScreenState();
}

class _NewsListScreenState extends State<NewsListScreen> {
  List<NewsItem> _items = repo.news;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await repo.fetchNews();
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = _items.isEmpty;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kCream,
        title: Text(app.tr('Local News', 'உள்ளூர் செய்திகள்'), style: ts(19, weight: FontWeight.w900)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text(
                            _failed
                                ? app.tr('Could not load news. Pull down to try again.', 'செய்திகளை ஏற்ற முடியவில்லை. கீழே இழுத்து மீண்டும் முயற்சிக்கவும்.')
                                : app.tr('No news yet', 'செய்திகள் இல்லை'),
                            textAlign: TextAlign.center,
                            style: ts(15, color: kMuted),
                          ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
                children: [
                  for (final n in _items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NewsCard(item: n),
                    ),
                ],
              ),
      ),
    );
  }
}
