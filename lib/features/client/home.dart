import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'reminders_screen.dart' show TodayMedicinesCard;
import 'shop.dart' show ProductArt;

/// Bottom tabs for clients: Home · Doctors · Rewards · Shop · Chat · Profile.
class ClientShell extends StatelessWidget {
  const ClientShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.medical_services_outlined, Icons.medical_services_rounded, 'Doctors'),
    (Icons.workspace_premium_outlined, Icons.workspace_premium_rounded, 'Rewards'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Shop'),
    (Icons.forum_outlined, Icons.forum_rounded, 'Chat'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: LvTabBar(
          index: shell.currentIndex,
          tabs: tabs,
          onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      );
}

/// Tab bar styled like the design (`.tabbar`): mint pill behind the active icon.
class LvTabBar extends StatelessWidget {
  const LvTabBar({super.key, required this.index, required this.tabs, required this.onTap, this.badges = const {}});
  final int index;
  final List<(IconData, IconData, String)> tabs;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        padding: EdgeInsets.fromLTRB(4, 8, 4, 8 + MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: i == index ? C.mint : Colors.transparent, borderRadius: BorderRadius.circular(99)),
                      child: Icon(i == index ? tabs[i].$2 : tabs[i].$1, color: i == index ? C.tealDeep : C.muted, size: 22),
                    ),
                    if ((badges[i] ?? 0) > 0) Positioned(right: -2, top: -4, child: CountBubble(badges[i]!)),
                  ]),
                  const SizedBox(height: 4),
                  Text(tabs[i].$3,
                      maxLines: 1,
                      style: TextStyle(fontSize: 11, color: i == index ? C.tealDeep : C.muted, fontWeight: i == index ? FontWeight.w500 : FontWeight.w400)),
                ]),
              ),
            ),
        ]),
      );
}

// ---------------------------------------------------------------- home

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<Map<String, dynamic>> _load() async {
    Future<T?> safe<T>(Future<T> f) => f.then<T?>((v) => v).catchError((_) => null);
    final r = await Future.wait([
      safe(api.get('/client/appointments', {'tab': 'upcoming'})),
      safe(api.get('/client/appointments', {'tab': 'requests'})),
      safe(api.get('/client/prescriptions')),
      safe(api.get('/catalog/news', {'per_page': 6})),
      safe(api.get('/catalog/services', {'online': 0})),
      safe(api.get('/catalog/products', {'in_stock': 1, 'per_page': 6})),
      safe(api.get('/client/rewards')),
      safe(api.get('/client/payments')),
    ]);
    session.refreshUnread();
    final upcoming = listOf(r[0])..sort((a, b) => a.str('starts_at').compareTo(b.str('starts_at')));
    return {
      'next': upcoming.where((a) => a.str('status') == 'approved').firstOrNull,
      'pending': listOf(r[1]).length,
      'rx': listOf(r[2]).where((p) => p.str('status') == 'sent').firstOrNull,
      'news': listOf(r[3]),
      'services': listOf(r[4]),
      'products': listOf(r[5]),
      'rewards': r[6] == null ? null : dataOf(r[6]),
      'owed': r[7] is Map && (r[7] as Map)['meta'] is Map ? (((r[7] as Map)['meta'] as Map)['outstanding'] as num?)?.toInt() ?? 0 : 0,
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StatusBarScrim(child: Loader<Map<String, dynamic>>(
          load: _load,
          builder: (context, d, reload) {
            final next = d['next'] as Json?;
            final rx = d['rx'] as Json?;
            final rw = d['rewards'] as Json?;
            final online = session.config['online_consultation'] is Map ? Map<String, dynamic>.from(session.config['online_consultation']) : null;
            return ListView(padding: EdgeInsets.zero, children: [
              TealHeader(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 58),
                child: Column(children: [
                  Row(children: [
                    Avatar(name: session.name, size: 46, hue: 28, url: session.user?['avatar_url']?.toString()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${greeting()},', style: const TextStyle(color: C.mint, fontSize: 13)),
                        Text(firstName(session.name), style: serif(28, color: Colors.white, height: 1)),
                      ]),
                    ),
                    ListenableBuilder(
                      listenable: session,
                      builder: (_, _) => CircleIconButton(Icons.notifications_outlined, onDark: true, dot: session.unread > 0, onTap: () => context.push('/notifications')),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => context.go('/doctors'),
                    borderRadius: BorderRadius.circular(99),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: .2))),
                      child: const Row(children: [
                        Icon(Icons.search_rounded, color: C.mint, size: 21),
                        SizedBox(width: 10),
                        Text('Search treatments or doctors', style: TextStyle(color: C.mint, fontSize: 14)),
                      ]),
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Transform.translate(
                    offset: const Offset(0, -40),
                    child: next != null ? _NextCard(a: next) : _BookCard(),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -28),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if ((d['owed'] as int? ?? 0) > 0) ...[
                        Banner2(
                          tone: Tone.warn,
                          icon: Icons.payments_outlined,
                          onTap: () => context.push('/payments'),
                          trailing: const Icon(Icons.chevron_right_rounded, color: C.warnInk),
                          text: Text.rich(TextSpan(children: [
                            TextSpan(text: 'You have ${etb(d['owed'] as int)} to pay', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const TextSpan(text: ' — pay at reception or upload your receipt.'),
                          ])),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (rw != null) _RewardsStrip(rw: rw),
                      const TodayMedicinesCard(),
                      if ((d['pending'] as int) > 0) ...[
                        const SizedBox(height: 12),
                        Banner2(
                          tone: Tone.warn,
                          icon: Icons.hourglass_top_rounded,
                          onTap: () => context.push('/appointments?tab=requests'),
                          trailing: const Icon(Icons.chevron_right_rounded, color: C.warnInk),
                          text: Text.rich(TextSpan(children: [
                            TextSpan(text: '${d['pending']} request${d['pending'] == 1 ? '' : 's'} waiting', style: const TextStyle(fontWeight: FontWeight.w600)),
                            const TextSpan(text: ' for reception to approve'),
                          ])),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(children: [
                        for (final (icon, label, to) in [
                          (Icons.calendar_month_rounded, 'Book', '/book'),
                          (Icons.event_note_rounded, 'Visits', '/appointments'),
                          (Icons.receipt_long_rounded, 'Payments', '/payments'),
                          (Icons.support_agent_rounded, 'Help', '/complaints'),
                        ])
                          Expanded(child: _Tile(icon: icon, label: label, onTap: () => context.push(to))),
                      ]),
                      if (online != null) ...[
                        const SizedBox(height: 20),
                        _OnlinePromo(service: online),
                      ],
                      if (rx != null) ...[
                        const SizedBox(height: 20),
                        LvCard(
                          color: C.goldSoft,
                          borderColor: const Color(0xFFEAD8CC),
                          onTap: () => context.push('/prescription/${rx['id']}'),
                          child: Row(children: [
                            Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.medication_rounded, color: C.goldInk)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('New prescription', style: TextStyle(fontWeight: FontWeight.w500)),
                                Muted('${rx.obj('doctor').str('name', 'Your doctor')} recommended ${rx.list('items').length} products', size: 12.5),
                              ]),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ]),
                        ),
                      ],
                      if ((d['news'] as List).isNotEmpty) ...[
                        const SectionTitle('News from Lavish'),
                        _HScroll(children: [for (final n in d['news'] as List<Json>) _NewsCard(n: n)]),
                      ],
                      if ((d['services'] as List).isNotEmpty) ...[
                        SectionTitle('Our treatments', action: 'See all', onAction: () => context.go('/doctors')),
                        _HScroll(children: [
                          for (final s in (d['services'] as List<Json>).take(8))
                            _ServiceCard(s: s, onTap: () => context.push('/book', extra: {'serviceId': s['id']})),
                        ]),
                      ],
                      if ((d['products'] as List).isNotEmpty) ...[
                        SectionTitle('Recommended for you', action: 'Shop', onAction: () => context.go('/shop')),
                        _HScroll(children: [
                          for (final p in d['products'] as List<Json>)
                            SizedBox(
                              width: 140,
                              child: InkWell(
                                onTap: () => context.push('/product/${p['id']}'),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  ProductArt(product: p, height: 120),
                                  const SizedBox(height: 8),
                                  Text(p.str('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, height: 1.3)),
                                  Text(etb(p['price'] as num?), style: serif(16)),
                                ]),
                              ),
                            ),
                        ]),
                      ],
                    ]),
                  ),
                ]),
              ),
            ]);
          },
        )),
      );
}

class _NextCard extends StatelessWidget {
  const _NextCard({required this.a});
  final Json a;
  @override
  Widget build(BuildContext context) {
    final doc = a.objOrNull('doctor');
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: C.tealDeep.withValues(alpha: .12), blurRadius: 30, offset: const Offset(0, 12))]),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () => context.push('/appointment/${a['id']}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [Expanded(child: Label('Next appointment')), Pill('Confirmed', tone: Tone.ok, icon: Icons.check_rounded)]),
                const SizedBox(height: 6),
                Text(a.flag('is_online') ? 'Online consultation' : a.obj('service').str('name'), style: serif(21)),
                const SizedBox(height: 10),
                Row(children: [
                  Avatar(name: doc?.str('name') ?? '?', hue: doc?['hue'] as num?, size: 30),
                  const SizedBox(width: 10),
                  Text(doc?.str('name') ?? 'Doctor to be assigned'),
                ]),
              ]),
            ),
            Container(
              color: C.goldSoft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: DefaultTextStyle(
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF6C4B39)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6C4B39)),
                  const SizedBox(width: 5),
                  Text(dayShort(a.str('starts_at'))),
                  const SizedBox(width: 14),
                  const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF6C4B39)),
                  const SizedBox(width: 5),
                  Text(a.str('time')),
                  const SizedBox(width: 14),
                  Icon(a.flag('is_online') ? Icons.videocam_rounded : Icons.location_on_rounded, size: 16, color: const Color(0xFF6C4B39)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(a.flag('is_online') ? 'Online' : a.obj('branch').str('name'), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: C.tealDeep.withValues(alpha: .12), blurRadius: 30, offset: const Offset(0, 12))]),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const IconBox(Icons.calendar_month_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('No upcoming visits', style: serif(19)),
              const Muted('Book a treatment with one of our doctors', size: 12.5),
            ]),
          ),
          LvButton('Book', small: true, expand: false, onTap: () => context.push('/book')),
        ]),
      );
}

class _RewardsStrip extends StatelessWidget {
  const _RewardsStrip({required this.rw});
  final Json rw;
  @override
  Widget build(BuildContext context) {
    final member = rw['member'] == true;
    final open = rw.integer('open_requests');
    return LvCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.go('/rewards'),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.tealGlow, C.tealNight], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.workspace_premium_rounded, color: C.goldSoft),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Muted(member ? '${rw.obj('tier').str('name', 'Glow')} · Lavish Rewards' : 'Lavish Rewards', size: 12),
            Text(member ? '${number(rw['points_balance'] as num?)} points' : 'Ask at reception to join', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ]),
        ),
        if (member && open > 0) Pill('$open request${open == 1 ? '' : 's'} open', tone: Tone.gold),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C3C0)),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)),
            child: Icon(icon, color: C.dark, size: 26),
          ),
          const SizedBox(height: 7),
          Text(label, style: const TextStyle(fontSize: 12)),
        ]),
      );
}

class _OnlinePromo extends StatelessWidget {
  const _OnlinePromo({required this.service});
  final Json service;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/book', extra: {'online': true}),
        borderRadius: BorderRadius.circular(20),
        child: TealHeader(
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.video_call_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('See a doctor online', style: serif(20, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${service.integer('duration_minutes', 45)}-min video consultation from home · ${etb(service['price'] as num?)}',
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .85))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ]),
        ),
      );
}

class _HScroll extends StatelessWidget {
  const _HScroll({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < children.length; i++) Padding(padding: EdgeInsets.only(right: i == children.length - 1 ? 0 : 12), child: children[i]),
        ]),
      );
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.n});
  final Json n;
  @override
  Widget build(BuildContext context) {
    final img = n.str('image_url');
    final hue = (n['hue'] as num?)?.toDouble() ?? 185;
    return SizedBox(
      width: 240,
      child: LvCard(
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/news/${n['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [HSLColor.fromAHSL(1, hue, .4, .42).toColor(), HSLColor.fromAHSL(1, hue, .45, .26).toColor()]),
              image: img.isNotEmpty ? DecorationImage(image: NetworkImage(img), fit: BoxFit.cover) : null,
            ),
            padding: const EdgeInsets.all(10),
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .25), borderRadius: BorderRadius.circular(99)),
              child: Text(n.str('tag', 'News'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          Text(n.str('title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, height: 1.3)),
          const SizedBox(height: 2),
          Muted(dayLong(n.str('published_at', n.str('created_at'))), size: 12),
        ]),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.s, required this.onTap});
  final Json s;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 132,
        child: LvCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBox(iconFor(s.str('icon')), small: true),
            const SizedBox(height: 10),
            SizedBox(height: 34, child: Text(s.str('name'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, height: 1.3))),
            const SizedBox(height: 4),
            Muted('from ${etb(s['price'] as num?)}', size: 12),
          ]),
        ),
      );
}
