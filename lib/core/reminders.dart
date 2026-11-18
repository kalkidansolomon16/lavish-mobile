import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';

/// One dose on a given day ("Vitamin C serum at 08:00 on 19 Nov").
class Dose {
  Dose({required this.itemId, required this.name, required this.instructions, required this.at});
  final int itemId;
  final String name;
  final String instructions;
  final DateTime at;

  String get key => '$itemId|${DateFormat('yyyy-MM-dd HH:mm').format(at)}';
  String get time => DateFormat('HH:mm').format(at);
}

/// Medicine reminders from prescriptions. The doctor sets the times and the number of days in the portal;
/// the app turns them into phone notifications (they work offline). Because phones limit how many alarms an
/// app may keep (iOS: 64), only the next [windowDays] days are scheduled; opening the app tops the window up.
class MedReminders extends ChangeNotifier {
  MedReminders._();
  static final MedReminders instance = MedReminders._();

  static const windowDays = 14;
  static const _maxScheduled = 60;
  static const _channel = AndroidNotificationDetails(
    'med_reminders',
    'Medicine reminders',
    channelDescription: 'Reminders to take the products and medicines your Lavish doctor prescribed',
    importance: Importance.high,
    priority: Priority.high,
  );

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  SharedPreferences? _prefs;

  /// Prescription items that have reminders: {id, name, instructions, reminder: {times, starts_on, ends_on, active}, prescription_id, doctor}.
  List<Json> items = [];
  Set<int> off = {};
  Set<String> taken = {};
  bool? allowed;

  /// Called when the user taps a notification: payload is 'reminders' or an app route like '/appointment/5'.
  void Function(String? payload)? onOpen;

  /// Bookings, payments, orders… shown as phone notifications (also used by Firebase push).
  static const updatesChannel = AndroidNotificationDetails(
    'lavish_updates',
    'Lavish updates',
    channelDescription: 'Bookings, payments, orders, messages and rewards',
    importance: Importance.high,
    priority: Priority.high,
  );

  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    off = (_prefs!.getStringList('rem_off') ?? []).map(int.parse).toSet();
    taken = (_prefs!.getStringList('rem_taken') ?? []).toSet();
    if (!supported) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Addis_Ababa'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
      onDidReceiveNotificationResponse: (r) => onOpen?.call(r.payload),
    );
    // Create the channels up front so Firebase can use "lavish_updates" while the app is closed.
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel('lavish_updates', 'Lavish updates',
        description: 'Bookings, payments, orders, messages and rewards', importance: Importance.high));
    await android?.createNotificationChannel(const AndroidNotificationChannel('med_reminders', 'Medicine reminders',
        description: 'Reminders to take the products and medicines your Lavish doctor prescribed', importance: Importance.high));
    _ready = true;
    await _checkAllowed();
  }

  /// The tap that opened the app from a notification (if any) — handled once the router is ready.
  Future<String?> launchPayload() async {
    if (!_ready) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    return d?.didNotificationLaunchApp == true ? d!.notificationResponse?.payload : null;
  }

  /// Shows an update (booking approved, payment received…) as a phone notification now.
  Future<void> showUpdate({required int id, required String title, required String body, String? route}) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: updatesChannel, iOS: DarwinNotificationDetails()),
      payload: route,
    );
  }

  /// Fetches the client's prescriptions and reschedules every reminder.
  Future<void> sync() async {
    try {
      final list = listOf(await api.get('/client/prescriptions'));
      items = [
        for (final rx in list)
          for (final i in rx.list('items'))
            if (i.objOrNull('reminder') != null)
              {
                'id': i['id'],
                'name': i.flag('is_custom') ? i.str('custom_name') : i.obj('product').str('name'),
                'instructions': i.str('instructions'),
                'reminder': i['reminder'],
                'prescription_id': rx['id'],
                'doctor': rx.obj('doctor').str('name'),
              },
      ];
      notifyListeners();
      // First time a reminder arrives: ask once for notification permission (Android 13+ / iPhone).
      if (items.any(isActive) && allowed != true && _prefs?.getBool('rem_asked') != true) {
        await _prefs?.setBool('rem_asked', true);
        await askPermission();
        return;
      }
      await _schedule();
    } catch (_) {
      // Offline: keep what is already scheduled.
    }
  }

  /// Signed out: remove every reminder from this phone.
  Future<void> clear() async {
    items = [];
    notifyListeners();
    if (_ready) await _plugin.cancelAllPendingNotifications();
  }

  /// Asks for notification permission (Android 13+ / iOS) and, on Android, for on-time alarms.
  Future<bool> askPermission() async {
    if (!_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await a?.requestNotificationsPermission();
      if (await a?.canScheduleExactNotifications() == false) await a?.requestExactAlarmsPermission();
    } else {
      await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true, badge: true);
    }
    await _checkAllowed();
    await _schedule();
    return allowed ?? false;
  }

  Future<void> setOn(int itemId, bool on) async {
    on ? off.remove(itemId) : off.add(itemId);
    await _prefs?.setStringList('rem_off', off.map((e) => '$e').toList());
    notifyListeners();
    await _schedule();
  }

  Future<void> setTaken(Dose d, bool yes) async {
    yes ? taken.add(d.key) : taken.remove(d.key);
    // keep two weeks of history
    final cutoff = DateTime.now().subtract(const Duration(days: 14));
    taken.removeWhere((k) => (DateTime.tryParse(k.split('|').last) ?? DateTime.now()).isBefore(cutoff));
    await _prefs?.setStringList('rem_taken', taken.toList());
    notifyListeners();
    await _schedule(); // a dose marked taken early is not reminded
  }

  bool isActive(Json item) => item.obj('reminder')['active'] == true && !off.contains(item['id']);

  /// Doses on [day] for every active reminder, earliest first.
  List<Dose> dosesOn(DateTime day) {
    final d0 = DateTime(day.year, day.month, day.day);
    final out = <Dose>[];
    for (final i in items.where(isActive)) {
      final r = i.obj('reminder');
      final start = DateTime.tryParse(r.str('starts_on'));
      final end = DateTime.tryParse(r.str('ends_on'));
      if (start != null && d0.isBefore(start)) continue;
      if (end != null && d0.isAfter(end)) continue;
      for (final t in (r['times'] as List? ?? const [])) {
        final p = t.toString().split(':');
        out.add(Dose(itemId: i['id'] as int, name: i.str('name'), instructions: i.str('instructions'), at: DateTime(d0.year, d0.month, d0.day, int.parse(p[0]), int.parse(p[1]))));
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  Future<void> _checkAllowed() async {
    if (!_ready) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      allowed = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled();
    } else {
      final s = await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.checkPermissions();
      allowed = s?.isEnabled;
    }
    notifyListeners();
  }

  Future<void> _schedule() async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications(); // scheduled reminders only — updates already shown stay
    if (items.where(isActive).isEmpty) return;

    var mode = AndroidScheduleMode.inexactAllowWhileIdle;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final ok = await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.canScheduleExactNotifications();
      if (ok == true) mode = AndroidScheduleMode.exactAllowWhileIdle;
    }

    final now = DateTime.now();
    var id = 1;
    var continuesAfterWindow = false;
    for (var day = 0; day < windowDays && id <= _maxScheduled; day++) {
      for (final d in dosesOn(now.add(Duration(days: day)))) {
        if (id > _maxScheduled) break;
        if (!d.at.isAfter(now) || taken.contains(d.key)) continue;
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: tz.TZDateTime.from(d.at, tz.local),
          notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
          androidScheduleMode: mode,
          title: 'Time for ${d.name}',
          body: d.instructions.isNotEmpty ? d.instructions : 'Tap to mark it as taken in Lavish.',
          payload: 'reminders',
        );
      }
    }
    // A course longer than the window: remind the client to open the app so reminders carry on.
    final windowEnd = DateTime(now.year, now.month, now.day).add(const Duration(days: windowDays));
    for (final i in items.where(isActive)) {
      final end = DateTime.tryParse(i.obj('reminder').str('ends_on'));
      if (end == null || end.isAfter(windowEnd)) continuesAfterWindow = true;
    }
    if (continuesAfterWindow && id <= _maxScheduled + 1) {
      await _plugin.zonedSchedule(
        id: 999,
        scheduledDate: tz.TZDateTime.from(windowEnd.subtract(const Duration(days: 1)).add(const Duration(hours: 10)), tz.local),
        notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: 'Keep your medicine reminders going',
        body: 'Open Lavish so we can schedule the next two weeks of reminders.',
        payload: 'reminders',
      );
    }
  }
}

final reminders = MedReminders.instance;
