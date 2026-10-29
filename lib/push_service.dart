import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'bus/bus_api.dart';
import 'firebase_config.dart';

/// Lets the push service show a dialog from anywhere (attached to MaterialApp in main.dart).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Push notifications (Firebase). Only a logged-in person gives his phone's token to the server;
/// the server alerts the mobile numbers listed in the table dbo.PushRecipients.
class PushService {
  static bool _ready = false;
  static String _lastAppToken = '';
  static String _lastSent = '';

  static bool get enabled => kFbApiKey.isNotEmpty && kFbAppId.isNotEmpty && kFbSenderId.isNotEmpty && kFbProjectId.isNotEmpty;

  static Future<void> init() async {
    if (!enabled || _ready) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(apiKey: kFbApiKey, appId: kFbAppId, messagingSenderId: kFbSenderId, projectId: kFbProjectId),
      );
      _ready = true;
      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      FirebaseMessaging.instance.onTokenRefresh.listen(_send);
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) _open(first);
      _lastAppToken = app.token ?? '';
      app.addListener(_onAppChanged);
      await registerForUser();
    } catch (_) {
      // Push is optional: the app works without it.
    }
  }

  /// Called after start and whenever the login changes.
  static Future<void> registerForUser() async {
    if (!_ready) return;
    final login = app.token ?? '';
    if (login.isEmpty) return;
    try {
      await FirebaseMessaging.instance.requestPermission();
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await _send(t);
    } catch (_) {}
  }

  static void _onAppChanged() {
    final now = app.token ?? '';
    if (now != _lastAppToken) {
      _lastAppToken = now;
      registerForUser();
    }
  }

  static Future<void> _send(String token) async {
    final login = app.token ?? '';
    if (token.isEmpty || login.isEmpty) return;
    final key = '$login|$token';
    if (key == _lastSent) return;
    try {
      await BusApi.post('/push/token', <String, dynamic>{'deviceId': app.deviceId, 'fcmToken': token});
      _lastSent = key;
    } catch (_) {}
  }

  /// The app is open: show the message as a dialog (the system tray only shows it when the app is closed).
  static void _onForeground(RemoteMessage m) {
    final n = m.notification;
    final ctx = rootNavigatorKey.currentState?.overlay?.context;
    if (n == null || ctx == null) return;
    final url = (m.data['url'] ?? '').toString();
    showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.notifications_active, color: Color(0xFFE8590C), size: 34),
        title: Text(n.title ?? ''),
        content: Text(n.body ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(app.tr('Later', 'பிறகு'))),
          if (url.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                _openUrl(url);
              },
              child: Text(app.tr('Open', 'திற')),
            ),
        ],
      ),
    );
  }

  /// The person tapped the notification: open the page it points to (the approval page).
  static void _open(RemoteMessage m) {
    final url = (m.data['url'] ?? '').toString();
    if (url.isNotEmpty) _openUrl(url);
  }

  static Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
