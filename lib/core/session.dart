import 'package:flutter/foundation.dart';

import 'api.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Who is signed in, plus the app config from GET /catalog/config. The router listens to this.
class Session extends ChangeNotifier {
  Session._() {
    api.onUnauthenticated = () {
      if (status == AuthStatus.signedIn) _signOutLocal();
    };
  }
  static final Session instance = Session._();

  AuthStatus status = AuthStatus.unknown;
  Json? user;
  Json config = {};
  int unread = 0;

  bool get isStudent => user?['type'] == 'student';
  bool get isClient => user?['type'] == 'client';
  bool get mustChangePassword => user?['must_change_password'] == true;
  String get name => user?['name']?.toString() ?? '';
  bool get onlinePayments => config['online_payments_enabled'] == true;
  String get home => isStudent ? '/s-home' : '/home';

  /// App start: load the saved token and config, then GET /auth/me.
  Future<void> start() async {
    try {
      await _start();
    } catch (_) {
      // Never leave the app on the splash screen: anything unexpected → the sign-in screens.
      if (status == AuthStatus.unknown) status = api.token != null && user != null ? AuthStatus.signedIn : AuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> _start() async {
    await api.loadToken();
    await loadConfig().timeout(const Duration(seconds: 20), onTimeout: () {});
    if (api.token == null) {
      status = AuthStatus.signedOut;
    } else {
      try {
        user = dataOf(await api.get('/auth/me'));
        status = AuthStatus.signedIn;
        refreshUnread();
      } on ApiException catch (e) {
        if (e.code == 'password_change_required' && user != null) {
          status = AuthStatus.signedIn;
        } else if (e.code == 'offline') {
          // Keep the token; show the sign-in screens only if we have nothing.
          status = AuthStatus.signedOut;
        } else {
          await api.saveToken(null);
          status = AuthStatus.signedOut;
        }
      }
    }
  }

  Future<void> loadConfig() async {
    try {
      config = dataOf(await api.get('/catalog/config'));
    } catch (_) {}
  }

  Future<void> login(String login, String password) async {
    final res = await api.post('/auth/login', {'login': login, 'password': password, 'app': 'mobile', 'device_name': _device()});
    await _signedIn(res);
  }

  /// Step 1 of sign-up: the server sends an SMS code. Returns the phone in E.164.
  Future<String> register(Map<String, dynamic> body) async {
    final res = await api.post('/auth/register', body);
    return (res is Map ? res['phone'] : null)?.toString() ?? body['phone'].toString();
  }

  Future<void> verify(String phone, String code) async {
    final res = await api.post('/auth/register/verify', {'phone': phone, 'code': code, 'device_name': _device()});
    await _signedIn(res);
  }

  Future<void> resendOtp(String phone, String purpose) => api.post('/auth/otp/resend', {'phone': phone, 'purpose': purpose});

  Future<void> forgot(String phone) => api.post('/auth/password/forgot', {'phone': phone});

  Future<void> reset(String phone, String code, String password) async {
    final res = await api.post('/auth/password/reset', {'phone': phone, 'code': code, 'password': password, 'password_confirmation': password});
    await _signedIn(res);
  }

  Future<void> changePassword(String current, String password) async {
    await api.post('/auth/password/change', {'current_password': current, 'password': password, 'password_confirmation': password});
    user = {...?user, 'must_change_password': false};
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try {
      user = dataOf(await api.get('/auth/me'));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> updateMe(Map<String, dynamic> body) async {
    user = dataOf(await api.patch('/auth/me', body));
    notifyListeners();
  }

  void setUser(Json u) {
    user = u;
    notifyListeners();
  }

  void setUnread(int n) {
    if (n == unread) return;
    unread = n;
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    try {
      final res = await api.get('/notifications/unread-count');
      final n = res is Map ? (res['data'] is Map ? res['data']['unread'] : res['unread'] ?? res['count']) : null;
      unread = n is num ? n.toInt() : 0;
      notifyListeners();
    } catch (_) {}
  }

  /// Firebase token of this phone (set by PushService) — removed from the server on sign-out.
  String? deviceToken;

  Future<void> logout() async {
    try {
      await api.post('/auth/logout', {if (deviceToken != null) 'device_token': deviceToken});
    } catch (_) {}
    _signOutLocal();
  }

  Future<void> _signedIn(dynamic res) async {
    final r = res as Map;
    await api.saveToken(r['token'].toString());
    user = Map<String, dynamic>.from(r['user'] as Map);
    if (user?['type'] == 'staff') {
      await api.saveToken(null);
      user = null;
      throw ApiException(403, 'wrong_app', 'Staff accounts use the Lavish web portal, not the app.');
    }
    status = AuthStatus.signedIn;
    notifyListeners();
    refreshUnread();
  }

  void _signOutLocal() {
    api.saveToken(null);
    user = null;
    unread = 0;
    status = AuthStatus.signedOut;
    notifyListeners();
  }

  String _device() => kIsWeb ? 'Lavish web' : 'Lavish ${defaultTargetPlatform.name}';
}

final session = Session.instance;
