import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'data_store.dart';
import 'models.dart';

/// One screen that serves every live section (bus, temples, shops, news).
class SectionScreen extends StatefulWidget {
  final TileInfo tile;
  const SectionScreen({super.key, required this.tile});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  late List<Item> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Item>.of(store.items(widget.tile.key));
  }

  Future<void> _persist() => store.save(widget.tile.key, _items);

  Future<void> _edit([Item? existing]) async {
    final result = await Navigator.push<Item>(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(item: existing, tile: widget.tile),
      ),
    );
    if (result == null) return;
    setState(() {
      final i = _items.indexWhere((e) => e.id == result.id);
      if (i >= 0) {
        _items[i] = result;
      } else {
        _items.insert(0, result);
      }
    });
    await _persist();
  }

  Future<void> _delete(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(item.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _items.removeWhere((e) => e.id == item.id));
    await _persist();
  }

  void _showDetails(Item item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ItemImage(item: item, height: 180, radius: 14),
              if (item.image.isNotEmpty) const SizedBox(height: 12),
              Text(item.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              if (item.titleTa.isNotEmpty)
                Text(item.titleTa,
                    style: TextStyle(fontSize: 16, color: widget.tile.color)),
              if (item.subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.subtitle,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
              if (item.details.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(item.details, style: const TextStyle(fontSize: 15)),
              ],
              if (item.phone.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.phone, size: 18),
                  const SizedBox(width: 6),
                  SelectableText(item.phone),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tile = widget.tile;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tile.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(tile.titleTa, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: tile.color.withAlpha(40),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: tile.color,
        foregroundColor: Colors.white,
        onPressed: () => _edit(),
        child: const Icon(Icons.add),
      ),
      body: _items.isEmpty
          ? const Center(child: Text('Nothing here yet. Tap + to add.'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                return Card(
                  elevation: 0,
                  color: tile.color.withAlpha(20),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    onTap: () => _showDetails(item),
                    leading: item.image.isNotEmpty
                        ? ItemImage(item: item, height: 52, width: 52, radius: 10)
                        : CircleAvatar(
                            backgroundColor: tile.color,
                            child: Icon(tile.icon, color: Colors.white),
                          ),
                    title: Text(item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [
                        if (item.titleTa.isNotEmpty) item.titleTa,
                        if (item.subtitle.isNotEmpty) item.subtitle,
                      ].join('\n'),
                    ),
                    isThreeLine: item.titleTa.isNotEmpty &&
                        item.subtitle.isNotEmpty,
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit') _edit(item);
                        if (v == 'delete') _delete(item);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Shows an item's photo from the local images folder (nothing if none).
class ItemImage extends StatelessWidget {
  final Item item;
  final double height;
  final double? width;
  final double radius;
  const ItemImage({
    super.key,
    required this.item,
    required this.height,
    this.width,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final File? f = store.imageFile(item.image);
    if (f == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        f,
        height: height,
        width: width ?? double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(height: height, width: width),
      ),
    );
  }
}

class EditItemScreen extends StatefulWidget {
  final Item? item;
  final TileInfo tile;
  const EditItemScreen({super.key, this.item, required this.tile});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late final TextEditingController _title;
  late final TextEditingController _titleTa;
  late final TextEditingController _subtitle;
  late final TextEditingController _details;
  late final TextEditingController _phone;
  String _image = '';
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _title = TextEditingController(text: it?.title ?? '');
    _titleTa = TextEditingController(text: it?.titleTa ?? '');
    _subtitle = TextEditingController(text: it?.subtitle ?? '');
    _details = TextEditingController(text: it?.details ?? '');
    _phone = TextEditingController(text: it?.phone ?? '');
    _image = it?.image ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _titleTa.dispose();
    _subtitle.dispose();
    _details.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked == null) return;
    final name = await store.importImage(picked.path);
    if (!mounted) return;
    setState(() => _image = name);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Item(
        id: widget.item?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        titleTa: _titleTa.text.trim(),
        subtitle: _subtitle.text.trim(),
        details: _details.text.trim(),
        phone: _phone.text.trim(),
        image: _image,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = Item(id: 'preview', image: _image);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add item' : 'Edit item'),
        actions: [
          TextButton(onPressed: _save, child: const Text('SAVE')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Title (English)', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleTa,
              decoration: const InputDecoration(
                  labelText: 'Title (தமிழ்)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subtitle,
              decoration: const InputDecoration(
                  labelText: 'Short info (timings, place, date...)',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _details,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                  labelText: 'Details', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Phone (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ItemImage(item: preview, height: 160, radius: 12),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: Text(_image.isEmpty ? 'Add photo' : 'Change photo'),
                ),
                const SizedBox(width: 8),
                if (_image.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _image = ''),
                    child: const Text('Remove'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
