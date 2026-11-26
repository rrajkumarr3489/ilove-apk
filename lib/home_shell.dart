import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'art.dart';
import 'auth/auth_service.dart';
import 'bus/bus_home_screen.dart';
import 'bus/bus_models.dart';
import 'bus/bus_repo.dart';
import 'bus/bus_widgets.dart';
import 'bus/departures_screen.dart';
import 'classifieds.dart';
import 'food/food_home_screen.dart';
import 'home_scene.dart';
import 'inbox.dart';
import 'news_submit.dart';
import 'report_issue.dart';
import 'screen_header.dart';
import 'share_util.dart';
import 'tabs.dart';
import 'theme.dart';
import 'tiles.dart';

const Color kCream = kBg;

/// Bottom tabs: Home, Favorites, All services, Me.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    auth.addListener(inbox.refresh);
    inbox.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    auth.removeListener(inbox.refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) inbox.refresh();
  }

  void _openUpdates() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: ScreenAppBar(
            kind: HeaderKind.services,
            title: app.tr('Updates', 'அறிவிப்புகள்'),
            subtitle: app.tr('Latest bus timing changes', 'பேருந்து நேர மாற்றங்கள்'),
          ),
          body: const UpdatesTab(),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, IconData selIcon, String label) {
    final on = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(color: on ? kTint : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Icon(on ? selIcon : icon, size: 24, color: on ? kBrandDark : kMuted),
            ),
            const SizedBox(height: 2),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? kInk : kMuted)),
          ],
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
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
            child: IndexedStack(
              index: _tab,
              children: [
                HomeTab(onOpenUpdates: _openUpdates, onAllServices: () => setState(() => _tab = 2)),
                SafeArea(top: false, bottom: false, child: FavoritesTab()),
                SafeArea(top: false, bottom: false, child: AllServicesTab()),
                SafeArea(top: false, bottom: false, child: SettingsTab()),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: kLine))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 66,
                child: Row(
                  children: [
                    _navItem(0, Icons.home_outlined, Icons.home_rounded, app.tr('Home', 'முகப்பு')),
                    _navItem(1, Icons.star_border_rounded, Icons.star_rounded, app.tr('Favorites', 'பிடித்தவை')),
                    _navItem(2, Icons.grid_view_outlined, Icons.grid_view_rounded, app.tr('Services', 'சேவைகள்')),
                    _navItem(3, Icons.person_outline_rounded, Icons.person_rounded, app.tr('Me', 'எனது')),
                  ],
                ),
              ),
            ),
          ),
        ));
      },
    );
  }
}

/// One order everywhere (home, side menu, all services): the order of the design.
const List<String> kTileOrder = ['bus', 'news', 'food', 'shops', 'parcel', 'services', 'train', 'classifieds', 'report', 'ai'];

List<TileInfo> orderedTiles() {
  final list = List<TileInfo>.of(currentTiles());
  int rank(TileInfo t) {
    final i = kTileOrder.indexOf(t.key);
    return i < 0 ? 100 : i;
  }
  list.sort((a, b) => rank(a).compareTo(rank(b)));
  return list;
}

void openTile(BuildContext context, TileInfo t) {
  if (t.key == 'news') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NewsListScreen()));
  } else if (t.key == 'classifieds') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ClassifiedsScreen()));
  } else if (t.key == 'report') {
    openReportIssue(context);
  } else if (t.key == 'food') {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodHomeScreen()));
  } else if (t.live) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BusHomeScreen()));
  } else {
    Navigator.push(context, MaterialPageRoute(builder: (_) => UnderConstructionScreen(tile: t)));
  }
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

  Widget _roundButton(Widget child) => Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: kTintSoft),
        child: child,
      );

  Widget _topBar(BuildContext context, int noticeCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: _roundButton(const Icon(Icons.menu_rounded, color: kInk, size: 22)),
            ),
          ),
          Image.asset('assets/logo.png', height: 44, fit: BoxFit.contain),
          Align(
            alignment: Alignment.centerRight,
            child: ListenableBuilder(
              listenable: inbox,
              builder: (context, _) {
                final loggedIn = (app.token ?? '').isNotEmpty;
                final count = loggedIn ? inbox.unread : noticeCount;
                return GestureDetector(
                  onTap: loggedIn ? () => openNotifications(context) : onOpenUpdates,
                  child: _roundButton(Badge(
                    isLabelVisible: count > 0,
                    label: Text('$count'),
                    child: const Icon(Icons.notifications_none_rounded, color: kInk, size: 24),
                  )),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconGrid(BuildContext context, List<TileInfo> list) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.count(
        padding: EdgeInsets.zero,
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 0,
        childAspectRatio: 0.82,
        children: [for (final t in list) _ServiceTile(tile: t, onTap: () => openTile(context, t))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banners = _banners();
    final noticeCount = repo.activeNotices(DateTime.now()).length;
    final all = orderedTiles();
    // Home shows 8 services as 4 + 4; "Report an issue" and "AI Assistant" live in All services only.
    final home = all.where((t) => t.key != 'report' && t.key != 'ai').take(8).toList();
    final top = MediaQuery.of(context).padding.top;
    const bannerH = 200.0;
    return Container(
      color: kBg,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(top: top + 6, bottom: 8),
            child: _topBar(context, noticeCount),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: bannerH,
              child: banners.isEmpty
                  ? ClipRRect(borderRadius: BorderRadius.circular(18), child: const CustomPaint(painter: HomeScenePainter(), size: Size.infinite))
                  : BannerCarousel(key: ValueKey(banners.map((e) => e.url).join(',')), items: banners, height: bannerH, radius: 18),
            ),
          ),
          const SizedBox(height: 14),
          _iconGrid(context, home),
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

  const _HeroBanner({this.height = 150});

  @override
  Widget build(BuildContext context) {
    return TempleBanner(
      height: height,
      radius: 20,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('அருப்புக்கோட்டை', maxLines: 1, style: ts(24, weight: FontWeight.w900, color: Colors.white)),
            Text('ARUPPUKOTTAI', style: TextStyle(fontSize: 12, letterSpacing: 3.5, fontWeight: FontWeight.w700, color: Colors.white.withAlpha(225))),
          ],
        ),
      ),
    );
  }
}

/// Rounded banner pictures from the server media folder (downloaded once, then remembered on the phone).
class BannerCarousel extends StatefulWidget {
  final List<_BannerItem> items;
  final double height;
  final double radius;

  const BannerCarousel({super.key, required this.items, this.height = 150, this.radius = 20});

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
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
                placeholder: (c, u) => Container(color: kTintSoft),
                errorWidget: (c, u, e) => _HeroBanner(height: widget.height),
              ),
            ),
            if (cap.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 26, 16, 14),
                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xAA000000)])),
                    child: Text(cap, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(15, weight: FontWeight.w700, color: Colors.white, height: 1.25)),
                  ),
                ),
              ),
            if (widget.items.length > 1)
              Positioned(
                right: 12,
                bottom: 10,
                child: Row(
                  children: [
                    for (var k = 0; k < widget.items.length; k++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(left: 4),
                        width: k == _i ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(color: k == _i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3)),
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

/// Grey rounded search bar.
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kTintSoft,
      elevation: 3,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: kMuted, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  app.tr('Search services, hotels, news', 'சேவைகள், உணவகங்கள், செய்திகள்'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(15, color: kMuted),
                ),
              ),
              const Icon(Icons.mic_none_rounded, color: kMuted, size: 24),
            ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                Expanded(child: Text(app.tr("Today's news", 'இன்றைய செய்திகள்'), style: ts(16, weight: FontWeight.w700))),
                GestureDetector(onTap: onMore, child: Text(app.tr('See all', 'அனைத்தும்'), style: ts(13, weight: FontWeight.w600, color: kBrand))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                child: Row(
                  children: [
                    const Icon(Icons.newspaper_rounded, color: kMuted),
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
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kLine)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
      onTap: item.link.isEmpty
          ? null
          : () => launchUrl(Uri.parse(item.link), mode: LaunchMode.externalApplication),
      child: Padding(
      padding: const EdgeInsets.all(8),
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
          IconButton(
            tooltip: app.tr('Share', 'பகிர்'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.share_rounded, size: 20, color: kNavy),
            onPressed: () => showShareSheet(context, text: newsShareText(item.name(app.lang), item.link), link: item.link),
          ),
        ],
      ),
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
      padding: const EdgeInsets.only(top: 14, bottom: 14),
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus_rounded, color: kBrand, size: 20),
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
      width: 60,
      height: 60,
      decoration: const BoxDecoration(color: kTintSoft, shape: BoxShape.circle),
      child: Icon(tile.icon, color: tile.color, size: 28),
    );
    // Picture from the server media folder: tile_<key>.png (for example tile_bus.png). Without it, the icon above is shown.
    final url = repo.mediaUrl('tile_${tile.key}.png');
    if (url == null) return fallback;
    return SizedBox(
      width: 60,
      height: 60,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        placeholder: (c, u) => fallback,
        errorWidget: (c, u, e) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = app.lang == 'ta' ? tile.titleTa : tile.title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          children: [
            _icon(),
            const SizedBox(height: 7),
            Text(primary, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: ts(12, weight: FontWeight.w500, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

/// All services (third bottom tab): clean list. Live services first as wide cards, the rest as a compact grid.
class AllServicesTab extends StatelessWidget {
  const AllServicesTab({super.key});

  Widget _sectionTitle(String text, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          Expanded(child: Text(text, style: ts(16, weight: FontWeight.w700, color: kInk))),
          if (trailing != null) Text(trailing, style: ts(12, color: kMuted, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app, repo]),
      builder: (context, _) {
        final tiles = orderedTiles();
        final live = tiles.where((t) => t.live).toList();
        final soon = tiles.where((t) => !t.live).toList();
        return Container(
          color: Colors.white,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              ScreenHeader(
                kind: HeaderKind.services,
                showBack: false,
                title: app.tr('All services', 'அனைத்து சேவைகள்'),
                subtitle: app.tr('Everything in Aruppukottai, one place', 'அருப்புக்கோட்டை முழுவதும் ஒரே இடத்தில்'),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SearchBar(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceSearchScreen()))),
              ),
              if (live.isNotEmpty) ...[
                _sectionTitle(app.tr('Available now', 'இப்போது கிடைப்பவை')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 142),
                    itemCount: live.length,
                    itemBuilder: (c, i) => _ServiceCard(tile: live[i], onTap: () => openTile(context, live[i])),
                  ),
                ),
              ],
              if (soon.isNotEmpty) ...[
                _sectionTitle(app.tr('Coming soon', 'விரைவில் வருகிறது'), trailing: '${soon.length}'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 142),
                    itemCount: soon.length,
                    itemBuilder: (c, i) => _ServiceCard(tile: soon[i], soon: true, onTap: () => openTile(context, soon[i])),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

String _tileTag(TileInfo tile) {
  final primary = app.lang == 'ta' ? tile.taglineTa : tile.tagline;
  final other = app.lang == 'ta' ? tile.tagline : tile.taglineTa;
  return primary.isNotEmpty ? primary : other;
}

/// Tinted service card for the All services page: icon circle, name, one line, big faint icon behind.
class _ServiceCard extends StatelessWidget {
  final TileInfo tile;
  final VoidCallback onTap;
  final bool soon;

  const _ServiceCard({required this.tile, required this.onTap, this.soon = false});

  @override
  Widget build(BuildContext context) {
    final title = app.lang == 'ta' ? tile.titleTa : tile.title;
    final tag = _tileTag(tile);
    final color = soon ? kMuted : tile.color;
    final url = repo.mediaUrl('tile_${tile.key}.png');
    final glyph = Icon(tile.icon, color: color, size: 26);
    return Material(
      color: Color.alphaBlend(color.withAlpha(soon ? 18 : 28), Colors.white),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              right: -16,
              bottom: -22,
              child: Transform.rotate(angle: -0.2, child: Icon(tile.icon, size: 100, color: color.withAlpha(34))),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        padding: EdgeInsets.all(url == null ? 0 : 8),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: url == null
                            ? glyph
                            : CachedNetworkImage(imageUrl: url, fit: BoxFit.contain, placeholder: (c, u) => glyph, errorWidget: (c, u, e) => glyph),
                      ),
                      const Spacer(),
                      if (soon)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                          child: Text(app.tr('Soon', 'விரைவில்'), style: ts(11, weight: FontWeight.w600, color: kMuted)),
                        )
                      else
                        const Icon(Icons.arrow_forward_rounded, size: 20, color: kInk),
                    ],
                  ),
                  const Spacer(),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, weight: FontWeight.w700, color: kInk)),
                  const SizedBox(height: 2),
                  Text(tag, maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(12, color: kMuted, height: 1.25)),
                ],
              ),
            ),
          ],
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
        appBar: ScreenAppBar(kind: HeaderKind.services, title: app.lang == 'ta' ? tile.titleTa : tile.title),
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
            icon: const Icon(Icons.directions_bus_rounded),
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
    final tiles = orderedTiles();
    final name = auth.name;
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 22, 20, 20),
            color: kBrand,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/logo_white.png', height: 62, alignment: Alignment.centerLeft, fit: BoxFit.contain),
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
                decoration: const BoxDecoration(color: kTintSoft, shape: BoxShape.circle),
                child: Icon(t.icon, color: t.color, size: 22),
              ),
              title: Text(app.lang == 'ta' ? t.titleTa : t.title, style: ts(15, weight: FontWeight.w700)),
              subtitle: Text(app.lang == 'ta' ? t.title : t.titleTa, style: ts(12, color: kMuted)),
              trailing: t.live
                  ? const Icon(Icons.chevron_right_rounded, color: kMuted)
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
          _pageTile(context, Icons.star_border_rounded, app.tr('Favorites', 'பிடித்தவை'), 1),
          ListenableBuilder(
            listenable: inbox,
            builder: (context, _) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Badge(
                isLabelVisible: inbox.unread > 0,
                label: Text('${inbox.unread}'),
                child: const Icon(Icons.notifications_active_rounded, color: kNavy),
              ),
              title: Text(app.tr('Notifications', 'அறிவிப்புகள்'), style: ts(15, weight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                openNotifications(context);
              },
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            leading: const Icon(Icons.notifications_none_rounded, color: kNavy),
            title: Text(app.tr('Updates', 'தகவல்கள்'), style: ts(15, weight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              onUpdates();
            },
          ),
          _pageTile(context, Icons.settings_rounded, app.tr('Settings', 'அமைப்புகள்'), 3),
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
    final list = orderedTiles().where(_match).toList();
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
                    icon: const Icon(Icons.close_rounded),
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
                            const Icon(Icons.chevron_right_rounded, color: kNavy),
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
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kBrand,
        foregroundColor: Colors.white,
        onPressed: () => openAddNews(context),
        icon: const Icon(Icons.add),
        label: Text(app.tr('Add news', 'செய்தி சேர்க்க')),
      ),
      body: Column(
        children: [
          ScreenHeader(
            kind: HeaderKind.news,
            title: app.tr('News', 'செய்திகள்'),
            subtitle: app.tr('Aruppukottai and around, today', 'அருப்புக்கோட்டை மற்றும் சுற்றுவட்டாரம், இன்று'),
            trailing: [HeaderButton(icon: Icons.list_alt_rounded, onTap: () => openMyNews(context))],
          ),
          Expanded(
            child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 90),
            children: [
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
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
                )
              else
                for (final n in _items)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _NewsCard(item: n),
                  ),
            ],
          ),
        ),
          ),
        ],
      ),
    );
  }
}
