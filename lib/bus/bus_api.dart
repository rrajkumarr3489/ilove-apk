import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../app_state.dart';
import '../config.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);

  @override
  String toString() => message;
}

/// Thin HTTP client for the I Love APK server.
class BusApi {
  static Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Device-Id': app.deviceId,
      'X-App-Version': kAppVersion,
    };
    final t = app.token;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  static Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final base = Uri.parse('${app.apiBase}$path');
    final uri = (query == null || query.isEmpty)
        ? base
        : base.replace(queryParameters: query);
    final res =
        await http.get(uri, headers: _headers).timeout(const Duration(seconds: 25));
    return _handle(res);
  }

  static Future<dynamic> post(String path, Object body) async {
    final uri = Uri.parse('${app.apiBase}$path');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    return _handle(res);
  }

  /// Sends a picture (JPEG bytes) as the request body.
  static Future<dynamic> postBytes(String path, List<int> bytes) async {
    final uri = Uri.parse('${app.apiBase}$path');
    final h = Map<String, String>.from(_headers);
    h['Content-Type'] = 'image/jpeg';
    final res = await http.post(uri, headers: h, body: bytes).timeout(const Duration(seconds: 60));
    return _handle(res);
  }

  /// The host blocks HTTP PUT (error 405), so "put" is sent as POST; the server accepts both for these routes.
  static Future<dynamic> put(String path, Object body) async {
    final uri = Uri.parse('${app.apiBase}$path');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 25));
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (data == null) {
        throw ApiException(app.tr(
            'Unexpected reply from the server.', 'சர்வரிலிருந்து தவறான பதில் வந்தது.'));
      }
      return data;
    }
    var msg = app.tr('Server problem (${res.statusCode}). Please try again.',
        'சர்வரில் சிக்கல் (${res.statusCode}). மீண்டும் முயற்சிக்கவும்.');
    if (data is Map && data['error'] is Map) {
      final m = (data['error'] as Map)['message'];
      if (m != null) msg = m.toString();
    }
    throw ApiException(msg, res.statusCode);
  }

  /// A short message that is safe to show to people.
  static String friendly(Object e) {
    if (e is ApiException) return e.message;
    if (e is TimeoutException) {
      return app.tr('The server is slow. Check your internet and try again.',
          'சர்வர் தாமதமாகிறது. இணைய இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.');
    }
    if (e is SocketException) {
      return app.tr('No internet connection.', 'இணைய இணைப்பு இல்லை.');
    }
    return app.tr('Could not reach the server.', 'சர்வரை அடைய முடியவில்லை.');
  }
}
