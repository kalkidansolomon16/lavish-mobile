import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../features/common/account.dart' show routeForTarget;
import 'api.dart';
import 'reminders.dart';
import 'session.dart';

/// Shows the signed-in person's new notifications (booking approved, payment received, order on the way,
/// new message…) as phone notifications.
///
/// Without Firebase this runs while the app is open (every minute) and each time it comes back to the
/// front. With Firebase (see push.dart) notifications also arrive while the app is closed; both paths share
/// the "already shown" list so nothing pops up twice.
class InboxAlerts {
  static Timer? _timer;
  static const _lastKey = 'inbox_last';
  static const _shownKey = 'inbox_shown';
  static final _shown = <String>{};
  static bool _loaded = false;

  static Future<void> start() async {
    stop();
    await _load();
    await check();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => check());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Signed out: forget what this phone has seen (the next person starts fresh).
  static Future<void> reset() async {
    stop();
    _shown.clear();
    final p = await SharedPreferences.getInstance();
    await p.remove(_lastKey);
    await p.remove(_shownKey);
  }

  static Future<void> check() async {
    if (session.status != AuthStatus.signedIn) return;
    try {
      final res = await api.get('/notifications', {'per_page': 15});
      final items = listOf(res);
      final unread = res is Map && res['meta'] is Map ? (res['meta']['unread'] as num?)?.toInt() : null;
      if (unread != null) session.setUnread(unread);
      final p = await SharedPreferences.getInstance();
      final last = p.getString(_lastKey);
      if (items.isNotEmpty) await p.setString(_lastKey, items.first.str('created_at'));
      if (last == null) return; // first run on this phone: don't replay old notifications
      final fresh = items.where((n) => n['read'] != true && n.str('created_at').compareTo(last) > 0).toList().reversed;
      for (final n in fresh) {
        await show(n.str('id'), n.str('title'), n.str('body'), n['target'] is Map ? n['target'] as Map : null);
      }
    } catch (_) {
      // offline — try again next time
    }
  }

  /// Shows one notification unless it was already shown (by polling or by Firebase).
  static Future<void> show(String nid, String title, String body, Map? target) async {
    await _load();
    if (nid.isNotEmpty && _shown.contains(nid)) return;
    if (nid.isNotEmpty) {
      _shown.add(nid);
      final p = await SharedPreferences.getInstance();
      final keep = _shown.toList();
      await p.setStringList(_shownKey, keep.length > 100 ? keep.sublist(keep.length - 100) : keep);
    }
    // ids 1–999 are medicine reminders; updates use 1000+
    final id = 1000 + (nid.isEmpty ? DateTime.now().millisecondsSinceEpoch : nid.hashCode).abs() % 1000000;
    await reminders.showUpdate(id: id, title: title, body: body, route: routeForTarget(target) ?? '/notifications');
    session.refreshUnread();
  }

  static Future<void> _load() async {
    if (_loaded) return;
    _loaded = true;
    final p = await SharedPreferences.getInstance();
    _shown.addAll(p.getStringList(_shownKey) ?? const []);
  }
}
