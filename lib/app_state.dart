import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

/// Small settings holder: language, device id and server address.
class AppState extends ChangeNotifier {
  SharedPreferences? _p;
  String lang = 'ta';
  String deviceId = '';
  String _server = '';
  String? token;
  String userJson = '';

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    lang = p.getString('lang') ?? 'ta';
    deviceId = p.getString('deviceId') ?? '';
    if (deviceId.length < 8) {
      deviceId = _newId();
      await p.setString('deviceId', deviceId);
    }
    _server = p.getString('server') ?? '';
    final t = p.getString('auth.token');
    token = (t == null || t.isEmpty) ? null : t;
    userJson = p.getString('auth.user') ?? '';
  }

  /// Keeps the login on the phone so the person stays logged in.
  Future<void> setSession(String newToken, String newUserJson) async {
    token = newToken;
    userJson = newUserJson;
    await _p?.setString('auth.token', newToken);
    await _p?.setString('auth.user', newUserJson);
    notifyListeners();
  }

  Future<void> setUserJson(String newUserJson) async {
    userJson = newUserJson;
    await _p?.setString('auth.user', newUserJson);
    notifyListeners();
  }

  Future<void> clearSession() async {
    token = null;
    userJson = '';
    await _p?.remove('auth.token');
    await _p?.remove('auth.user');
    notifyListeners();
  }

  String _newId() {
    final r = Random.secure();
    final sb = StringBuffer('d');
    for (var i = 0; i < 20; i++) {
      sb.write(r.nextInt(16).toRadixString(16));
    }
    return sb.toString();
  }

  /// Text in the chosen language (falls back to English when Tamil is empty).
  String tr(String en, String ta) => (lang == 'ta' && ta.isNotEmpty) ? ta : en;

  Future<void> setLang(String value) async {
    lang = value;
    await _p?.setString('lang', value);
    notifyListeners();
  }

  String get apiBase => _server.isNotEmpty ? _server : kApiBaseDefault;
  String get serverText => _server;
  bool get serverConfigured => !apiBase.contains('YOUR-SUBDOMAIN');

  /// Accepts "https://api.mysite.com" or the full ".../api/v1" address.
  Future<void> setServer(String value) async {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    if (v.isNotEmpty && !v.startsWith('http')) v = 'https://$v';
    if (v.isNotEmpty && !v.endsWith('/api/v1')) v = '$v/api/v1';
    _server = v;
    await _p?.setString('server', v);
    notifyListeners();
  }

  List<String> getList(String key) => _p?.getStringList(key) ?? <String>[];

  Future<void> setList(String key, List<String> value) async {
    await _p?.setStringList(key, value);
  }

  String? getString(String key) => _p?.getString(key);

  Future<void> setString(String key, String value) async {
    await _p?.setString(key, value);
  }
}

final AppState app = AppState();
