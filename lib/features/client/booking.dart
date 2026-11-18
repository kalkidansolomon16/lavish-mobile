import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

/// Step 1: clinic or online, treatment, branch, date, time, note.
class BookScreen extends StatefulWidget {
  const BookScreen({super.key, this.doctorId, this.serviceId, this.online = false});
  final int? doctorId;
  final int? serviceId;
  final bool online;
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  Json? doctor;
  List<Json> services = [];
  List<Json> branches = [];
  bool online = false;
  int? serviceId;
  int? branchId;
  late DateTime date;
  String? time;
  List<Json> slots = [];
  bool loadingSlots = false;
  bool ready = false;
  Object? error;
  final note = TextEditingController();

  Json? get onlineService => session.config['online_consultation'] is Map ? Map<String, dynamic>.from(session.config['online_consultation']) : null;
  Json? get service => online ? onlineService : services.where((s) => s['id'] == serviceId).firstOrNull;

  @override
  void initState() {
    super.initState();
    online = widget.online;
    serviceId = widget.serviceId;
    final now = DateTime.now();
    date = DateTime(now.year, now.month, now.day);
    _init();
  }

  Future<void> _init() async {
    try {
      final r = await Future.wait([
        widget.doctorId != null ? api.get('/catalog/doctors/${widget.doctorId}') : Future.value(null),
        api.get('/catalog/services', {'online': 0}),
        api.get('/catalog/branches'),
      ]);
      doctor = r[0] == null ? null : dataOf(r[0]);
      services = doctor != null ? doctor!.list('services').where((s) => !s.flag('is_online')).toList() : listOf(r[1]);
      branches = listOf(r[2]);
      final pref = session.user?['preferred_branch'];
      branchId = (pref is Map ? pref['id'] as int? : null) ?? branches.firstOrNull?['id'] as int?;
      if (serviceId == null || !services.any((s) => s['id'] == serviceId)) serviceId = services.firstOrNull?['id'] as int?;
      setState(() => ready = true);
      _loadSlots();
    } catch (e) {
      setState(() => error = e);
    }
  }

  Future<void> _loadSlots() async {
    final s = service;
    if (s == null) return;
    setState(() {
      loadingSlots = true;
      time = null;
    });
    try {
      final r = dataOf(await api.get('/catalog/availability', {
        'service_id': s['id'],
        'date': ymd(date),
        'doctor_id': doctor?['id'],
        'branch_id': online || doctor != null ? null : branchId,
      }));
      if (!mounted) return;
      setState(() => slots = r.list('slots'));
    } catch (e) {
      if (mounted) setState(() => slots = []);
    } finally {
      if (mounted) setState(() => loadingSlots = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return Scaffold(appBar: AppBar(), body: ErrorBox(error: error!, onRetry: () => setState(() {
          error = null;
          _init();
        })));
    if (!ready) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator(color: C.dark)));

    final horizon = (session.config['booking_horizon_days'] as num?)?.toInt() ?? 60;
    final today = DateTime.now();
    final days = [for (var i = 0; i < horizon.clamp(7, 30); i++) DateTime(today.year, today.month, today.day + i)];
    final free = slots.where((s) => s.flag('available')).length;
    final s = service;

    return Scaffold(
      appBar: lvAppBar(context, online ? 'Book online session' : 'Book appointment',
          subtitle: doctor != null ? doctor!.str('name') : online ? 'Reception will match you with a doctor' : 'Reception will assign a doctor'),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        if (onlineService != null)
          Seg<bool>(
            items: const [(false, 'At the clinic'), (true, 'Online')],
            value: online,
            onChanged: (v) {
              setState(() => online = v);
              _loadSlots();
            },
          ),
        const SizedBox(height: 16),
        if (doctor != null)
          LvCard(
            child: Row(children: [
              Avatar(name: doctor!.str('name'), hue: doctor!['hue'] as num?, size: 44, url: doctor!.str('photo_url')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doctor!.str('name'), style: const TextStyle(fontWeight: FontWeight.w500)),
                  Muted('${doctor!.str('specialty')} · ${online ? 'Video call' : doctor!.obj('branch').str('name')}', size: 12.5),
                ]),
              ),
            ]),
          )
        else
          Banner2(
            tone: Tone.gold,
            icon: Icons.auto_awesome_rounded,
            text: Text('Reception will match you with the best available specialist for your ${online ? 'concern' : 'treatment'} and time.'),
          ),
        if (online && onlineService != null) ...[
          const SectionTitle('Session', top: 20),
          RadioCard(
            selected: true,
            leading: const IconBox(Icons.video_call_rounded),
            title: onlineService!.str('name', 'Online consultation'),
            subtitle: '${onlineService!.integer('duration_minutes', 45)} min · video call',
            trailing: Text(etb(onlineService!['price'] as num?), style: serif(15)),
          ),
          const SizedBox(height: 12),
          const Banner2(text: Text('Talk to a Lavish doctor from home about your skin, hair or a treatment plan. Good light helps — the doctor will look at your skin on camera.')),
        ] else ...[
          const SectionTitle('Treatment', top: 20),
          for (final sv in services)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioCard(
                selected: sv['id'] == serviceId,
                title: sv.str('name'),
                subtitle: '${sv.integer('duration_minutes')} min',
                leading: IconBox(iconFor(sv.str('icon')), small: true),
                trailing: Text(etb(sv['price'] as num?), style: serif(15)),
                onTap: () {
                  setState(() => serviceId = sv['id'] as int);
                  _loadSlots();
                },
              ),
            ),
          if (services.isEmpty) const Muted('No treatments available for booking right now.'),
          if (doctor == null) ...[
            const SectionTitle('Branch', top: 20),
            ChipBarPadded(
              items: [for (final b in branches) (b['id'] as int, b.str('name'))],
              value: branchId,
              onChanged: (v) {
                setState(() => branchId = v);
                _loadSlots();
              },
            ),
          ],
        ],
        SectionTitle('Date', top: 20, action: DateFormat('MMMM yyyy').format(date)),
        SizedBox(
          height: 74,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final d = days[i];
              final on = d == date;
              return Material(
                color: on ? C.dark : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: on ? C.dark : C.line)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() => date = d);
                    _loadSlots();
                  },
                  child: SizedBox(
                    width: 58,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(DateFormat('EEE').format(d).toUpperCase(), style: TextStyle(fontSize: 11, letterSpacing: .5, color: on ? C.mint : C.muted)),
                      Text('${d.day}', style: serif(22, color: on ? Colors.white : C.ink)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        SectionTitle('Time', top: 20, action: loadingSlots ? 'Checking…' : '$free slot${free == 1 ? '' : 's'} free'),
        if (loadingSlots)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: C.dark, strokeWidth: 2)))
        else if (slots.isEmpty || free == 0)
          Banner2(tone: Tone.grey, icon: Icons.event_busy_rounded, text: Text(slots.isEmpty ? 'No times on this day. Try another date.' : 'This day is fully booked. Try another date.'))
        else
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.9,
            children: [
              for (final sl in slots)
                _SlotButton(
                  label: sl.str('time'),
                  available: sl.flag('available'),
                  selected: time == sl.str('time'),
                  onTap: () => setState(() => time = sl.str('time')),
                ),
            ],
          ),
        SectionTitle(online ? 'What would you like to discuss?' : 'Notes for the doctor', top: 20, action: 'Optional'),
        TextField(
          controller: note,
          maxLines: 4,
          decoration: InputDecoration(hintText: online ? 'e.g. Acne that keeps coming back, or questions before booking a treatment…' : 'Describe your skin concern, allergies or anything we should know…'),
        ),
      ]),
      bottomNavigationBar: FootBar(
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Muted(online ? 'Price · ${s?.integer('duration_minutes', 45) ?? 45} min' : 'Price', size: 11.5),
            Text(etb(s?['price'] as num?), style: serif(22)),
          ]),
          const SizedBox(width: 14),
          Expanded(
            child: LvButton(
              time == null ? 'Pick a time' : 'Continue',
              onTap: time == null || s == null
                  ? null
                  : () => context.push('/book/review', extra: {
                        'doctor': doctor,
                        'service': s,
                        'online': online,
                        'branch': online || doctor != null ? null : branches.where((b) => b['id'] == branchId).firstOrNull,
                        'date': ymd(date),
                        'time': time,
                        'note': note.text.trim(),
                      }),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({required this.label, required this.available, required this.selected, required this.onTap});
  final String label;
  final bool available;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: selected ? C.dark : (available ? Colors.white : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: selected ? C.dark : (available ? C.line : const Color(0xFFDDDCDA)))),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: available ? onTap : null,
          child: Center(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : (available ? C.ink : const Color(0xFFC1C0BD)),
                  decoration: available ? null : TextDecoration.lineThrough,
                )),
          ),
        ),
      );
}

/// Chips inside a padded list (no horizontal bleed).
class ChipBarPadded<T> extends StatelessWidget {
  const ChipBarPadded({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T? value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (v, l) in items)
          Material(
            color: v == value ? C.dark : Colors.white,
            shape: StadiumBorder(side: BorderSide(color: v == value ? C.dark : C.line)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onChanged(v),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on_outlined, size: 16, color: v == value ? Colors.white : C.muted),
                  const SizedBox(width: 6),
                  Text(l, style: TextStyle(fontSize: 13, color: v == value ? Colors.white : C.ink)),
                ]),
              ),
            ),
          ),
      ]);
}

// ---------------------------------------------------------------- review & confirm

class BookReviewScreen extends StatefulWidget {
  const BookReviewScreen({super.key, required this.f});
  final Map<String, dynamic> f;
  @override
  State<BookReviewScreen> createState() => _BookReviewScreenState();
}

class _BookReviewScreenState extends State<BookReviewScreen> {
  List<Json> vouchers = [];
  List<Json> cards = [];
  int? voucherId;
  int? cardId;
  int? points;
  bool busy = false;

  Json get s => Map<String, dynamic>.from(widget.f['service'] as Map);
  Json? get doctor => widget.f['doctor'] == null ? null : Map<String, dynamic>.from(widget.f['doctor'] as Map);
  bool get online => widget.f['online'] == true;

  @override
  void initState() {
    super.initState();
    Future.wait([
      api.get('/client/rewards/vouchers', {'status': 'issued'}).then(listOf).catchError((_) => <Json>[]),
      api.get('/client/gift-cards').then((r) => dataOf(r).list('received')).catchError((_) => <Json>[]),
      api.get('/client/rewards/estimate', {'service_id': s['id']}).then((r) => dataOf(r).integer('points')).catchError((_) => 0),
    ]).then((r) {
      if (!mounted) return;
      setState(() {
        vouchers = (r[0] as List<Json>).where(_voucherFits).toList();
        cards = (r[1] as List<Json>).where((c) => c.str('status') == 'active' && c.integer('balance') > 0 && (c.str('type') != 'service' || c.obj('service')['id'] == s['id'])).toList();
        points = r[2] as int;
      });
    });
  }

  bool _voucherFits(Json v) => v.str('reward_type') != 'product' && (v.str('reward_type') != 'free_service' || v.obj('service')['id'] == s['id']);

  Future<void> confirmBooking() async {
    final ok = await confirm(context,
        title: 'Send this booking request?',
        body: '${s.str('name')}\n${DateFormat('EEEE d MMMM').format(DateTime.parse(widget.f['date']))} at ${widget.f['time']}\nReception will confirm it and let you know.',
        ok: 'Send request');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final res = await api.post('/client/appointments', {
        'service_id': s['id'],
        'date': widget.f['date'],
        'time': widget.f['time'],
        'doctor_id': doctor?['id'],
        'branch_id': (widget.f['branch'] as Map?)?['id'],
        'note': (widget.f['note'] as String?)?.isEmpty == true ? null : widget.f['note'],
        'voucher_id': voucherId,
        'gift_card_id': cardId,
      });
      final a = dataOf(res);
      final credits = res is Map && res['meta'] is Map ? res['meta']['credits_error'] : null;
      if (!mounted) return;
      if (credits is Map) toast(context, credits['message'].toString(), error: true);
      final pay = a.objOrNull('payment');
      context.go('/success', extra: {
        'icon': Icons.event_available_rounded,
        'title': 'Request sent!',
        'text': 'Reception will confirm your ${online ? 'online session' : 'appointment'} shortly — we’ll notify you. ${online ? 'Pay once it’s confirmed to get your video link.' : 'You can pay now or at the clinic.'}',
        'rows': [
          ['Treatment', s.str('name')],
          ['When', '${dayShort(a.str('starts_at'))} · ${a.str('time')}'],
          [online ? 'Where' : 'Branch', online ? 'Video call' : (a.obj('branch').str('name', doctor?.obj('branch').str('name') ?? '—'))],
          if (pay != null) ['To pay', etb(pay['due_amount'] as num?)],
        ],
        'primary': pay != null && pay.str('status') != 'paid' && (pay['due_amount'] as num? ?? 0) > 0 ? {'label': 'Pay now', 'to': '/pay/${pay['id']}'} : {'label': 'View appointment', 'to': '/appointment/${a['id']}'},
        'secondary': {'label': 'Back to home', 'to': '/home'},
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = s.integer('price');
    final v = vouchers.where((x) => x['id'] == voucherId).firstOrNull;
    final vOff = v == null ? 0 : (v.str('reward_type') == 'free_service' ? price : v.integer('value').clamp(0, price));
    final c = cards.where((x) => x['id'] == cardId).firstOrNull;
    final cOff = c == null ? 0 : (c.str('type') == 'service' ? price - vOff : c.integer('balance').clamp(0, price - vOff));
    final total = price - vOff - cOff;

    return Scaffold(
      appBar: lvAppBar(context, 'Review & confirm', subtitle: 'Step 2 of 2'),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        LvCard(
          child: Column(children: [
            Row(children: [
              if (doctor != null)
                Avatar(name: doctor!.str('name'), hue: doctor!['hue'] as num?, size: 48, url: doctor!.str('photo_url'))
              else
                const IconBox(Icons.auto_awesome_rounded, tone: Tone.gold, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(doctor?.str('name') ?? 'Best available doctor', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  Muted(doctor?.str('specialty') ?? 'Assigned by reception', size: 12.5),
                ]),
              ),
              if (online) const Pill('Online', tone: Tone.teal, icon: Icons.videocam_rounded),
            ]),
            const SizedBox(height: 12),
            KVList([
              KV(online ? 'Session' : 'Treatment', s.str('name')),
              KV('Date', DateFormat('EEEE, d MMMM').format(DateTime.parse(widget.f['date']))),
              KV('Time', '${widget.f['time']} · ${s.integer('duration_minutes')} min'),
              KV(online ? 'Where' : 'Branch', online ? 'Video call in the Lavish app' : ((widget.f['branch'] as Map?)?['name']?.toString() ?? doctor?.obj('branch').str('name') ?? '—')),
              if ((widget.f['note'] as String?)?.isNotEmpty == true) KV('Note', widget.f['note']),
              if (vOff > 0 || cOff > 0) ...[
                KV('Price', etb(price)),
                if (vOff > 0) KV('Voucher', '−${etb(vOff)}', valueColor: C.tealDeep),
                if (cOff > 0) KV('Gift card', '−${etb(cOff)}', valueColor: C.tealDeep),
              ],
              KV('Total', etb(total), total: true),
            ]),
          ]),
        ),
        if (vouchers.isNotEmpty || cards.isNotEmpty) ...[
          const SectionTitle('Use a voucher or a gift card', top: 22),
          for (final x in vouchers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CreditTile(
                icon: Icons.redeem_rounded,
                gold: true,
                title: x.str('name'),
                subtitle: 'Voucher ${x.str('code')} · ${x.str('summary')}',
                on: voucherId == x['id'],
                onTap: () => setState(() => voucherId = voucherId == x['id'] ? null : x['id'] as int),
              ),
            ),
          for (final x in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CreditTile(
                icon: Icons.card_giftcard_rounded,
                title: x.str('label'),
                subtitle: '${x.str('masked_code')} · ${etb(x['balance'] as num?)} left',
                on: cardId == x['id'],
                onTap: () => setState(() => cardId = cardId == x['id'] ? null : x['id'] as int),
              ),
            ),
          const Muted('Applied when your booking is created. Cancelling gives them back.', size: 12),
        ],
        const SizedBox(height: 14),
        if ((points ?? 0) > 0)
          Banner2(tone: Tone.gold, icon: Icons.stars_rounded, text: Text('You’ll earn about ${number(points)} Lavish Rewards points after this visit is completed and paid.')),
        const SizedBox(height: 10),
        Banner2(
          icon: Icons.info_outline_rounded,
          text: Text(online
              ? 'Reception confirms your slot first. Then pay in the app to receive your video link.'
              : 'Reception confirms your request and notifies you. Free to cancel until the appointment starts.'),
        ),
      ]),
      bottomNavigationBar: FootBar(child: LvButton('Confirm booking', onTap: confirmBooking, busy: busy)),
    );
  }

}

class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.icon, required this.title, required this.subtitle, required this.on, required this.onTap, this.gold = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final bool on;
  final VoidCallback onTap;
  final bool gold;
  @override
  Widget build(BuildContext context) => Material(
        color: on ? const Color(0xFFF2F8F7) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: on ? C.dark : C.line, width: 1.5)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              IconBox(icon, tone: gold ? Tone.gold : Tone.teal, small: true),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w500)), Muted(subtitle, size: 12, maxLines: 1)])),
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: on ? C.dark : Colors.white, shape: BoxShape.circle, border: Border.all(color: on ? C.dark : C.line, width: 1.5)),
                child: on ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              ),
            ]),
          ),
        ),
      );
}

// ---------------------------------------------------------------- success

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.s});
  final Map<String, dynamic> s;
  @override
  Widget build(BuildContext context) {
    final rows = (s['rows'] as List?) ?? const [];
    final primary = s['primary'] as Map?;
    final secondary = s['secondary'] as Map?;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 60, 20, 20), children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: C.mint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.mint.withValues(alpha: .5), spreadRadius: 12)]),
              child: Icon(s['icon'] as IconData? ?? Icons.check_circle_rounded, color: C.dark, size: 46),
            ),
          ),
          const SizedBox(height: 30),
          Text(s['title']?.toString() ?? 'Done', textAlign: TextAlign.center, style: serif(32)),
          const SizedBox(height: 8),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Muted(s['text']?.toString() ?? '', align: TextAlign.center, size: 14)),
          const SizedBox(height: 22),
          if (rows.isNotEmpty) LvCard(child: KVList([for (final r in rows) KV(r[0].toString(), r[1].toString())])),
        ]),
      ),
      bottomNavigationBar: FootBar(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (primary != null) LvButton(primary['label'].toString(), onTap: () => context.go(primary['to'].toString())),
          const SizedBox(height: 10),
          LvButton(secondary?['label']?.toString() ?? 'Done', kind: BtnKind.ghost, onTap: () => context.go(secondary?['to']?.toString() ?? session.home)),
        ]),
      ),
    );
  }
}
