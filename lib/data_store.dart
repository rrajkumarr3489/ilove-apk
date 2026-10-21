import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// All data access in the app goes through this interface.
///
/// Today: [LocalFileStore] keeps everything in a data.json file + an images
/// folder on the phone. Later, when your server is ready, write a
/// `RemoteStore implements DataStore` (download JSON from the server, cache it
/// locally) and change the single line at the bottom of this file. No screen
/// needs to change.
abstract class DataStore {
  Future<void> init();
  List<Item> items(String section);
  Future<void> save(String section, List<Item> list);

  /// Copies a picked photo into the local images folder, returns its file name.
  Future<String> importImage(String sourcePath);
  File? imageFile(String name);

  String get dataFilePath;
  String get imagesFolderPath;

  Future<void> resetDemo();
}

class LocalFileStore implements DataStore {
  final Map<String, List<Item>> _data = {};
  late Directory _dir;
  late File _file;
  late Directory _imgDir;

  @override
  String get dataFilePath => _file.path;

  @override
  String get imagesFolderPath => _imgDir.path;

  @override
  Future<void> init() async {
    _dir = await getApplicationDocumentsDirectory();
    _file = File('${_dir.path}/data.json');
    _imgDir = Directory('${_dir.path}/images');
    if (!_imgDir.existsSync()) _imgDir.createSync(recursive: true);

    if (!_file.existsSync()) await _seed();
    try {
      _parse(await _file.readAsString());
    } catch (_) {
      // Broken file -> fall back to the bundled demo data.
      await _seed();
      _parse(await _file.readAsString());
    }
  }

  Future<void> _seed() async {
    final text = await rootBundle.loadString('assets/data.json');
    await _file.writeAsString(text);
  }

  void _parse(String text) {
    final map = jsonDecode(text) as Map<String, dynamic>;
    final sections = (map['sections'] as Map<String, dynamic>?) ?? {};
    _data.clear();
    sections.forEach((key, value) {
      _data[key] = (value as List)
          .map((e) => Item.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });
  }

  Future<void> _write() async {
    final map = {
      'sections': _data.map(
        (key, list) => MapEntry(key, list.map((e) => e.toJson()).toList()),
      ),
    };
    await _file
        .writeAsString(const JsonEncoder.withIndent('  ').convert(map));
  }

  @override
  List<Item> items(String section) =>
      _data.putIfAbsent(section, () => <Item>[]);

  @override
  Future<void> save(String section, List<Item> list) async {
    _data[section] = list;
    await _write();
  }

  @override
  Future<String> importImage(String sourcePath) async {
    var ext = '.jpg';
    final dot = sourcePath.lastIndexOf('.');
    if (dot != -1 && sourcePath.length - dot <= 5) {
      ext = sourcePath.substring(dot);
    }
    final name = '${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy('${_imgDir.path}/$name');
    return name;
  }

  @override
  File? imageFile(String name) {
    if (name.isEmpty) return null;
    final f = File('${_imgDir.path}/$name');
    return f.existsSync() ? f : null;
  }

  @override
  Future<void> resetDemo() async {
    await _seed();
    _parse(await _file.readAsString());
  }
}

/// The one place that decides where data comes from.
final DataStore store = LocalFileStore();
