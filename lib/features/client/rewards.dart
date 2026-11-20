import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

/// Tier card colours (same as the design and the web portal).
(Color, Color) tierColors(String key) => switch (key) {
      'glow' => (const Color(0xFFD7B39D), const Color(0xFF9C735C)),
      'elite' => (const Color(0xFF3A3A3A), const Color(0xFF111111)),
      _ => (C.tealGlow, C.tealNight),
    };

Color tierBar(String key) => switch (key) {
      'glow' => C.gold,
      'elite' => C.ink,
      _ => C.dark,
    };

bool _tierUpOpen = false;

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  Future<Map<String, dynamic>> _load() async {
    final r = await Future.wait([
      api.get('/client/rewards'),
      api.get('/client/rewards/ways-to-earn').catchError((_) => null),
      api.get('/client/gift-cards').catchError((_) => null),
    ]);
    return {'rw': dataOf(r[0]), 'ways': r[1] == null ? <String, dynamic>{} : dataOf(r[1]), 'gift': r[2] == null ? <String, dynamic>{} : dataOf(r[2])};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Lavish Rewards', actions: [CircleIconButton(Icons.help_outline_rounded, onTap: () => context.push('/rewards/ways'))]),
        body: Loader<Map<String, dynamic>>(
          load: _load,
          builder: (context, d, reload) {
            final rw = d['rw'] as Json;
            final ways = d['ways'] as Json;
            final giftTotal = (d['gift'] as Json).integer('total_balance');
            if (rw['show_tier_up'] == true && !_tierUpOpen) {
              _tierUpOpen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await context.push('/tier-up', extra: rw.obj('tier'));
                _tierUpOpen = false;
                reload();
              });
            }
            if (rw['member'] != true) return _JoinView(giftTotal: giftTotal, rw: rw, onChanged: reload);
            final tier = rw.obj('tier');
            final held = rw.integer('held_points');
            final openReq = rw.integer('open_requests');
            final nt = rw.objOrNull('next_tier');
            final exp = rw.objOrNull('expiring_soon');
            final tiers = rw.list('tiers');
            final campaign = ways.list('campaigns').where((c) => c['running'] == true).firstOrNull;
            final (t1, t2) = tierColors(tier.str('key'));
            return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              if (rw.str('member_number').isNotEmpty) ...[
                MemberCard(number: rw.str('member_number'), name: session.name),
                const SizedBox(height: 14),
              ],
              GestureDetector(
                onTap: () => context.push('/rewards/history'),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(colors: [t1, t2], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: C.tealNight.withValues(alpha: .35), blurRadius: 40, offset: const Offset(0, 22), spreadRadius: -24)],
                  ),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(right: -60, bottom: -80, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .18))))),
                    DefaultTextStyle(
                      style: const TextStyle(color: Colors.white),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${tier.str('name').toUpperCase()} MEMBER', style: TextStyle(fontSize: 11, letterSpacing: 3, color: Colors.white.withValues(alpha: .8)))),
                          Icon(Icons.workspace_premium_rounded, color: Colors.white.withValues(alpha: .8)),
                        ]),
                        const SizedBox(height: 12),
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text(number(rw['points_balance'] as num?), style: serif(46, color: Colors.white, height: 1)),
                          const SizedBox(width: 6),
                          Text('points', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .8))),
                        ]),
                        const SizedBox(height: 4),
                        Text('Worth ${etb(rw['points_value_etb'] as num?)} · tap for history', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: .85))),
                        if (held > 0) ...[
                          const SizedBox(height: 4),
                          Text('${number(held)} held by your open request${openReq == 1 ? '' : 's'} · ${number(rw['available_points'] as num?)} available',
                              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .9))),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                            onPressed: rw.integer('available_points') > 0
                                ? () async {
                                    await context.push('/rewards/use');
                                    reload();
                                  }
                                : null,
                            icon: const Icon(Icons.redeem_rounded, size: 19),
                            label: const Text('Use my points', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
              if (exp != null) ...[
                const SizedBox(height: 12),
                Banner2(
                  tone: Tone.warn,
                  icon: Icons.hourglass_bottom_rounded,
                  onTap: () => context.push('/rewards/use'),
                  trailing: const Icon(Icons.chevron_right_rounded, color: C.warnInk),
                  text: Text.rich(TextSpan(children: [
                    TextSpan(text: '${number(exp['points'] as num?)} points expire on ${dayLong(exp.str('on'))}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' — use them before then.'),
                  ])),
                ),
              ],
              const SizedBox(height: 20),
              Row(children: [
                for (final (icon, label, to, sub) in [
                  (Icons.receipt_long_outlined, 'My requests', '/rewards/requests', openReq > 0 ? '$openReq open' : ''),
                  (Icons.history_rounded, 'History', '/rewards/history', ''),
                  (Icons.workspace_premium_outlined, 'Benefits', '/rewards/ways', ''),
                  (Icons.group_add_outlined, 'Refer', '/rewards/refer', ''),
                ])
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        await context.push(to);
                        reload();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Column(children: [
                        Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.line)), child: Icon(icon, color: C.dark, size: 26)),
                        const SizedBox(height: 7),
                        Text(label, style: const TextStyle(fontSize: 12)),
                        if (sub.isNotEmpty) Muted(sub, size: 11),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 20),
              LvCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Your tier', style: TextStyle(fontWeight: FontWeight.w500))),
                    Muted('${number(rw['points_12m'] as num?)} pts in 12 months', size: 12.5),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (final t in tiers)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(children: [
                            Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(99), color: rw.integer('points_12m') >= t.integer('min_points_12m') ? tierBar(t.str('key')) : C.grey)),
                            const SizedBox(height: 4),
                            Text(t.str('name'), style: TextStyle(fontSize: 12, fontWeight: t.str('key') == tier.str('key') ? FontWeight.w600 : FontWeight.w400, color: t.str('key') == tier.str('key') ? C.ink : C.muted)),
                          ]),
                        ),
                      ),
                  ]),
                  if (nt != null) ...[
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Earn '),
                        TextSpan(text: '${number(nt['points_needed'] as num?)} more points', style: const TextStyle(color: C.ink, fontWeight: FontWeight.w600)),
                        TextSpan(text: ' in the next 12 months to reach ${nt.str('name')}${(nt['benefits'] as List?)?.isNotEmpty == true ? ' — ${(nt['benefits'] as List).take(2).join(', ').toLowerCase()} and more.' : '.'}'),
                      ]),
                      style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 4),
                  const Muted('Spending points never lowers your tier.', size: 12.5),
                  if ((tier['benefits'] as List?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: C.line),
                    const SizedBox(height: 12),
                    Text('${tier.str('name')} benefits', style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    for (final b in tier['benefits'] as List)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(children: [const Icon(Icons.check_rounded, size: 16, color: C.dark), const SizedBox(width: 6), Expanded(child: Text(b.toString(), style: const TextStyle(fontSize: 13)))]),
                      ),
                  ],
                ]),
              ),
              if (campaign != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => context.push('/rewards/ways'),
                  child: TealHeader(
                    radius: 20,
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(15)),
                        child: Text('${_mult(campaign['multiplier'])}×', style: serif(22, color: Colors.white)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(campaign.str('name'), style: serif(20, color: Colors.white)),
                          Text('Until ${dayShort(campaign.str('ends_at'))}${campaign.str('description').isNotEmpty ? ' · ${campaign.str('description')}' : ''}',
                              style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .85))),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ],
              SectionTitle('Ways to earn', action: 'See all', onAction: () => context.push('/rewards/ways')),
              LvList(children: [
                for (final r in ways.list('rules').take(4)) LvTile(icon: _ruleIcon(r.str('type')), title: _ruleTitle(r.str('type')), subtitle: r.str('text')),
              ]),
            ]);
          },
        ),
      );
}

String _mult(dynamic m) {
  final v = (m as num?)?.toDouble() ?? 1;
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

IconData _ruleIcon(String t) => switch (t) {
      'spend' => Icons.spa_rounded,
      'visit' => Icons.event_available_rounded,
      'product_spend' => Icons.shopping_bag_outlined,
      'referral' => Icons.group_add_outlined,
      'review' => Icons.rate_review_outlined,
      'birthday' => Icons.cake_outlined,
      'signup' => Icons.celebration_outlined,
      'app_booking' => Icons.phone_iphone_rounded,
      _ => Icons.stars_rounded,
    };

String _ruleTitle(String t) => switch (t) {
      'spend' => 'Every treatment',
      'visit' => 'Each completed visit',
      'product_spend' => 'Shop purchases',
      'referral' => 'Refer a friend',
      'review' => 'Review a visit',
      'birthday' => 'Birthday month',
      'signup' => 'Joining',
      'app_booking' => 'Booking in the app',
      _ => 'Bonus',
    };

/// The member card: show this barcode at reception to start using your points.
class MemberCard extends StatelessWidget {
  const MemberCard({super.key, required this.number, required this.name});
  final String number;
  final String name;
  @override
  Widget build(BuildContext context) => LvCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Text('MY LAVISH REWARDS CARD', style: TextStyle(fontSize: 11, letterSpacing: 2.2, fontWeight: FontWeight.w700)),
            const Spacer(),
            Muted(name, size: 12),
          ]),
          const SizedBox(height: 12),
          BarcodeWidget(barcode: Barcode.code128(), data: number, height: 74, drawText: false),
          const SizedBox(height: 8),
          Text('NR $number', textAlign: TextAlign.right, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 2),
          const Muted('Show this at reception when you use your points.', size: 12, align: TextAlign.right),
        ]),
      );
}

/// Not a member yet: one tap joins (no approval needed).
class _JoinView extends StatefulWidget {
  const _JoinView({required this.giftTotal, required this.rw, required this.onChanged});
  final int giftTotal;
  final Json rw;
  final Future<void> Function() onChanged;
  @override
  State<_JoinView> createState() => _JoinViewState();
}

class _JoinViewState extends State<_JoinView> {
  bool busy = false;

  Future<void> _join() async {
    final ok = await confirm(context,
        title: 'Become a Lavish Rewards member?',
        body: 'You’ll collect points on your treatments and shop orders and can use them for discounts. '
            'Lavish keeps your points history and visits for the program. You get a member card with a barcode to show at reception.',
        ok: 'Yes, make me a member');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await api.post('/client/rewards/join');
      if (mounted) toast(context, 'Welcome to Lavish Rewards!');
      await widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
        TealHeader(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.workspace_premium_rounded, color: C.gold, size: 36),
            const SizedBox(height: 12),
            Text('Lavish Rewards', style: serif(30, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('Collect points on your treatments and shop orders, move up tiers and use your points for discounts. Joining is free.',
                style: TextStyle(color: C.mint, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 16),
        LvButton('I want to become a Lavish Rewards member', icon: Icons.how_to_reg_rounded, kind: BtnKind.gold, busy: busy, onTap: _join),
        const SizedBox(height: 16),
        for (final (i, t, s) in [
          (Icons.qr_code_2_rounded, 'Your member card', 'A barcode in the app — show it at reception'),
          (Icons.stars_rounded, 'Collect points', 'On every completed, paid treatment and shop order'),
          (Icons.redeem_rounded, 'Use them your way', 'A discount on a treatment, on shop products or something else'),
          (Icons.trending_up_rounded, 'Better benefits', 'Glow → Radiance → Lavish Elite: earn faster and unlock member prices'),
        ])
          Padding(padding: const EdgeInsets.only(bottom: 10), child: LvCard(child: Row(children: [IconBox(i), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w500)), Muted(s, size: 12.5)]))]))),
      ]);
}

// ---------------------------------------------------------------- use my points

/// Use my points: what for, how many, a note → sent to reception. Points are held until it is handled.
class UsePointsScreen extends StatefulWidget {
  const UsePointsScreen({super.key});
  @override
  State<UsePointsScreen> createState() => _UsePointsScreenState();
}

class _UsePointsScreenState extends State<UsePointsScreen> {
  String kind = 'treatment';
  final points = TextEditingController();
  final note = TextEditingController();
  bool busy = false;
  late Future<Json> _rw = _load();

  Future<Json> _load() async => dataOf(await api.get('/client/rewards'));

  static const kinds = [
    ('treatment', Icons.spa_rounded, 'Discount on a treatment', 'Taken off your treatment bill at Lavish'),
    ('shop', Icons.shopping_bag_outlined, 'Discount on shop products', 'Skincare and medicines from the Lavish shop'),
    ('other', Icons.auto_awesome_outlined, 'Something else', 'Tell us what you’d like'),
  ];

  @override
  void dispose() {
    points.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _send(int available) async {
    final n = int.tryParse(points.text.trim()) ?? 0;
    if (n < 1) return toast(context, 'Enter how many points you want to use', error: true);
    if (n > available) return toast(context, 'You have ${number(available)} points available', error: true);
    if (kind == 'other' && note.text.trim().isEmpty) return toast(context, 'Tell us what you’d like to use the points for', error: true);
    final what = kinds.firstWhere((k) => k.$1 == kind).$3;
    final ok = await confirm(context, title: 'Send to Lavish?', body: '${number(n)} points — ${what.toLowerCase()}.\nReception checks it and lets you know. The points are taken only when they are used.', ok: 'Send request');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await api.post('/client/rewards/requests', {'kind': kind, 'points': n, if (note.text.trim().isNotEmpty) 'note': note.text.trim()});
      if (!mounted) return;
      toast(context, 'Request sent to Lavish');
      context.pushReplacement('/rewards/requests');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Use my points'),
        body: FutureBuilder<Json>(
          future: _rw,
          builder: (context, snap) {
            if (snap.hasError) return ErrorBox(error: snap.error!, onRetry: () => setState(() => _rw = _load()));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final rw = snap.data!;
            final available = rw.integer('available_points');
            final rate = (rw['point_value_etb'] as num?)?.toDouble() ?? 0;
            final n = int.tryParse(points.text.trim()) ?? 0;
            return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              Banner2(icon: Icons.stars_rounded, text: Text.rich(TextSpan(children: [
                const TextSpan(text: 'You have '),
                TextSpan(text: '${number(available)} points', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: ' available · 1 point = ${etb(rate)}'),
              ]))),
              const SectionTitle('What for?'),
              for (final (k, icon, title, sub) in kinds)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RadioCard(selected: kind == k, title: title, subtitle: sub, leading: Icon(icon, color: C.dark), onTap: () => setState(() => kind = k)),
                ),
              const SectionTitle('How many points?'),
              Field(label: '', controller: points, hint: 'e.g. ${available >= 1000 ? 1000 : available}', keyboard: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {})),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final v in {if (available >= 500) 500, if (available >= 1000) 1000, if (available >= 2000) 2000, available})
                  if (v > 0)
                    ActionChip(label: Text(v == available ? 'All · ${number(v)}' : number(v)), onPressed: () => setState(() => points.text = '$v')),
              ]),
              if (n > 0) ...[
                const SizedBox(height: 12),
                LvCard(
                  color: C.mint,
                  borderColor: C.mint,
                  child: Row(children: [
                    const Icon(Icons.local_offer_outlined, color: C.tealDeep),
                    const SizedBox(width: 10),
                    Expanded(child: Text(n > available ? 'More than you have (${number(available)})' : 'Worth about ${etb((n * rate).floor())} off', style: TextStyle(color: n > available ? C.bad : C.tealDeep, fontWeight: FontWeight.w500))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Field(label: kind == 'other' ? 'What would you like?' : 'Note for reception (optional)', controller: note, maxLines: 3,
                  hint: switch (kind) { 'treatment' => 'e.g. For my HydraFacial on Friday', 'shop' => 'e.g. For the sunscreen I’m ordering', _ => 'Describe what you’d like' }),
              const SizedBox(height: 6),
              LvButton('Send to Lavish', busy: busy, icon: Icons.send_rounded, onTap: () => _send(available)),
              const SizedBox(height: 10),
              const Muted('Reception checks your request. Treatment discounts come off your bill; shop discounts are applied by the Lavish shop to your order. You can see every step under My requests.', size: 12.5, align: TextAlign.center),
            ]);
          },
        ),
      );
}

/// My requests to use points, with what happened to each one.
class PointsRequestsScreen extends StatelessWidget {
  const PointsRequestsScreen({super.key});

  static String statusText(String s) => switch (s) {
        'pending' => 'Sent',
        'forwarded' => 'With Lavish Shop',
        'completed' => 'Used',
        'rejected' => 'Not approved',
        'cancelled' => 'Cancelled',
        _ => s,
      };

  static Tone statusTone(String s) => switch (s) {
        'pending' => Tone.warn,
        'forwarded' => Tone.gold,
        'completed' => Tone.ok,
        'rejected' => Tone.bad,
        _ => Tone.grey,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'My requests'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/client/rewards/requests')),
          builder: (context, list, reload) => list.isEmpty
              ? ListView(children: [
                  Empty(icon: Icons.receipt_long_outlined, title: 'No requests yet', text: 'Use your points for a discount on a treatment, shop products or something else.', action: 'Use my points', onAction: () => context.push('/rewards/use')),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final st = r.str('status');
                    final used = r['points_used'] as num?;
                    return LvCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          IconBox(switch (r.str('kind')) { 'shop' => Icons.shopping_bag_outlined, 'treatment' => Icons.spa_rounded, _ => Icons.auto_awesome_outlined }, small: true, tone: Tone.gold),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.str('kind_label'), style: const TextStyle(fontWeight: FontWeight.w500)),
                            Muted(dayLong(r.str('created_at')), size: 12),
                          ])),
                          Pill(statusText(st), tone: statusTone(st)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Text('${number(used ?? r['points'] as num?)} points', style: serif(20)),
                          const SizedBox(width: 8),
                          Muted('· ${etb((r['discount_etb'] ?? r['value_etb']) as num?)}${st == 'completed' ? ' off' : ''}', size: 13),
                        ]),
                        if (r.str('note').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Muted('“${r.str('note')}”', size: 12.5)),
                        if (st == 'completed' && r['bill'] is Map) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Taken off: ${(r['bill'] as Map)['description']}', style: const TextStyle(fontSize: 12.5))),
                        if (r.str('staff_note').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Lavish: ${r.str('staff_note')}', style: const TextStyle(fontSize: 12.5))),
                        if (st == 'pending') ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () async {
                                if (!await confirm(context, title: 'Cancel this request?', body: 'Your points will be free to use again.', ok: 'Cancel request', cancel: 'Keep', danger: true)) return;
                                try {
                                  await api.post('/client/rewards/requests/${r['id']}/cancel');
                                  reload();
                                } catch (e) {
                                  if (context.mounted) showError(context, e);
                                }
                              },
                              child: const Text('Cancel request', style: TextStyle(color: C.bad)),
                            ),
                          ),
                        ],
                      ]),
                    );
                  },
                ),
        ),
      );
}

// ---------------------------------------------------------------- catalog

class RewardCatalogScreen extends StatelessWidget {
  const RewardCatalogScreen({super.key});

  Future<void> _redeem(BuildContext context, Json r, Future<void> Function() reload) async {
    final ok = await confirm(context, title: 'Redeem ${r.str('name')}?', body: '${pts(r['points_cost'] as num?)} will be taken from your balance.\nYou get a voucher to use at your next visit.', ok: 'Redeem');
    if (!ok || !context.mounted) return;
    try {
      final v = dataOf(await api.post('/client/rewards/catalog/${r['id']}/redeem'));
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.celebration_rounded, color: C.gold, size: 40),
          title: Text('Your voucher is ready', textAlign: TextAlign.center, style: serif(24)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(v.str('name'), style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: C.mint, borderRadius: BorderRadius.circular(12)),
              child: Text(v.str('code'), style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 18, color: C.tealDeep, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 10),
            Muted('Use it when you book, or show it at reception. Valid until ${dayLong(v.str('expires_at'))}.', align: TextAlign.center, size: 12.5),
          ]),
          actions: [LvButton('Done', onTap: () => Navigator.pop(c))],
        ),
      );
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Rewards'),
        body: Loader<dynamic>(
          load: () => api.get('/client/rewards/catalog'),
          builder: (context, res, reload) {
            final list = listOf(res);
            final bal = res is Map && res['meta'] is Map ? (res['meta']['points_balance'] as num?) ?? 0 : 0;
            return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              Banner2(icon: Icons.stars_rounded, text: Text.rich(TextSpan(children: [const TextSpan(text: 'You have '), TextSpan(text: pts(bal), style: const TextStyle(fontWeight: FontWeight.w600)), const TextSpan(text: ' to spend.')]))),
              const SizedBox(height: 14),
              for (final r in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Ticket(
                    icon: r.str('reward_type') == 'free_service' ? Icons.spa_rounded : r.str('reward_type') == 'product' ? Icons.inventory_2_outlined : iconFor(r.str('icon'), Icons.redeem_rounded),
                    off: r['affordable'] == false || r['locked'] == true,
                    title: r.str('name'),
                    subtitle: [
                      r.str('summary'),
                      if (r['locked'] == true) 'For ${r.obj('tier_required').str('name')} members',
                      if (r.str('available_until').isNotEmpty) 'Until ${dayShort(r.str('available_until'))}',
                    ].join(' · '),
                    trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      Text(number(r['points_cost'] as num?), style: serif(18)),
                      const Muted('pts', size: 11),
                      if (r['affordable'] == true && r['locked'] != true) ...[
                        const SizedBox(height: 4),
                        LvButton('Redeem', small: true, expand: false, onTap: () => _redeem(context, r, reload)),
                      ] else if (r['locked'] != true)
                        Muted('${number((r.integer('points_cost') - bal).clamp(0, 1 << 31))} more', size: 11),
                    ]),
                  ),
                ),
              if (list.isEmpty) const Empty(icon: Icons.redeem_rounded, title: 'No rewards right now', text: 'Check back soon — new rewards are added for holidays.'),
            ]);
          },
        ),
      );
}

/// Reward / voucher ticket with a gold stub (`.ticket`).
class Ticket extends StatelessWidget {
  const Ticket({super.key, required this.icon, required this.title, required this.subtitle, this.trailing, this.off = false, this.onTap, this.code});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool off;
  final VoidCallback? onTap;
  final String? code;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: off ? .6 : 1,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  width: 74,
                  decoration: BoxDecoration(
                    gradient: off ? null : const LinearGradient(colors: [C.goldSoft, Color(0xFFECD3C2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    color: off ? const Color(0xFFEFEEEC) : null,
                    border: const Border(right: BorderSide(color: Colors.white, width: 2)),
                  ),
                  child: Icon(icon, size: 30, color: off ? C.muted : const Color(0xFF7A5440)),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Muted(subtitle, size: 12),
                      if (code != null) ...[const SizedBox(height: 4), Text(code!, style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1.5, fontSize: 13, color: C.tealDeep))],
                    ]),
                  ),
                ),
                if (trailing != null) Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: trailing)),
              ]),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- vouchers

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});
  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  String tab = 'issued';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'My vouchers'),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
            child: Seg<String>(items: const [('issued', 'Ready to use'), ('used', 'Used'), ('expired', 'Expired')], value: tab, onChanged: (v) => setState(() => tab = v)),
          ),
          Expanded(
            child: Loader<List<Json>>(
              key: ValueKey(tab),
              load: () async => listOf(await api.get('/client/rewards/vouchers', {'status': tab})),
              builder: (context, list, _) => list.isEmpty
                  ? ListView(children: [
                      Empty(
                        icon: Icons.confirmation_number_outlined,
                        title: tab == 'issued' ? 'No vouchers yet' : 'Nothing here',
                        text: tab == 'issued' ? 'Redeem your points for a reward to get a voucher.' : null,
                        action: tab == 'issued' ? 'See rewards' : null,
                        onAction: () => context.push('/rewards/catalog'),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final v = list[i];
                        return Ticket(
                          icon: v.str('reward_type') == 'free_service' ? Icons.spa_rounded : Icons.redeem_rounded,
                          off: tab != 'issued',
                          title: v.str('name'),
                          subtitle: tab == 'used' ? 'Used ${dayLong(v.str('used_at'))}' : '${v.str('summary')} · until ${dayLong(v.str('expires_at'))}',
                          code: tab == 'issued' ? v.str('code') : null,
                          trailing: tab == 'issued'
                              ? IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 19, color: C.dark),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: v.str('code')));
                                    toast(context, 'Voucher code copied');
                                  },
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ]),
      );
}

// ---------------------------------------------------------------- ways to earn

class WaysToEarnScreen extends StatelessWidget {
  const WaysToEarnScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Ways to earn'),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/client/rewards/ways-to-earn')),
          builder: (context, w, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
            for (final c in w.list('campaigns'))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LvCard(
                  color: c['running'] == true ? C.mint : Colors.white,
                  borderColor: c['running'] == true ? C.mint : C.line,
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c['running'] == true ? C.dark : C.goldSoft, borderRadius: BorderRadius.circular(15)),
                      child: Text('${_mult(c['multiplier'])}×', style: serif(20, color: c['running'] == true ? Colors.white : C.goldInk)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.str('name'), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Muted('${c['running'] == true ? 'On now' : 'From ${dayShort(c.str('starts_at'))}'} · until ${dayShort(c.str('ends_at'))}', size: 12.5),
                        if (c.str('description').isNotEmpty) Text(c.str('description'), style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ]),
                ),
              ),
            LvList(children: [for (final r in w.list('rules')) LvTile(icon: _ruleIcon(r.str('type')), title: _ruleTitle(r.str('type')), subtitle: r.str('text'))]),
            if ((w['not_earning'] as List?)?.isNotEmpty == true) ...[
              const SectionTitle('No points on'),
              LvCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final n in w['not_earning'] as List)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.remove_rounded, size: 16, color: C.muted), const SizedBox(width: 8), Expanded(child: Muted(n.toString()))])),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            const Banner2(text: Text('Points are added when a visit is completed and paid (for Lavish Rewards members). They expire 12 months after you earn them — we remind you before they do.')),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- history

class PointsHistoryScreen extends StatelessWidget {
  const PointsHistoryScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Points history'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/client/rewards/history', {'per_page': 100})),
          builder: (context, list, _) => list.isEmpty
              ? ListView(children: const [Empty(icon: Icons.stars_rounded, title: 'No points yet', text: 'Points from your visits appear here.')])
              : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
                  LvList(children: [
                    for (final h in list)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(children: [
                          IconBox(h.integer('points') >= 0 ? Icons.add_rounded : Icons.remove_rounded, tone: h.integer('points') >= 0 ? Tone.teal : Tone.bad, small: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(h.str('description', h.str('type')), style: const TextStyle(fontWeight: FontWeight.w500)),
                              Muted([dayLong(h.str('created_at')), if (h.str('reason').isNotEmpty) h.str('reason'), if (h.str('expires_at').isNotEmpty && h.integer('remaining') > 0) 'expires ${dayLong(h.str('expires_at'))}'].join(' · '), size: 12),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${h.integer('points') >= 0 ? '+' : '−'}${number(h.integer('points').abs())}',
                                style: TextStyle(fontWeight: FontWeight.w600, color: h.integer('points') >= 0 ? C.tealDeep : C.bad, fontFeatures: const [FontFeature.tabularFigures()])),
                            if (h['balance_after'] != null) Muted('${number(h['balance_after'] as num?)} left', size: 11),
                          ]),
                        ]),
                      ),
                  ]),
                ]),
        ),
      );
}

// ---------------------------------------------------------------- refer

class ReferScreen extends StatelessWidget {
  const ReferScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Refer a friend'),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/client/rewards/referrals')),
          builder: (context, r, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
            TealHeader(
              radius: 24,
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                const Icon(Icons.group_add_rounded, color: C.gold, size: 38),
                const SizedBox(height: 10),
                Text('Give a friend Lavish,\nget ${number(r['points_per_referral'] as num?)} points', textAlign: TextAlign.center, style: serif(26, color: Colors.white)),
                const SizedBox(height: 6),
                const Text('When your friend joins with your code and finishes their first paid visit, you both get points.', textAlign: TextAlign.center, style: TextStyle(color: C.mint, height: 1.45, fontSize: 13)),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .3))),
                  child: Text(r.str('code'), style: const TextStyle(fontFamily: 'monospace', fontSize: 22, letterSpacing: 3, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: LvButton('Copy code', kind: BtnKind.ghost, icon: Icons.copy_rounded, onTap: () {
                  Clipboard.setData(ClipboardData(text: r.str('code')));
                  toast(context, 'Code copied');
                }),
              ),
              const SizedBox(width: 10),
              Expanded(child: LvButton('Share', icon: Icons.ios_share_rounded, onTap: () => SharePlus.instance.share(ShareParams(text: r.str('share_text', r.str('code')))))),
            ]),
            const SizedBox(height: 8),
            Muted('Up to ${r.integer('max_per_year')} referral rewards a year.', align: TextAlign.center, size: 12),
            const SectionTitle('Your referrals'),
            if (r.list('referrals').isEmpty)
              const Muted('No referrals yet — share your code to get started.')
            else
              LvList(children: [
                for (final f in r.list('referrals'))
                  LvTile(
                    leading: Avatar(name: f.str('name'), size: 36),
                    title: f.str('name'),
                    trailing: Pill(f.str('status') == 'pending' ? 'Joined' : f.str('status')),
                  ),
              ]),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- tier up

class TierUpScreen extends StatelessWidget {
  const TierUpScreen({super.key, required this.tier});
  final Json tier;
  @override
  Widget build(BuildContext context) {
    final (t1, t2) = tierColors(tier.str('key'));
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0, -.4), radius: 1.2, colors: [t1, t2])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .14), border: Border.all(color: C.gold.withValues(alpha: .7), width: 3)),
                child: const Icon(Icons.workspace_premium_rounded, color: C.goldSoft, size: 64),
              ),
              const SizedBox(height: 26),
              Text('YOU’RE NOW', style: TextStyle(color: Colors.white.withValues(alpha: .8), letterSpacing: 4, fontSize: 12)),
              const SizedBox(height: 6),
              Text(tier.str('name'), style: serif(46, color: Colors.white)),
              const SizedBox(height: 18),
              for (final b in (tier['benefits'] as List?) ?? const [])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.check_circle_rounded, color: C.gold, size: 18),
                    const SizedBox(width: 8),
                    Flexible(child: Text(b.toString(), style: const TextStyle(color: Colors.white))),
                  ]),
                ),
              const Spacer(),
              LvButton('Wonderful', kind: BtnKind.gold, onTap: () async {
                try {
                  await api.post('/client/rewards/tier-seen');
                } catch (_) {}
                if (context.mounted) context.pop();
              }),
            ]),
          ),
        ),
      ),
    );
  }
}
