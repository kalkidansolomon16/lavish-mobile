import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart' hide Barcode;

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/ui.dart';

const designs = <String, (Color, Color)>{
  'classic': (Color(0xFF0A7379), Color(0xFF06484C)),
  'gold': (Color(0xFFE3C8B6), Color(0xFFA37A62)),
  'botanical': (Color(0xFF5F8F73), Color(0xFF2F5A45)),
  'birthday': (Color(0xFFD98A9A), Color(0xFF9C4F63)),
  'thank_you': (Color(0xFF3A3A3A), Color(0xFF161616)),
};

/// The gift card artwork (`.gcard`).
class GiftCardArt extends StatelessWidget {
  const GiftCardArt({super.key, required this.design, required this.value, required this.bottomLeft, this.bottomRight = '', this.small = false});
  final String design;
  final String value;
  final String bottomLeft;
  final String bottomRight;
  final bool small;
  @override
  Widget build(BuildContext context) {
    final (a, b) = designs[design] ?? designs['classic']!;
    return AspectRatio(
      aspectRatio: 1.6,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.symmetric(horizontal: small ? 11 : 18, vertical: small ? 9 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(small ? 12 : 18),
          gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: small ? null : [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 18), spreadRadius: -18)],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            right: small ? -40 : -60,
            bottom: small ? -70 : -100,
            child: Container(width: small ? 100 : 170, height: small ? 100 : 170, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .22)))),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Image.asset('assets/img/logo-white.png', width: small ? 44 : 76),
            Text(value, style: serif(small ? 16 : 28, color: Colors.white, height: 1.05), maxLines: 2, overflow: TextOverflow.ellipsis),
            DefaultTextStyle(
              style: TextStyle(color: Colors.white.withValues(alpha: .92), fontSize: small ? 10 : 12, letterSpacing: 1),
              child: Row(children: [Expanded(child: Text(bottomLeft, overflow: TextOverflow.ellipsis)), Text(bottomRight)]),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Friendly status words for a card.
String cardStatus(Json c) => switch (c.str('status')) {
      'pending_payment' when c.str('payment_status') == 'in_review' => 'Receipt being checked',
      'active' => 'Active',
      'awaiting_activation' => 'Waiting for Lavish to activate',
      'pending_payment' => 'Not paid yet',
      'redeemed' => 'Fully used',
      'expired' => 'Expired',
      'void' => 'Cancelled',
      final s => s.replaceAll('_', ' '),
    };

String cardValue(Json c) => c.str('type') == 'service' ? c.obj('service').str('name', c.str('label')) : etb(c['balance'] as num?);

// ---------------------------------------------------------------- list

class GiftCardsScreen extends StatefulWidget {
  const GiftCardsScreen({super.key});
  @override
  State<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends State<GiftCardsScreen> {
  String tab = 'received';
  final key = GlobalKey<LoaderState<Json>>();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Gift cards', actions: [
          CircleIconButton(Icons.qr_code_scanner_rounded, onTap: () async {
            await context.push('/gift-cards/add');
            key.currentState?.reload();
          }),
        ]),
        body: Loader<Json>(
          key: key,
          load: () async => dataOf(await api.get('/client/gift-cards')),
          builder: (context, d, reload) {
            final list = d.list(tab);
            return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              LvCard(
                color: C.dark,
                borderColor: C.dark,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Label('Gift card balance', color: C.mint),
                      Text(etb(d['total_balance'] as num?), style: serif(28, color: Colors.white)),
                      const Text('Use it when you book or pay — in one go or over several visits.', style: TextStyle(color: C.mint, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: LvButton('Buy a gift card', icon: Icons.card_giftcard_rounded, kind: BtnKind.gold, onTap: () async {
                  await context.push('/gift-cards/buy');
                  reload();
                })),
                const SizedBox(width: 10),
                Expanded(child: LvButton('Add a card', icon: Icons.add_card_rounded, kind: BtnKind.ghost, onTap: () async {
                  await context.push('/gift-cards/add');
                  reload();
                })),
              ]),
              const SizedBox(height: 18),
              Seg<String>(items: const [('received', 'My cards'), ('sent', 'Sent')], value: tab, onChanged: (v) => setState(() => tab = v)),
              const SizedBox(height: 14),
              if (list.isEmpty)
                Empty(
                  icon: Icons.card_giftcard_rounded,
                  title: tab == 'received' ? 'No gift cards yet' : 'You haven’t sent any',
                  text: tab == 'received' ? 'Got a printed card or a code by SMS? Add it here.' : 'Send a Lavish gift card to someone special.',
                )
              else
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      onTap: () => context.push('/gift-card/${c['id']}'),
                      borderRadius: BorderRadius.circular(18),
                      child: Opacity(
                        opacity: c.str('status') == 'active' ? 1 : .55,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          GiftCardArt(design: c.str('design'), value: cardValue(c), bottomLeft: c.str('masked_code'), bottomRight: c.str('status') == 'active' ? 'Valid to ${monthYear(c.str('expires_at'))}' : cardStatus(c)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(child: Muted(tab == 'sent' ? 'To ${c.obj('recipient').str('name', '—')}' : (c.str('from').isNotEmpty ? 'From ${c.str('from')}' : c.str('label')), size: 12.5)),
                            if (c.integer('initial_value') > 0 && c.str('type') != 'service') Muted('${etb(c['balance'] as num?)} of ${etb(c['initial_value'] as num?)}', size: 12.5),
                          ]),
                        ]),
                      ),
                    ),
                  ),
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- detail

class GiftCardScreen extends StatelessWidget {
  const GiftCardScreen({super.key, required this.id});
  final int id;
  static const _ledger = {'issue': 'Card issued', 'redeem': 'Spent', 'restore': 'Returned (booking cancelled)', 'void': 'Cancelled', 'reissue': 'Reissued', 'expire': 'Expired', 'adjust': 'Adjusted'};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Gift card'),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/client/gift-cards/$id')),
          builder: (context, c, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
            GiftCardArt(design: c.str('design'), value: cardValue(c), bottomLeft: c.str('masked_code'), bottomRight: c.str('expires_at').isEmpty ? cardStatus(c) : 'Valid to ${monthYear(c.str('expires_at'))}'),
            if (c.str('status') == 'awaiting_activation') ...[
              const SizedBox(height: 14),
              Banner2(tone: Tone.gold, icon: Icons.hourglass_top_rounded, text: Text(c['mine'] == 'sent'
                  ? 'Paid — thank you! Lavish is checking the card and will activate it. ${c.obj('recipient').str('name', 'The recipient')} then gets it by ${c.obj('recipient').str('email').isNotEmpty ? 'email' : 'SMS'} with the dates it can be used.'
                  : 'This card is paid and waiting for Lavish to activate it.')),
            ],
            if (c.str('status') == 'pending_payment' && c.str('payment_status') == 'in_review') ...[
              const SizedBox(height: 14),
              Banner2(tone: Tone.gold, icon: Icons.hourglass_top_rounded, text: const Text('We received your payment receipt. Lavish is checking it, then activates the card and sends it to the recipient.')),
              const SizedBox(height: 8),
              LvButton('View payment', kind: BtnKind.ghost, icon: Icons.receipt_long_outlined, onTap: () => context.push('/pay/${c['payment_id']}')),
            ] else if (c.str('status') == 'pending_payment' && c['payment_id'] != null) ...[
              const SizedBox(height: 14),
              LvButton('Pay for this card', icon: Icons.payments_outlined, onTap: () => context.push('/pay/${c['payment_id']}')),
            ],
            if (c.str('code').isNotEmpty && ['active', 'awaiting_activation'].contains(c.str('status'))) ...[
              const SizedBox(height: 14),
              LvCard(
                child: Column(children: [
                  Muted(c.str('status') == 'active' ? 'Show this at the Lavish front desk' : 'The card’s QR code (works once it is activated)', size: 12.5),
                  const SizedBox(height: 10),
                  BarcodeWidget(barcode: Barcode.qrCode(), data: c.str('code').replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase(), width: 170, height: 170, drawText: false),
                  const SizedBox(height: 8),
                  Text(c.str('code'), style: const TextStyle(fontFamily: 'monospace', letterSpacing: 2, fontSize: 16, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            if (c.str('message').isNotEmpty) ...[
              const SizedBox(height: 14),
              LvCard(color: C.goldSoft, borderColor: const Color(0xFFEAD8CC), child: Text('“${c.str('message')}”${c.str('from').isNotEmpty ? '\n— ${c.str('from')}' : ''}', style: serif(17, weight: FontWeight.w500, color: const Color(0xFF7A5440)))),
            ],
            const SizedBox(height: 14),
            LvCard(
              child: KVList([
                KV('Status', cardStatus(c)),
                KV('Balance', c.str('type') == 'service' ? c.obj('service').str('name') : '${etb(c['balance'] as num?)} of ${etb(c['initial_value'] as num?)}'),
                if (c.integer('used') > 0) KV('Used so far', etb(c['used'] as num?)),
                if (c.str('activated_at').isNotEmpty) KV('Valid', '${dayLong(c.str('activated_at'))} – ${dayLong(c.str('expires_at'))}')
                else if (c.str('expires_at').isNotEmpty) KV('Valid until', dayLong(c.str('expires_at')))
                else const KV('Valid', 'From activation'),
                if (c['mine'] == 'sent') KV('Sent to', [c.obj('recipient').str('name', '—'), c.obj('recipient').str('email'), c.obj('recipient').str('phone')].where((x) => x.isNotEmpty).join(' · ')),
              ]),
            ),
            const SizedBox(height: 12),
            if (c['mine'] == 'received' && c.str('status') == 'active' && c.integer('balance') > 0) ...[
              LvCard(
                color: const Color(0xFFF2F8F7),
                borderColor: C.mint,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.phone_iphone_rounded, color: C.tealDeep),
                    SizedBox(width: 8),
                    Text('Use it online', style: TextStyle(fontWeight: FontWeight.w600, color: C.tealDeep)),
                  ]),
                  const SizedBox(height: 6),
                  Text(c.str('type') == 'service'
                      ? 'Book ${c.obj('service').str('name', 'your treatment')} in the app and choose this card on the booking summary — it covers the treatment.'
                      : 'Choose this card when you book a treatment, or on any bill under Payments (treatments and shop orders). It pays as much as its balance covers; you pay the rest.',
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: LvButton('Book', small: true, icon: Icons.calendar_month_rounded, onTap: () => context.push('/book'))),
                    if (c.str('type') != 'service') ...[
                      const SizedBox(width: 8),
                      Expanded(child: LvButton('Shop', small: true, kind: BtnKind.ghost, icon: Icons.shopping_bag_outlined, onTap: () => context.go('/shop'))),
                      const SizedBox(width: 8),
                      Expanded(child: LvButton('Pay a bill', small: true, kind: BtnKind.ghost, icon: Icons.receipt_long_rounded, onTap: () => context.push('/payments'))),
                    ],
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            const Banner2(icon: Icons.info_outline_rounded, text: Text('At the clinic, show the QR code (or the printed card) at the front desk — reception scans it and uses it for your treatment.')),
            if (c.list('ledger').isNotEmpty) ...[
              const SectionTitle('History'),
              LvList(children: [
                for (final l in c.list('ledger'))
                  LvTile(
                    title: _ledger[l.str('type')] ?? l.str('type'),
                    subtitle: '${when(l.str('created_at'))}${l.str('reason').isNotEmpty ? ' · ${l.str('reason')}' : ''}',
                    trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${l.integer('amount') >= 0 ? '+' : '−'}${etb(l.integer('amount').abs())}',
                          style: TextStyle(fontWeight: FontWeight.w600, color: l.integer('amount') >= 0 ? C.tealDeep : C.bad)),
                      Muted('${etb(l['balance_after'] as num?)} left', size: 11),
                    ]),
                  ),
              ]),
            ],
          ]),
        ),
      );
}

// ---------------------------------------------------------------- buy

class GiftBuyScreen extends StatefulWidget {
  const GiftBuyScreen({super.key});
  @override
  State<GiftBuyScreen> createState() => _GiftBuyScreenState();
}

class _GiftBuyScreenState extends State<GiftBuyScreen> {
  Json? opts;
  String type = 'monetary';
  int amount = 2500;
  int? serviceId;
  String design = 'classic';
  final name = TextEditingController();
  final phone = PhoneController();
  final email = TextEditingController();
  final message = TextEditingController();
  final custom = TextEditingController();
  DateTime? deliverAt;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    api.get('/client/gift-cards/options').then((r) {
      if (!mounted) return;
      setState(() {
        opts = dataOf(r);
        final a = (opts!['amounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
        if (a.isNotEmpty) amount = a.length > 1 ? a[1] : a.first;
        serviceId = opts!.list('services').firstOrNull?['id'] as int?;
      });
    }).catchError((e) {
      if (mounted) showError(context, e);
    });
  }

  int get value => type == 'service' ? opts!.list('services').where((s) => s['id'] == serviceId).firstOrNull?.integer('price') ?? 0 : amount;

  Future<void> _buy() async {
    if (name.text.trim().isEmpty) return toast(context, 'Who is it for? Enter their name', error: true);
    final mail = email.text.trim();
    final hasPhone = phone.text.trim().isNotEmpty;
    if (mail.isEmpty && !hasPhone) return toast(context, 'Enter their email or phone — we send the card there', error: true);
    if (mail.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(mail)) return toast(context, 'Check the email address', error: true);
    if (hasPhone && !phone.looksValid) return toast(context, 'Check their phone number', error: true);
    final to = [if (mail.isNotEmpty) mail, if (hasPhone) phone.text.trim()].join(' · ');
    final ok = await confirm(context,
        title: 'Buy a ${etb(value)} gift card?',
        body: 'For ${name.text.trim()} · $to\n\nAfter you pay, Lavish checks and activates the card, then sends it to them${mail.isNotEmpty ? ' by email' : ' by SMS'}${deliverAt == null ? '' : ' on ${dayLong(deliverAt!.toIso8601String())}'} with the dates it can be used.',
        ok: 'Continue to pay');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final r = await api.post('/client/gift-cards', {
        'type': type,
        if (type == 'monetary') 'amount': amount,
        if (type == 'service') 'service_id': serviceId,
        'design': design,
        'message': message.text.trim().isEmpty ? null : message.text.trim(),
        'recipient_name': name.text.trim(),
        if (hasPhone) 'recipient_phone': phone.full,
        if (mail.isNotEmpty) 'recipient_email': mail,
        'delivery': mail.isNotEmpty ? 'email' : 'sms',
        'deliver_at': deliverAt == null ? null : ymd(deliverAt!),
      });
      final pay = r is Map && r['payment'] is Map ? Map<String, dynamic>.from(r['payment']) : null;
      if (!mounted) return;
      if (pay != null) {
        context.pushReplacement('/pay/${pay['id']}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (opts == null) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator(color: C.dark)));
    final amounts = (opts!['amounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [1000, 2500, 5000, 10000];
    final services = opts!.list('services');
    return Scaffold(
      appBar: lvAppBar(context, 'Buy a gift card'),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        GiftCardArt(design: design, value: type == 'service' ? services.where((s) => s['id'] == serviceId).firstOrNull?.str('name') ?? 'Treatment' : etb(amount), bottomLeft: 'For ${name.text.isEmpty ? '…' : name.text}', bottomRight: 'LAVISH'),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final d in designs.entries)
              GestureDetector(
                onTap: () => setState(() => design = d.key),
                child: Container(
                  width: 58,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(colors: [d.value.$1, d.value.$2]),
                    border: Border.all(color: design == d.key ? C.ink : Colors.transparent, width: 2),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        if (services.isNotEmpty) Seg<String>(items: const [('monetary', 'An amount'), ('service', 'A treatment')], value: type, onChanged: (v) => setState(() => type = v)),
        const SizedBox(height: 14),
        if (type == 'monetary') ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in amounts)
              ChoiceChip(
                label: Text(etb(a)),
                selected: amount == a && custom.text.isEmpty,
                onSelected: (_) => setState(() {
                  amount = a;
                  custom.clear();
                }),
                selectedColor: C.dark,
                labelStyle: TextStyle(color: amount == a && custom.text.isEmpty ? Colors.white : C.ink),
                backgroundColor: Colors.white,
                side: BorderSide(color: amount == a && custom.text.isEmpty ? C.dark : C.line),
                shape: const StadiumBorder(),
                showCheckmark: false,
              ),
          ]),
          const SizedBox(height: 10),
          Field(
            label: 'Or another amount (ETB ${opts!.integer('min_amount', 100)} or more)',
            controller: custom,
            keyboard: TextInputType.number,
            icon: Icons.edit_outlined,
            onChanged: (v) => setState(() => amount = int.tryParse(v) ?? amount),
          ),
        ] else
          for (final s in services)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioCard(selected: serviceId == s['id'], title: s.str('name'), trailing: Text(etb(s['price'] as num?), style: serif(15)), onTap: () => setState(() => serviceId = s['id'] as int)),
            ),
        const SectionTitle('Who is it for?', top: 10),
        Field(label: 'Their name', controller: name, icon: Icons.person_outline_rounded, onChanged: (_) => setState(() {})),
        Field(label: 'Their email', controller: email, icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress, hint: 'We email the card when it is activated'),
        PhoneField(label: 'Their phone (optional if you gave an email)', controller: phone),
        Field(label: 'Message (optional)', controller: message, hint: 'e.g. Happy birthday! Treat yourself ♥', maxLines: 2),
        LvTile(
          icon: Icons.schedule_send_outlined,
          title: deliverAt == null ? 'Send as soon as it’s activated' : 'Send on ${dayLong(deliverAt!.toIso8601String())}',
          subtitle: 'Tap to pick a date — e.g. their birthday',
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: deliverAt ?? now);
            setState(() => deliverAt = d);
          },
        ),
        const SizedBox(height: 8),
        for (final t in (opts!['terms'] as List?) ?? const []) Padding(padding: const EdgeInsets.only(bottom: 4), child: Muted('• $t', size: 12)),
      ]),
      bottomNavigationBar: FootBar(child: LvButton('Continue · ${etb(value)}', onTap: value < 100 ? null : _buy, busy: busy)),
    );
  }
}

// ---------------------------------------------------------------- add (type or scan)

class GiftAddScreen extends StatefulWidget {
  const GiftAddScreen({super.key});
  @override
  State<GiftAddScreen> createState() => _GiftAddScreenState();
}

class _GiftAddScreenState extends State<GiftAddScreen> {
  final code = TextEditingController();
  Json? preview;
  bool busy = false;

  bool get canScan => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> _check() async {
    if (code.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 10) return toast(context, 'Enter the full number from the card', error: true);
    setState(() => busy = true);
    try {
      final p = dataOf(await api.post('/client/gift-cards/check', {'code': code.text}));
      setState(() => preview = p);
    } catch (e) {
      if (mounted) showError(context, e);
      setState(() => preview = null);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _claim() async {
    setState(() => busy = true);
    try {
      await api.post('/client/gift-cards/claim', {'code': code.text});
      if (!mounted) return;
      toast(context, 'Gift card added to your account');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _scan() async {
    final v = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScanPage()));
    if (v == null || !mounted) return;
    code.text = v;
    _check();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Add a gift card', subtitle: 'Printed card, SMS code or a card from a friend'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          if (canScan) ...[
            InkWell(
              onTap: _scan,
              borderRadius: BorderRadius.circular(20),
              child: TealHeader(
                radius: 20,
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Scan the card', style: serif(20, color: Colors.white)),
                      const Text('Point your camera at the barcode on the back', style: TextStyle(color: C.mint, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Muted('or type the number')),
            const SizedBox(height: 12),
          ],
          Field(
            label: 'Card number',
            controller: code,
            icon: Icons.credit_card_rounded,
            hint: 'XXXX-XXXX-XXXX-XXXX',
            onSubmitted: (_) => _check(),
            onChanged: (_) => setState(() => preview = null),
          ),
          if (preview == null)
            LvButton('Check card', onTap: _check, busy: busy)
          else ...[
            LvCard(
              child: Column(children: [
                Row(children: [
                  const IconBox(Icons.card_giftcard_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(preview!.str('label'), style: const TextStyle(fontWeight: FontWeight.w500)), Muted(preview!.str('masked_code'), size: 12.5)])),
                  Pill(preview!.str('status')),
                ]),
                const SizedBox(height: 8),
                KVList([KV('Balance', etb(preview!['balance'] as num?), total: true), KV('Valid until', dayLong(preview!.str('expires_at')))]),
              ]),
            ),
            const SizedBox(height: 12),
            LvButton('Add to my account', onTap: preview!.str('status') == 'active' ? _claim : null, busy: busy),
          ],
          const SizedBox(height: 16),
          const Banner2(text: Text('A printed card works once it has been paid for at the Lavish front desk. Keep the card safe — anyone with the number can use it.')),
        ]),
      );
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();
  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool done = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('Scan gift card', style: serif(22, color: Colors.white))),
        body: Stack(children: [
          MobileScanner(
            onDetect: (capture) {
              if (done) return;
              final v = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
              if (v == null || v.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 10) return;
              done = true;
              Navigator.pop(context, v);
            },
          ),
          Center(
            child: Container(
              width: 290,
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: C.gold, width: 3), borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 60, child: Text('Line up the barcode inside the frame', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))),
        ]),
      );
}
