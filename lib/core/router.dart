import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/client/appointments.dart';
import '../features/client/booking.dart';
import '../features/client/care.dart';
import '../features/client/doctors.dart';
import '../features/client/giftcards.dart';
import '../features/client/home.dart';
import '../features/client/payments.dart';
import '../features/client/reminders_screen.dart';
import '../features/client/rewards.dart';
import '../features/client/shop.dart';
import '../features/common/account.dart';
import '../features/common/chat.dart';
import '../features/student/student.dart';
import 'session.dart';

int _id(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '') ?? 0;
Map<String, dynamic> _extra(GoRouterState s) => s.extra is Map ? Map<String, dynamic>.from(s.extra as Map) : <String, dynamic>{};

const _public = {'/welcome', '/login', '/register', '/otp', '/forgot'};

final router = GoRouter(
  initialLocation: '/splash',
  refreshListenable: session,
  redirect: (context, state) {
    final loc = state.matchedLocation;
    switch (session.status) {
      case AuthStatus.unknown:
        // Remember where the user was going (deep link / notification) until the session is known.
        return loc == '/splash' ? null : Uri(path: '/splash', queryParameters: {'from': state.uri.toString()}).toString();
      case AuthStatus.signedOut:
        if (loc == '/splash') {
          final from = state.uri.queryParameters['from'];
          return from != null && _public.contains(Uri.parse(from).path) ? from : '/welcome';
        }
        return _public.contains(loc) ? null : '/welcome';
      case AuthStatus.signedIn:
        if (session.mustChangePassword) return loc == '/set-password' ? null : '/set-password';
        if (loc == '/splash') {
          final from = state.uri.queryParameters['from'];
          final path = from == null ? '' : Uri.parse(from).path;
          final ok = path.isNotEmpty && path != '/splash' && !_public.contains(path) && path != '/set-password' && !(session.isStudent ? _clientOnly(path) : _studentOnly(path));
          return ok ? from : session.home;
        }
        if (loc == '/set-password' || _public.contains(loc)) return session.home;
        // keep clients and students in their own app
        if (session.isStudent && _clientOnly(loc)) return '/s-home';
        if (session.isClient && _studentOnly(loc)) return '/home';
        return null;
    }
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/login', builder: (_, s) => LoginScreen(student: s.uri.queryParameters['role'] == 'student')),
    GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    GoRoute(path: '/otp', builder: (_, s) => OtpScreen(phone: _extra(s)['phone']?.toString() ?? '', purpose: _extra(s)['purpose']?.toString() ?? 'register')),
    GoRoute(path: '/forgot', builder: (_, _) => const ForgotScreen()),
    GoRoute(path: '/set-password', builder: (_, _) => const SetPasswordScreen()),

    // ---------------------------------------------------------- client tabs
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => ClientShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, _) => const HomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/doctors', builder: (_, s) => DoctorsScreen(serviceId: int.tryParse(s.uri.queryParameters['service'] ?? '')))]),
        StatefulShellBranch(routes: [GoRoute(path: '/rewards', builder: (_, _) => const RewardsScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/shop', builder: (_, _) => const ShopScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
      ],
    ),

    // ---------------------------------------------------------- student tabs
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => StudentShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/s-home', builder: (_, _) => const StudentHomeScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/s-courses', builder: (_, _) => const CoursesScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/s-chats', builder: (_, _) => const TeacherChatsScreen())]),
        StatefulShellBranch(routes: [GoRoute(path: '/s-profile', builder: (_, _) => const ProfileScreen(student: true))]),
      ],
    ),

    // ---------------------------------------------------------- client screens
    GoRoute(path: '/doctor/:id', builder: (_, s) => DoctorScreen(id: _id(s))),
    GoRoute(
      path: '/book',
      builder: (_, s) {
        final e = _extra(s);
        return BookScreen(doctorId: e['doctorId'] as int?, serviceId: e['serviceId'] as int?, online: e['online'] == true);
      },
    ),
    GoRoute(path: '/book/review', builder: (_, s) => BookReviewScreen(f: _extra(s))),
    GoRoute(path: '/success', builder: (_, s) => SuccessScreen(s: _extra(s))),
    GoRoute(path: '/appointments', builder: (_, s) => AppointmentsScreen(tab: s.uri.queryParameters['tab'] ?? 'upcoming')),
    GoRoute(path: '/appointment/:id', builder: (_, s) => AppointmentScreen(id: _id(s))),
    GoRoute(path: '/payments', builder: (_, _) => const PaymentsScreen()),
    GoRoute(path: '/pay/:id', builder: (_, s) => PayScreen(id: _id(s))),
    GoRoute(path: '/product/:id', builder: (_, s) => ProductScreen(id: _id(s))),
    GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
    GoRoute(path: '/orders', builder: (_, _) => const OrdersScreen()),
    GoRoute(path: '/order/:id', builder: (_, s) => OrderScreen(id: _id(s))),
    GoRoute(path: '/prescriptions', builder: (_, _) => const PrescriptionsScreen()),
    GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
    GoRoute(path: '/prescription/:id', builder: (_, s) => PrescriptionScreen(id: _id(s))),
    GoRoute(path: '/complaints', builder: (_, _) => const ComplaintsScreen()),
    GoRoute(path: '/complaints/new', builder: (_, _) => const NewComplaintScreen()),
    GoRoute(path: '/complaint/:id', builder: (_, s) => ComplaintScreen(id: _id(s))),
    GoRoute(path: '/rewards/catalog', builder: (_, _) => const RewardCatalogScreen()),
    GoRoute(path: '/rewards/vouchers', builder: (_, _) => const VouchersScreen()),
    GoRoute(path: '/rewards/ways', builder: (_, _) => const WaysToEarnScreen()),
    GoRoute(path: '/rewards/history', builder: (_, _) => const PointsHistoryScreen()),
    GoRoute(path: '/rewards/use', builder: (_, _) => const UsePointsScreen()),
    GoRoute(path: '/rewards/requests', builder: (_, _) => const PointsRequestsScreen()),
    GoRoute(path: '/rewards/refer', builder: (_, _) => const ReferScreen()),
    GoRoute(path: '/tier-up', builder: (_, s) => TierUpScreen(tier: _extra(s))),
    GoRoute(path: '/gift-cards', builder: (_, _) => const GiftCardsScreen()),
    GoRoute(path: '/gift-cards/buy', builder: (_, _) => const GiftBuyScreen()),
    GoRoute(path: '/gift-cards/add', builder: (_, _) => const GiftAddScreen()),
    GoRoute(path: '/gift-card/:id', builder: (_, s) => GiftCardScreen(id: _id(s))),

    // ---------------------------------------------------------- student screens
    GoRoute(path: '/course/:id', builder: (_, s) => CourseScreen(id: _id(s))),
    GoRoute(path: '/my-course/:id', builder: (_, s) => MyCourseScreen(id: _id(s))),
    GoRoute(path: '/lesson/:id', builder: (_, s) => LessonScreen(id: _id(s))),
    GoRoute(path: '/certificate/:id', builder: (_, s) => CertificateScreen(id: _id(s))),

    // ---------------------------------------------------------- shared
    GoRoute(
      path: '/chat/:id',
      builder: (_, s) => ChatRoomScreen(id: _id(s), title: _extra(s)['title']?.toString() ?? 'Chat', subtitle: _extra(s)['subtitle']?.toString()),
    ),
    GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
    GoRoute(path: '/news/:id', builder: (_, s) => NewsScreen(id: _id(s))),
    GoRoute(path: '/profile/edit', builder: (_, _) => const EditProfileScreen()),
    GoRoute(path: '/profile/password', builder: (_, _) => const ChangePasswordScreen()),
  ],
  errorBuilder: (context, state) => Scaffold(appBar: AppBar(), body: const Center(child: Text('Page not found'))),
);

bool _studentOnly(String loc) => loc.startsWith('/s-') || loc.startsWith('/my-course') || loc.startsWith('/lesson') || loc.startsWith('/certificate');

const _clientRoots = [
  '/home', '/doctors', '/doctor', '/rewards', '/shop', '/chats', '/profile', '/book', '/success', '/appointments', '/appointment', '/payments', '/pay',
  '/product', '/cart', '/checkout', '/orders', '/order', '/prescriptions', '/prescription', '/reminders', '/complaints', '/complaint', '/tier-up', '/gift-cards', '/gift-card',
];

bool _clientOnly(String loc) => !loc.startsWith('/profile/') && _clientRoots.any((p) => loc == p || loc.startsWith('$p/'));
