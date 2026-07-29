// ════════════════════════════════════════════════════════════════════════════
//  OnlineAuthService — MAC-based online device activation
//  Place at: lib/core/online_auth_service.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ─── Configuration ────────────────────────────────────────────────────────────
class _AuthConfig {
  // ⚠ غير ده لرابط السيرفر بتاعك
  static const String baseUrl = 'http://185.205.246.109:3000';
  static const String endpoint = '/api/v1/device/validate';

  static const String _sharedSecret =
      String.fromEnvironment('AUTH_SECRET', defaultValue: 'CHANGE_ME_IN_PROD');

  // مدة الـ offline grace period بالثواني (86400 = 24 ساعة)
  static const int offlineGracePeriodSeconds = 86400;

  static const String _cacheStatusKey    = 'oauthcache_status';
  static const String _cacheTimestampKey = 'oauthcache_ts';
  static const String _cacheMacKey       = 'oauthcache_mac';
  static const String _cacheExpiryKey    = 'oauthcache_expiry';

  static const Duration requestTimeout = Duration(seconds: 8);

  static String get sharedSecret => _sharedSecret;
}

// ─── Result model ─────────────────────────────────────────────────────────────
enum AuthStatus {
  allowed,
  blocked,
  notFound,
  offline,
  error,
}

class AuthResult {
  final AuthStatus status;
  final String message;
  final bool fromCache;
  final DateTime? expiryDate;

  const AuthResult({
    required this.status,
    required this.message,
    this.fromCache = false,
    this.expiryDate,
  });

  bool get isAllowed => status == AuthStatus.allowed;
}

// ─── Main Service ─────────────────────────────────────────────────────────────
class OnlineAuthService {
  OnlineAuthService._();

  static Future<AuthResult> validate(String appId) async {
    await _log('Validation started for appId=$appId');

    final mac = await getMacAddress();
    if (mac.isEmpty) {
      await _log('ERROR: Could not read MAC address');
      return const AuthResult(
        status: AuthStatus.error,
        message: 'تعذر قراءة معرّف الجهاز',
      );
    }

    await _log('MAC=$mac | appId=$appId');

    try {
      final result = await _validateOnline(mac, appId);
      if (result.status == AuthStatus.allowed) {
        await _writeCache(mac, result);
      } else {
        await _clearCache();
      }
      await _log('Online result: ${result.status} — ${result.message}');
      return result;
    } on SocketException {
      await _log('Network unavailable — checking offline cache');
      return _offlineFallback(mac);
    } on TimeoutException {
      await _log('Request timed out — checking offline cache');
      return _offlineFallback(mac);
    } catch (e) {
      await _log('Unexpected error: $e');
      return _offlineFallback(mac);
    }
  }

  // ── Online validation ─────────────────────────────────────────────────────
  static Future<AuthResult> _validateOnline(String mac, String appId) async {
    final deviceName = await _getDeviceName();
    final timestamp  = DateTime.now().millisecondsSinceEpoch.toString();

    final body = <String, dynamic>{
      'mac_address': mac,
      'app_id':      appId,
      'device_name': deviceName,
      'timestamp':   timestamp,
    };

    final signature = _signRequest(body);
    body['signature'] = signature;

    final response = await http
        .post(
          Uri.parse('${_AuthConfig.baseUrl}${_AuthConfig.endpoint}'),
          headers: {
            'Content-Type':        'application/json',
            'X-Auth-Signature':    signature,
            'X-Request-Timestamp': timestamp,
          },
          body: jsonEncode(body),
        )
        .timeout(_AuthConfig.requestTimeout);

    if (response.statusCode == 200 || response.statusCode == 403) {
      return _parseResponse(response.body);
    }
    throw Exception('HTTP ${response.statusCode}');
  }

  static AuthResult _parseResponse(String body) {
    try {
      final data    = jsonDecode(body) as Map<String, dynamic>;
      final status  = data['status']?.toString() ?? '';
      final message = data['message']?.toString() ?? '';
      final expiry  = data['expiry_date'] != null
          ? DateTime.tryParse(data['expiry_date'].toString())
          : null;

      switch (status) {
        case 'allowed':
          return AuthResult(
            status: AuthStatus.allowed,
            message: message,
            expiryDate: expiry,
          );
        case 'blocked':
          return AuthResult(
            status: AuthStatus.blocked,
            message: message.isNotEmpty ? message : 'الجهاز محظور',
          );
        case 'not_found':
          return AuthResult(
            status: AuthStatus.notFound,
            message: message.isNotEmpty ? message : 'الجهاز غير مسجل',
          );
        default:
          return const AuthResult(
            status: AuthStatus.error,
            message: 'استجابة غير متوقعة من الخادم',
          );
      }
    } catch (_) {
      return const AuthResult(
        status: AuthStatus.error,
        message: 'فشل في معالجة استجابة الخادم',
      );
    }
  }

  // ── Offline fallback ──────────────────────────────────────────────────────
  static Future<AuthResult> _offlineFallback(String mac) async {
    final prefs         = await SharedPreferences.getInstance();
    final cachedStatus  = prefs.getString(_AuthConfig._cacheStatusKey);
    final cachedMac     = prefs.getString(_AuthConfig._cacheMacKey);
    final cachedTs      = prefs.getInt(_AuthConfig._cacheTimestampKey);
    final cachedExpiry  = prefs.getString(_AuthConfig._cacheExpiryKey);

    if (cachedStatus == null || cachedMac == null || cachedTs == null) {
      return const AuthResult(
        status: AuthStatus.offline,
        message: 'لا يوجد اتصال بالإنترنت ولا يوجد تفعيل مؤقت مخزّن',
      );
    }

    if (cachedMac != _hashMac(mac)) {
      return const AuthResult(
        status: AuthStatus.blocked,
        message: 'بيانات التفعيل المخزنة لا تطابق هذا الجهاز',
      );
    }

    if (cachedStatus != 'allowed') {
      return const AuthResult(
        status: AuthStatus.blocked,
        message: 'الجهاز غير مصرح له',
      );
    }

    final nowSecs     = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final elapsedSecs = nowSecs - (cachedTs ~/ 1000);
    if (elapsedSecs > _AuthConfig.offlineGracePeriodSeconds) {
      await _clearCache();
      return const AuthResult(
        status: AuthStatus.offline,
        message: 'انتهت صلاحية التفعيل المؤقت — يرجى الاتصال بالإنترنت',
      );
    }

    if (cachedExpiry != null) {
      final expiry = DateTime.tryParse(cachedExpiry);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        await _clearCache();
        return const AuthResult(
          status: AuthStatus.blocked,
          message: 'انتهت صلاحية ترخيص هذا الجهاز',
        );
      }
    }

    return const AuthResult(
      status: AuthStatus.allowed,
      message: 'وضع التشغيل المؤقت (بدون إنترنت)',
      fromCache: true,
    );
  }

  // ── Cache ─────────────────────────────────────────────────────────────────
  static Future<void> _writeCache(String mac, AuthResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_AuthConfig._cacheStatusKey, 'allowed');
    await prefs.setString(_AuthConfig._cacheMacKey, _hashMac(mac));
    await prefs.setInt(
        _AuthConfig._cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    if (result.expiryDate != null) {
      await prefs.setString(
          _AuthConfig._cacheExpiryKey, result.expiryDate!.toIso8601String());
    } else {
      await prefs.remove(_AuthConfig._cacheExpiryKey);
    }
  }

  static Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_AuthConfig._cacheStatusKey);
    await prefs.remove(_AuthConfig._cacheMacKey);
    await prefs.remove(_AuthConfig._cacheTimestampKey);
    await prefs.remove(_AuthConfig._cacheExpiryKey);
  }

  // ── Signing ───────────────────────────────────────────────────────────────
  static String _hashMac(String mac) {
    final bytes = utf8.encode(mac + _AuthConfig.sharedSecret);
    return sha256.convert(bytes).toString();
  }

  static String _signRequest(Map<String, dynamic> body) {
    final sorted  = Map.fromEntries(
      body.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final payload = sorted.entries.map((e) => '${e.key}=${e.value}').join('&');
    final key     = utf8.encode(_AuthConfig.sharedSecret);
    final msg     = utf8.encode(payload);
    return Hmac(sha256, key).convert(msg).toString();
  }

  // ── MAC Address (Windows / Linux / macOS — no extra packages) ────────────
  static Future<String> getMacAddress() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'getmac', ['/fo', 'csv', '/nh'],
          runInShell: true,
        );
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          final match = RegExp(r'([0-9A-Fa-f]{2}[-]){5}[0-9A-Fa-f]{2}')
              .firstMatch(line);
          if (match != null) {
            return match.group(0)!.replaceAll('-', ':').toUpperCase();
          }
        }
      } else if (Platform.isLinux) {
        final interfaces = await NetworkInterface.list(includeLoopback: false);
        for (final iface in interfaces) {
          final result = await Process.run(
            'cat', ['/sys/class/net/${iface.name}/address'],
          );
          final mac = result.stdout.toString().trim().toUpperCase();
          if (mac.isNotEmpty &&
              mac != '00:00:00:00:00:00' &&
              mac.length == 17) {
            return mac;
          }
        }
      } else if (Platform.isMacOS) {
        final result = await Process.run('ifconfig', ['en0']);
        final match  = RegExp(r'ether\s+([0-9a-fA-F:]{17})')
            .firstMatch(result.stdout.toString());
        if (match != null) return match.group(1)!.toUpperCase();
      }
    } catch (_) {}
    return '';
  }

  static Future<String> _getDeviceName() async {
    try {
      final r = await Process.run(
        'hostname', [],
        runInShell: Platform.isWindows,
      );
      return r.stdout.toString().trim();
    } catch (_) {
      return 'Unknown Device';
    }
  }

  // ── Logging ───────────────────────────────────────────────────────────────
  static Future<void> _log(String message) async {
    final ts = DateTime.now().toIso8601String();
    // ignore: avoid_print
    print('[OnlineAuth] $ts — $message');
  }
}