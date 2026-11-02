import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'approvals.dart';
import 'bus/bus_api.dart';
import 'classifieds.dart';
import 'home_shell.dart';
import 'news_submit.dart';
import 'firebase_config.dart';

/// Lets the push service show a dialog from anywhere (attached to MaterialApp in main.dart).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Push notifications (Firebase). Only a logged-in person gives his phone's token to the server;
/// the server alerts the mobile numbers listed in the table dbo.PushRecipients.
class PushService {
  static const String _channelId = 'ilove_alerts';
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _channelId,
    'I Love APK alerts',
    description: 'New news and job alerts',
    importance: Importance.max,
  );
  static bool _ready = false;
  static String _localError = '';
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
      await _initLocal();
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

  /// Creates the high-importance channel (banner at the top of the screen, also on the lock screen).
  static Future<void> _initLocal() async {
    try {
      // The app icon is called launcher_icon (made by the icon generator); ic_launcher is the fallback.
      Object? last;
      var ok = false;
      for (final res in const ['@mipmap/launcher_icon', '@mipmap/ic_launcher']) {
        try {
          await _local.initialize(
            InitializationSettings(android: AndroidInitializationSettings(res)),
            onDidReceiveNotificationResponse: (r) => _tap(r.payload ?? ''),
          );
          ok = true;
          break;
        } catch (e) {
          last = e;
        }
      }
      if (!ok) throw last ?? 'no icon';
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (e) {
      _localError = 'init: $e';
    }
  }

  /// The app is open: Android does not show a banner by itself, so show the same kind of
  /// notification at the top of the screen (tap opens the page).
  static Future<void> _onForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    final payload = _payloadOf(m);
    // The icon resource is only checked when a notification is shown, so try both names.
    var shown = false;
    for (final res in const ['@drawable/ic_stat_notify', '@mipmap/launcher_icon', '@mipmap/ic_launcher']) {
      try {
        await _local.show(
          m.hashCode & 0x7fffffff,
          n.title ?? '',
          n.body ?? '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: res,
            ),
          ),
          payload: payload,
        );
        shown = true;
        _localError = _localError.startsWith('init:') ? _localError : '';
        break;
      } catch (e) {
        _localError = 'show($res): $e';
      }
    }
    if (shown) return;
    if (_localError.isNotEmpty) _showDialogFallback(n.title ?? '', '${n.body ?? ''}\n\n[banner problem] $_localError', _payloadOf(m));
  }

  /// Used only when the banner could not be shown: the alert still reaches the person (and shows what went wrong).
  static void _showDialogFallback(String title, String body, String url) {
    final ctx = rootNavigatorKey.currentState?.overlay?.context;
    if (ctx == null) return;
    showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.notifications_active, color: Color(0xFFE8590C), size: 34),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(app.tr('Later', 'பிறகு'))),
          if (url.isNotEmpty)
            FilledButton(
              onPressed: () {
                Navigator.pop(c);
                _tap(url);
              },
              child: Text(app.tr('Open', 'திற')),
            ),
        ],
      ),
    );
  }

  /// News / job alerts open the in-app approval screen; anything else with a link opens that link.
  static String _payloadOf(RemoteMessage m) {
    final type = (m.data['type'] ?? '').toString();
    // The sender is told the result: approved -> open that list, not approved -> open "my news / my jobs" (shows the reason).
    if (type == 'approved_news') return 'open:news';
    if (type == 'approved_jobs') return 'open:jobs';
    if (type == 'rejected_news') return 'open:mynews';
    if (type == 'rejected_jobs') return 'open:myjobs';
    if (type == 'jobs') return 'approvals:jobs';
    if (type == 'news' || type == 'test') return 'approvals:news';
    return (m.data['url'] ?? '').toString();
  }

  /// The person tapped the notification.
  static void _open(RemoteMessage m) => _tap(_payloadOf(m));

  static void _tap(String payload) {
    if (payload.isEmpty) return;
    if (payload.startsWith('approvals')) {
      _openApprovals(payload.endsWith(':jobs') ? 1 : 0);
    } else if (payload.startsWith('open:')) {
      _openPage(payload.substring(5));
    } else {
      _openUrl(payload);
    }
  }

  /// When the app was closed, the screen is not ready at once, so wait a little for it.
  static Future<void> _openApprovals(int tab) async {
    for (var i = 0; i < 20; i++) {
      final nav = rootNavigatorKey.currentState;
      if (nav != null) {
        nav.push(MaterialPageRoute<void>(builder: (_) => ApprovalsScreen(initialTab: tab)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Opens the News list, the Jobs (classifieds) list, or the person's own news / jobs list.
  static Future<void> _openPage(String page) async {
    for (var i = 0; i < 20; i++) {
      final nav = rootNavigatorKey.currentState;
      final ctx = rootNavigatorKey.currentContext;
      if (nav != null && ctx != null) {
        if (page == 'news') {
          nav.push(MaterialPageRoute<void>(builder: (_) => const NewsListScreen()));
        } else if (page == 'jobs') {
          nav.push(MaterialPageRoute<void>(builder: (_) => const ClassifiedsScreen()));
        } else if (page == 'mynews') {
          openMyNews(ctx);
        } else if (page == 'myjobs') {
          openMyJobs(ctx);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  static Future<void> _openUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
