import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_state.dart';
import '../bus/bus_api.dart';

/// Register / login / logout. The token is kept on the phone (see AppState),
/// so after one login the app opens straight to the home screen.
class AuthService extends ChangeNotifier {
  bool get loggedIn => app.token != null && app.token!.isNotEmpty;

  Map<String, dynamic> get user {
    if (app.userJson.isEmpty) return <String, dynamic>{};
    try {
      return Map<String, dynamic>.from(jsonDecode(app.userJson) as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String get name => (user['displayName'] ?? '').toString();
  String get mobile => (user['mobile'] ?? '').toString();
  String get email => (user['email'] ?? '').toString();

  Future<void> _start(dynamic reply) async {
    final j = reply as Map<String, dynamic>;
    await app.setSession(j['token'].toString(), jsonEncode(j['user']));
    notifyListeners();
  }

  Future<void> register({
    required String mobile,
    required String name,
    required String password,
    String email = '',
  }) async {
    final r = await BusApi.post('/auth/register', <String, dynamic>{
      'mobile': mobile,
      'displayName': name,
      'password': password,
      'email': email,
      'language': app.lang,
      'deviceId': app.deviceId,
    });
    await _start(r);
  }

  Future<void> login(String mobile, String password) async {
    final r = await BusApi.post('/auth/login', <String, dynamic>{
      'mobile': mobile,
      'password': password,
      'deviceId': app.deviceId,
    });
    await _start(r);
  }

  /// Called when the app opens. If the server says the login is no longer valid
  /// the person is sent to the login screen; if there is no internet we keep
  /// them logged in.
  Future<void> validate() async {
    if (!loggedIn || !app.serverConfigured) return;
    try {
      final j = await BusApi.get('/auth/me') as Map<String, dynamic>;
      await app.setUserJson(jsonEncode(j['user']));
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 401) {
        await app.clearSession();
        notifyListeners();
      }
    } catch (_) {
      // No internet: stay logged in.
    }
  }

  /// The server said this login is no longer valid (401): forget it on this phone.
  Future<void> expire() async {
    await app.clearSession();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await BusApi.post('/auth/logout', <String, dynamic>{});
    } catch (_) {
      // Even if the server cannot be reached, log out on this phone.
    }
    await app.clearSession();
    notifyListeners();
  }

  Future<void> updateProfile(String name, String email) async {
    final j = await BusApi.put('/auth/me', <String, dynamic>{
      'displayName': name,
      'email': email,
      'language': app.lang,
    }) as Map<String, dynamic>;
    await app.setUserJson(jsonEncode(j['user']));
    notifyListeners();
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await BusApi.post('/auth/change-password', <String, dynamic>{
      'oldPassword': oldPassword,
      'newPassword': newPassword,
    });
  }

  /// Deletes the account on the server and logs out on this phone.
  Future<void> deleteAccount(String password) async {
    await BusApi.post('/auth/delete-account', <String, dynamic>{'oldPassword': password});
    await app.clearSession();
    notifyListeners();
  }
}

final AuthService auth = AuthService();
