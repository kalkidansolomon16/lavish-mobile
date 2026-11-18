import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Payments'),
        body: Loader<dynamic>(
          load: () => api.get('/client/payments'),
          builder: (context, res, reload) {
            final list = listOf(res);
            final meta = res is Map && res['meta'] is Map ? Map<String, dynamic>.from(res['meta']) : <String, dynamic>{};
            return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              Row(children: [
                Expanded(
                  child: LvCard(
                    color: C.dark,
                    borderColor: C.dark,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Label('Outstanding', color: C.mint),
                      Text(etb(meta['outstanding'] as num?), style: serif(26, color: Colors.white)),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LvCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Label('Paid'), Text(etb(meta['paid'] as num?), style: serif(26))])),
                ),
              ]),
              const SizedBox(height: 12),
              Banner2(
                text: Text(session.onlinePayments
                    ? 'Pay in the app or at reception. Payments taken at reception appear here.'
                    : 'Pay by Telebirr, CBE Birr, bank transfer or at reception, then upload your receipt here. Reception checks it and confirms.'),
              ),
              const SectionTitle('History'),
              if (list.isEmpty)
                const Empty(icon: Icons.receipt_long_rounded, title: 'No payments yet', text: 'Bills for your treatments and orders appear here.')
              else
                LvList(children: [
                  for (final p in list)
                    LvTile(
                      icon: p.str('status') == 'paid' ? Icons.receipt_long_rounded : Icons.pending_outlined,
                      iconTone: p.str('status') == 'paid' ? Tone.teal : Tone.gold,
                      title: p.str('description'),
                      subtitle: '${dayLong(p.str('created_at'))} · ${p.objOrNull('method') != null ? p.enumLabel('method') : p.str('status') == 'in_review' ? 'Receipt in review' : 'Not paid yet'}',
                      trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(etb(p.str('status') == 'paid' ? p['amount'] as num? : p['due_amount'] as num?), style: const TextStyle(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 3),
                        Pill(_payLabel(p)),
                      ]),
                      onTap: () async {
                        await context.push('/pay/${p['id']}');
                        reload();
                      },
                    ),
                ]),
            ]);
          },
        ),
      );
}

String _payLabel(Json p) => switch (p.str('status')) {
      'unpaid' => 'Pay now',
      'in_review' => 'In review',
      'refund_due' => 'Refund due',
      final s => s,
    };

// ---------------------------------------------------------------- pay

class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.id});
  final int id;
  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  final key = GlobalKey<LoaderState<Json>>();
  Future<void> reload() async => key.currentState?.reload();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Payment', subtitle: session.onlinePayments ? 'Secured by Chapa' : 'Pay any way, then upload your receipt'),
        body: Loader<Json>(
          key: key,
          load: () async => dataOf(await api.get('/client/payments/${widget.id}')),
          builder: (context, p, reload) {
            final status = p.str('status');
            final receipt = p.objOrNull('receipt');
            final due = p.integer('due_amount');
            final open = ['unpaid', 'failed', 'pending'].contains(status);
            return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              _AmountCard(p: p),
              const SizedBox(height: 14),
              if (status == 'paid')
                _PaidCard(p: p)
              else if (status == 'in_review')
                Banner2(
                  tone: Tone.warn,
                  icon: Icons.hourglass_top_rounded,
                  text: const Text('We received your receipt. Reception is checking it — you’ll get a notification when it’s confirmed.'),
                )
              else if (receipt?.str('status') == 'rejected')
                Banner2(
                  tone: Tone.bad,
                  icon: Icons.error_outline_rounded,
                  text: Text.rich(TextSpan(children: [
                    const TextSpan(text: 'Your last receipt wasn’t accepted', style: TextStyle(fontWeight: FontWeight.w600)),
                    TextSpan(text: receipt!.str('reject_reason').isEmpty ? '. Please upload a clear photo of the receipt.' : ': ${receipt.str('reject_reason')}'),
                  ])),
                )
              else if (!['unpaid', 'failed', 'pending'].contains(status))
                Banner2(tone: Tone.grey, text: Text('This payment is ${status.replaceAll('_', ' ')}.')),
              if (receipt != null && status != 'paid') ...[const SizedBox(height: 12), _ReceiptCard(r: receipt)],
              if (open && due > 0 && p.integer('gift_card_amount') == 0 && p.integer('discount_amount') == 0) _Credits(p: p, onApplied: reload),
              if ((open || status == 'in_review') && due > 0) ...[
                if (session.onlinePayments) _ChapaPay(p: p, onDone: reload) else _ReceiptForm(p: p, onSent: reload, replacing: status == 'in_review'),
              ],
            ]);
          },
        ),
      );
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.p});
  final Json p;
  @override
  Widget build(BuildContext context) {
    final paid = p.str('status') == 'paid';
    final credits = p.integer('discount_amount') + p.integer('gift_card_amount');
    return LvCard(
      color: C.dark,
      borderColor: C.dark,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Label(paid ? 'Paid' : 'Amount due', color: C.mint),
        const SizedBox(height: 4),
        Text(etb(paid ? p.integer('amount') - credits : p['due_amount'] as num?), style: serif(40, color: Colors.white, height: 1.1)),
        const SizedBox(height: 4),
        Text(p.str('description'), textAlign: TextAlign.center, style: const TextStyle(color: C.mint, fontSize: 12.5)),
        if (credits > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${etb(p['amount'] as num?)} − ${[
              if (p.integer('discount_amount') > 0) 'rewards ${etb(p['discount_amount'] as num?)}',
              if (p.integer('gift_card_amount') > 0) 'gift card ${etb(p['gift_card_amount'] as num?)}',
            ].join(' − ')}', textAlign: TextAlign.center, style: const TextStyle(color: C.mint, fontSize: 12)),
          ),
      ]),
    );
  }
}

class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.p});
  final Json p;
  @override
  Widget build(BuildContext context) => LvCard(
        child: Column(children: [
          const Row(children: [IconBox(Icons.check_circle_rounded, tone: Tone.ok), SizedBox(width: 12), Expanded(child: Text('Payment confirmed', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)))]),
          const SizedBox(height: 8),
          KVList([
            if (p.objOrNull('method') != null) KV('Method', p.enumLabel('method')),
            if (p.str('provider_reference').isNotEmpty) KV('Reference', p.str('provider_reference')),
            if (p.objOrNull('receipt')?.str('reference').isNotEmpty == true) KV('Reference', p.obj('receipt').str('reference')),
            KV('Paid on', when(p.str('paid_at'))),
          ]),
        ]),
      );
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.r});
  final Json r;
  @override
  Widget build(BuildContext context) {
    final f = r.obj('file');
    return LvCard(
      child: Row(children: [
        if (f.flag('is_image') && f.str('url').isNotEmpty)
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(f.str('url'), width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, _, _) => const IconBox(Icons.image_outlined)))
        else
          const IconBox(Icons.picture_as_pdf_rounded, tone: Tone.bad),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r.enumLabel('method')} receipt', style: const TextStyle(fontWeight: FontWeight.w500)),
            Muted([if (r.str('reference').isNotEmpty) 'Ref ${r.str('reference')}', 'sent ${when(r.str('created_at'))}'].join(' · '), size: 12),
          ]),
        ),
        Pill(r.str('status') == 'pending' ? 'Checking' : r.str('status')),
      ]),
    );
  }
}

/// Vouchers and gift cards that can go on this bill (wallet → quote → apply).
class _Credits extends StatefulWidget {
  const _Credits({required this.p, required this.onApplied});
  final Json p;
  final Future<void> Function() onApplied;
  @override
  State<_Credits> createState() => _CreditsState();
}

class _CreditsState extends State<_Credits> {
  List<Json> vouchers = [];
  List<Json> cards = [];
  int? voucherId;
  int? cardId;
  Json? quote;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    api.get('/client/payments/${widget.p['id']}/wallet').then((r) {
      final w = dataOf(r);
      if (mounted) {
        setState(() {
          vouchers = w.list('vouchers').where((v) => v['applies'] == true).toList();
          cards = w.list('gift_cards').where((c) => c['applies'] == true && c.integer('balance') > 0).toList();
        });
      }
    }).catchError((_) {});
  }

  Future<void> _quote() async {
    if (voucherId == null && cardId == null) return setState(() => quote = null);
    try {
      final q = dataOf(await api.post('/client/payments/${widget.p['id']}/quote', {'voucher_id': voucherId, 'gift_card_id': cardId}));
      if (mounted) setState(() => quote = q);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _apply() async {
    final q = quote;
    if (q == null) return;
    final ok = await confirm(context,
        title: 'Use these on this bill?',
        body: [
          if (q.integer('voucher_discount') > 0) 'Voucher: −${etb(q['voucher_discount'] as num?)}',
          if (q.integer('gift_card_amount') > 0) 'Gift card: −${etb(q['gift_card_amount'] as num?)}',
          'Left to pay: ${etb(q['to_pay'] as num?)}',
        ].join('\n'),
        ok: 'Apply');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await api.post('/client/payments/${widget.p['id']}/apply', {'voucher_id': voucherId, 'gift_card_id': cardId});
      if (mounted) toast(context, q.integer('to_pay') == 0 ? 'Paid in full with your rewards!' : 'Applied');
      await widget.onApplied();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (vouchers.isEmpty && cards.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Use rewards or a gift card', top: 22),
      for (final v in vouchers)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RadioCard(
            selected: voucherId == v['id'],
            leading: const IconBox(Icons.redeem_rounded, tone: Tone.gold, small: true),
            title: v.str('name'),
            subtitle: 'Voucher ${v.str('code')}',
            onTap: () {
              setState(() => voucherId = voucherId == v['id'] ? null : v['id'] as int);
              _quote();
            },
          ),
        ),
      for (final c in cards)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RadioCard(
            selected: cardId == c['id'],
            leading: const IconBox(Icons.card_giftcard_rounded, small: true),
            title: c.str('label'),
            subtitle: '${c.str('masked_code')} · ${etb(c['balance'] as num?)} left',
            onTap: () {
              setState(() => cardId = cardId == c['id'] ? null : c['id'] as int);
              _quote();
            },
          ),
        ),
      if (quote != null) ...[
        LvCard(
          child: KVList([
            KV('Bill', etb(quote!['price'] as num? ?? widget.p['amount'] as num?)),
            if (quote!.integer('voucher_discount') > 0) KV('Voucher', '−${etb(quote!['voucher_discount'] as num?)}', valueColor: C.tealDeep),
            if (quote!.integer('gift_card_amount') > 0) KV('Gift card', '−${etb(quote!['gift_card_amount'] as num?)}', valueColor: C.tealDeep),
            KV('Left to pay', etb(quote!['to_pay'] as num?), total: true),
          ]),
        ),
        const SizedBox(height: 10),
        LvButton('Apply to this bill', kind: BtnKind.gold, busy: busy, onTap: _apply),
      ],
    ]);
  }
}

/// Receipt flow (Chapa off): pay by any means, then upload the receipt for reception to check.
class _ReceiptForm extends StatefulWidget {
  const _ReceiptForm({required this.p, required this.onSent, this.replacing = false});
  final Json p;
  final Future<void> Function() onSent;
  final bool replacing;
  @override
  State<_ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends State<_ReceiptForm> {
  late String method;
  final reference = TextEditingController();
  final note = TextEditingController();
  Uint8List? bytes;
  String? fileName;
  bool busy = false;
  bool open = false;

  List<Json> get instructions => (session.config['payment_instructions'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  List<Json> get methods => (session.config['receipt_methods'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((m) => m['value'] != 'card').toList();

  @override
  void initState() {
    super.initState();
    method = instructions.where((i) => i['method'] != 'cash').firstOrNull?['method']?.toString() ?? 'telebirr';
    open = !widget.replacing;
  }

  Future<void> _pick(String from) async {
    Navigator.pop(context);
    try {
      if (from == 'file') {
        final f = (await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'])).firstOrNull;
        if (f == null) return;
        final b = await f.readAsBytes();
        if (b.length > 5 * 1024 * 1024) return _tooBig();
        setState(() {
          bytes = b;
          fileName = f.name;
        });
      } else {
        final x = await ImagePicker().pickImage(source: from == 'camera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
        if (x == null) return;
        final b = await x.readAsBytes();
        if (b.length > 5 * 1024 * 1024) return _tooBig();
        setState(() {
          bytes = b;
          fileName = x.name.contains('.') ? x.name : '${x.name}.jpg';
        });
      }
    } catch (e) {
      if (mounted) toast(context, 'Couldn’t open that file', error: true);
    }
  }

  void _tooBig() => toast(context, 'That file is over 5 MB — take a smaller photo', error: true);

  void _chooseSource() => showModalBottomSheet(
        context: context,
        builder: (c) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add your receipt', style: serif(22)),
            const SizedBox(height: 8),
            ListTile(leading: const IconBox(Icons.photo_camera_outlined, small: true), title: const Text('Take a photo'), onTap: () => _pick('camera')),
            ListTile(leading: const IconBox(Icons.photo_library_outlined, small: true), title: const Text('Choose from gallery'), onTap: () => _pick('gallery')),
            ListTile(leading: const IconBox(Icons.picture_as_pdf_outlined, tone: Tone.bad, small: true), title: const Text('PDF or file (e.g. bank e-receipt)'), onTap: () => _pick('file')),
            const SizedBox(height: 12),
          ]),
        ),
      );

  Future<void> _send() async {
    if (bytes == null) return toast(context, 'Add a photo or PDF of your receipt', error: true);
    if (method != 'cash' && reference.text.trim().isEmpty) {
      final go = await confirm(context, title: 'No transaction number?', body: 'Adding the transaction or reference number helps reception confirm your payment faster.', ok: 'Send anyway', cancel: 'Add it');
      if (!go) return;
    }
    if (!mounted) return;
    final label = methods.where((m) => m['value'] == method).firstOrNull?['label'] ?? method;
    final ok = await confirm(context, title: 'Send this receipt?', body: '$label · ${etb(widget.p['due_amount'] as num?)}\nReception checks it and confirms your payment.', ok: 'Send receipt');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await api.upload('/client/payments/${widget.p['id']}/receipt', {
        'method': method,
        'reference': reference.text.trim().isEmpty ? null : reference.text.trim(),
        'amount': widget.p['due_amount'],
        'note': note.text.trim().isEmpty ? null : note.text.trim(),
      }, {
        'receipt': [UploadFile(bytes!, fileName ?? 'receipt.jpg')],
      });
      if (!mounted) return;
      toast(context, 'Receipt sent — we’ll let you know once it’s confirmed');
      await widget.onSent();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!open) {
      return Padding(padding: const EdgeInsets.only(top: 14), child: LvButton('Upload a different receipt', kind: BtnKind.ghost, onTap: () => setState(() => open = true)));
    }
    final ins = instructions.where((i) => i['method'] != 'cash').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('1 · Pay Lavish', top: 22),
      if (ins.isEmpty)
        const Banner2(text: Text('Ask reception for Lavish’s Telebirr or bank account details, or pay at the front desk.'))
      else
        LvList(children: [
          for (final i in ins)
            LvTile(
              icon: i['method'] == 'telebirr' ? Icons.phone_android_rounded : Icons.account_balance_rounded,
              title: i.str('label'),
              subtitle: i.str('details'),
              trailing: IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy_rounded, size: 19, color: C.dark),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: i.str('details')));
                  toast(context, '${i.str('label')} details copied');
                },
              ),
            ),
        ]),
      const SizedBox(height: 8),
      Muted('Pay exactly ${etb(widget.p['due_amount'] as num?)}. You can also pay at reception — they record it for you.', size: 12.5),
      const SectionTitle('2 · Upload your receipt', top: 22),
      const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('How did you pay?', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in methods)
          ChoiceChip(
            label: Text(m.str('label')),
            selected: method == m['value'],
            onSelected: (_) => setState(() => method = m.str('value')),
            selectedColor: C.dark,
            labelStyle: TextStyle(color: method == m['value'] ? Colors.white : C.ink, fontSize: 13),
            backgroundColor: Colors.white,
            side: BorderSide(color: method == m['value'] ? C.dark : C.line),
            shape: const StadiumBorder(),
            showCheckmark: false,
          ),
      ]),
      const SizedBox(height: 14),
      if (method != 'cash') Field(label: 'Transaction / reference number', controller: reference, icon: Icons.tag_rounded, hint: 'e.g. FT2611AB34 or Telebirr TXN ID'),
      _ReceiptPicker(bytes: bytes, name: fileName, onPick: _chooseSource, onClear: () => setState(() => bytes = null)),
      const SizedBox(height: 14),
      Field(label: 'Note (optional)', controller: note, hint: 'e.g. Paid from my sister’s account'),
      LvButton('Send receipt', icon: Icons.send_rounded, onTap: _send, busy: busy),
    ]);
  }
}

class _ReceiptPicker extends StatelessWidget {
  const _ReceiptPicker({required this.bytes, required this.name, required this.onPick, required this.onClear});
  final Uint8List? bytes;
  final String? name;
  final VoidCallback onPick;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCFCDCA), width: 1.5),
          ),
          child: const Column(children: [
            Icon(Icons.add_a_photo_outlined, size: 30, color: C.dark),
            SizedBox(height: 6),
            Text('Add a photo of the receipt', style: TextStyle(fontWeight: FontWeight.w500)),
            SizedBox(height: 2),
            Muted('Camera, gallery or PDF · up to 5 MB', size: 12),
          ]),
        ),
      );
    }
    final pdf = (name ?? '').toLowerCase().endsWith('.pdf');
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        if (pdf)
          Container(
            height: 90,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(children: [const IconBox(Icons.picture_as_pdf_rounded, tone: Tone.bad), const SizedBox(width: 12), Expanded(child: Text(name ?? 'receipt.pdf', overflow: TextOverflow.ellipsis))]),
          )
        else
          Image.memory(bytes!, height: 200, width: double.infinity, fit: BoxFit.cover),
        Positioned(
          right: 10,
          top: 10,
          child: Row(children: [
            _Chip('Change', onPick),
            const SizedBox(width: 6),
            _Chip('Remove', onClear, danger: true),
          ]),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.onTap, {this.danger = false});
  final String label;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: .94),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text(label, style: TextStyle(fontSize: 12, color: danger ? C.bad : C.ink))),
        ),
      );
}

/// Chapa flow — only when online payments are switched on in the backend.
class _ChapaPay extends StatefulWidget {
  const _ChapaPay({required this.p, required this.onDone});
  final Json p;
  final Future<void> Function() onDone;
  @override
  State<_ChapaPay> createState() => _ChapaPayState();
}

class _ChapaPayState extends State<_ChapaPay> {
  String method = 'telebirr';
  bool busy = false;
  bool started = false;

  Future<void> _pay() async {
    setState(() => busy = true);
    try {
      final p = dataOf(await api.post('/client/payments/${widget.p['id']}/checkout', {'method': method}));
      final url = p.str('checkout_url');
      if (url.isNotEmpty) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      setState(() => started = true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => busy = true);
    try {
      final p = dataOf(await api.post('/client/payments/${widget.p['id']}/verify'));
      if (!mounted) return;
      toast(context, p.str('status') == 'paid' ? 'Payment confirmed' : 'Not confirmed yet — finish paying, then check again', error: p.str('status') != 'paid');
      await widget.onDone();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methods = (session.config['payment_methods'] as List? ?? []).whereType<Map>().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Pay with', top: 22),
      for (final m in methods)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RadioCard(selected: method == m['value'], title: m['label'].toString(), onTap: () => setState(() => method = m['value'].toString())),
        ),
      const SizedBox(height: 8),
      LvButton(started ? 'I’ve paid — check now' : 'Pay ${etb(widget.p['due_amount'] as num?)}', busy: busy, onTap: started ? _verify : _pay),
      if (started) ...[const SizedBox(height: 8), LvButton('Open payment page again', kind: BtnKind.ghost, onTap: _pay)],
    ]);
  }
}
