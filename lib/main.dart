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

  // Phone notifications: medicine reminders + updates (booking approved, payment received…).
  await reminders.init();
  await PushService.init();
  void open(String? payload) {
    if (payload == null || payload.isEmpty) return;
    router.push(payload == 'reminders' ? '/reminders' : payload);
  }

  reminders.onOpen = open;
  PushService.onOpen = open;

  var wasIn = false;
  var wasClient = false;
  session.addListener(() {
    final signedIn = session.status == AuthStatus.signedIn && !session.mustChangePassword;
    final isClient = signedIn && session.isClient;
    if (signedIn && !wasIn) {
      InboxAlerts.start();
      PushService.register();
      reminders.launchPayload().then(open); // opened by tapping one of our notifications
    }
    if (!signedIn && wasIn) {
      InboxAlerts.reset();
      PushService.unregister();
    }
    if (isClient && !wasClient) reminders.sync();
    if (!isClient && wasClient) reminders.clear();
    wasIn = signedIn;
    wasClient = isClient;
  });
  await session.start();
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
