import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/inbox_alerts.dart';
import 'core/push.dart';
import 'core/reminders.dart';
import 'core/router.dart';
import 'core/session.dart';
import 'core/theme.dart';

/// Lavish Medical Spa — client & student app. Same Laravel API as the web portal (see lavish_backend/docs/API.md).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const LavishApp());

  void open(String? payload) {
    if (payload == null || payload.isEmpty) return;
    router.push(payload == 'reminders' ? '/reminders' : payload);
  }

  // Phone notifications (medicine reminders, updates, Firebase) are optional extras: they must never stop the
  // app from opening. Each step is guarded and time-limited; sign-in starts right away in parallel.
  final notificationsReady = () async {
    await _safely('reminders', reminders.init);
    await _safely('push', PushService.init);
    reminders.onOpen = open;
    PushService.onOpen = open;
  }();

  var wasIn = false;
  var wasClient = false;
  session.addListener(() {
    final signedIn = session.status == AuthStatus.signedIn && !session.mustChangePassword;
    final isClient = signedIn && session.isClient;
    if (signedIn && !wasIn) {
      _safely('inbox', InboxAlerts.start);
      notificationsReady.then((_) {
        _safely('push register', PushService.register);
        reminders.launchPayload().then(open).catchError((_) {}); // opened by tapping one of our notifications
      });
    }
    if (!signedIn && wasIn) {
      InboxAlerts.reset();
      _safely('push unregister', PushService.unregister);
    }
    if (isClient && !wasClient) notificationsReady.then((_) => _safely('reminders sync', reminders.sync));
    if (!isClient && wasClient) _safely('reminders clear', reminders.clear);
    wasIn = signedIn;
    wasClient = isClient;
  });
  await session.start();
}

/// Runs an optional start-up step; a failure or a hang (20 s) is logged and ignored.
Future<void> _safely(String what, Future<void> Function() step) async {
  try {
    await step().timeout(const Duration(seconds: 20));
  } catch (e) {
    debugPrint('Lavish: $what skipped — $e');
  }
}

class LavishApp extends StatefulWidget {
  const LavishApp({super.key});
  @override
  State<LavishApp> createState() => _LavishAppState();
}

class _LavishAppState extends State<LavishApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back in the app: show updates that arrived meanwhile, top up reminders, refresh the badge.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || session.status != AuthStatus.signedIn) return;
    InboxAlerts.check();
    if (session.isClient) reminders.sync();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'Lavish',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        routerConfig: router,
      );
}
