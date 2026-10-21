import 'package:flutter/material.dart';

import 'data_store.dart';
import 'models.dart';
import 'section_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: const [
            _HomeTab(),
            _PlaceholderTab(
                icon: Icons.favorite,
                title: 'Favorites',
                titleTa: 'பிடித்தவை'),
            _PlaceholderTab(
                icon: Icons.article,
                title: 'Updates',
                titleTa: 'புதிய தகவல்கள்'),
            _SettingsTab(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favorites'),
          NavigationDestination(icon: Icon(Icons.article), label: 'Updates'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _Header(),
        const _Banner(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [for (final t in kTiles) _TileCard(tile: t)],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w900),
                    children: [
                      const TextSpan(
                          text: 'I ',
                          style: TextStyle(color: Color(0xFFF57C00))),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Icons.favorite,
                            color: Colors.red.shade600, size: 36),
                      ),
                      const TextSpan(
                          text: ' APK',
                          style: TextStyle(color: Color(0xFFD9541E))),
                    ],
                  ),
                ),
                const Text('I Love Aruppukottai',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B5D3B))),
                const SizedBox(height: 2),
                const Text('நம் ஊர் • நம் மக்கள் • நம் ஆப்',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE5581B))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, size: 28),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Notifications will work once the server is ready.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFFFFE0B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.temple_hindu, size: 64, color: Color(0xFF8D5524)),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('அருப்புக்கோட்டை',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF3E2723))),
              Text('ARUPPUKOTTAI',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Color(0xFF3E2723))),
            ],
          ),
        ],
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  final TileInfo tile;
  const _TileCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tile.color.withAlpha(28),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => tile.live
                  ? SectionScreen(tile: tile)
                  : _ComingSoon(tile: tile),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: tile.color,
                child: Icon(tile.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(tile.titleTa,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: tile.color)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final TileInfo tile;
  const _ComingSoon({required this.tile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tile.title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: tile.color,
              child: Icon(tile.icon, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 16),
            Text(tile.titleTa, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Coming soon / விரைவில்',
                style: TextStyle(fontSize: 16, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String titleTa;
  const _PlaceholderTab(
      {required this.icon, required this.title, required this.titleTa});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.black38),
          const SizedBox(height: 12),
          Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          Text(titleTa),
          const SizedBox(height: 8),
          const Text('Coming soon', style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text(
            'All your edits will be replaced by the original demo data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    await store.resetDemo();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Demo data restored.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text('Data file (notepad-style JSON)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        SelectableText(store.dataFilePath),
        const SizedBox(height: 12),
        const Text('Images folder',
            style: TextStyle(fontWeight: FontWeight.w700)),
        SelectableText(store.imagesFolderPath),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restore),
          label: const Text('Reset demo data'),
        ),
      ],
    );
  }
}
