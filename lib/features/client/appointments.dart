import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, this.tab = 'upcoming'});
  final String tab;
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late String tab = widget.tab;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'My appointments'),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: C.gold,
          foregroundColor: C.ink,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onPressed: () => context.push('/book'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Book', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Seg<String>(items: const [('upcoming', 'Upcoming'), ('requests', 'Requests'), ('past', 'Past')], value: tab, onChanged: (v) => setState(() => tab = v)),
          ),
          Expanded(
            child: Loader<List<Json>>(
              key: ValueKey(tab),
              load: () async => listOf(await api.get('/client/appointments', {'tab': tab})),
              builder: (context, list, reload) => list.isEmpty
                  ? ListView(children: [
                      Empty(
                        icon: Icons.event_busy_rounded,
                        title: 'Nothing here yet',
                        text: tab == 'requests' ? 'No requests waiting for approval.' : 'Book a treatment to get started.',
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => AppointmentCard(a: list[i], onReturn: reload),
                    ),
            ),
          ),
        ]),
      );
}

class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.a, this.onReturn});
  final Json a;
  final VoidCallback? onReturn;
  @override
  Widget build(BuildContext context) {
    final pay = a.objOrNull('payment');
    final online = a.flag('is_online');
    return LvCard(
      onTap: () async {
        await context.push('/appointment/${a['id']}');
        onReturn?.call();
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBox(online ? Icons.videocam_rounded : iconFor(a.obj('service').str('icon'))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(online ? 'Online consultation' : a.obj('service').str('name'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
              Pill(a.str('status')),
            ]),
            const SizedBox(height: 4),
            Muted('${a.objOrNull('doctor')?.str('name') ?? 'Doctor to be assigned'}${online ? ' · Video call · ${a.integer('duration_minutes')} min' : ''}', size: 12.5),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, children: [
              _M(Icons.calendar_today_rounded, dayShort(a.str('starts_at'))),
              _M(Icons.schedule_rounded, a.str('time')),
              if (pay != null) _M(Icons.payments_outlined, pay.str('status') == 'paid' ? 'Paid' : pay.str('status') == 'in_review' ? 'Receipt in review' : etb(pay['due_amount'] as num?)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _M extends StatelessWidget {
  const _M(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: C.muted), const SizedBox(width: 4), Text(text, style: const TextStyle(color: C.muted, fontSize: 12.5))]);
}

// ---------------------------------------------------------------- detail

class AppointmentScreen extends StatelessWidget {
  const AppointmentScreen({super.key, required this.id});
  final int id;

  static (IconData, String, String) head(Json a) {
    final online = a.flag('is_online');
    return switch (a.str('status')) {
      'pending' => (Icons.hourglass_top_rounded, 'Waiting for approval', 'Reception will confirm your ${online ? 'session' : 'appointment'} and notify you.'),
      'approved' => (Icons.event_available_rounded, 'Confirmed', online ? 'Your doctor will call you at the booked time.' : 'See you at ${a.obj('branch').str('name', 'the clinic')}. Please arrive 10 minutes early.'),
      'completed' => (Icons.check_circle_rounded, 'Completed', 'Thank you for visiting Lavish.'),
      'declined' => (Icons.event_busy_rounded, 'Not approved', a.str('decline_reason', 'Reception could not confirm this time. Please book another slot.')),
      'cancelled' => (Icons.cancel_rounded, 'Cancelled', 'This booking was cancelled.'),
      _ => (Icons.info_rounded, a.str('status'), ''),
    };
  }

  Future<void> _cancel(BuildContext context, Json a, Future<void> Function() reload) async {
    final ok = await confirm(context,
        title: 'Cancel this booking?',
        body: '${a.obj('service').str('name')} on ${dayShort(a.str('starts_at'))} at ${a.str('time')}.\nAny voucher or gift card used is given back.',
        ok: 'Cancel booking',
        cancel: 'Keep it',
        danger: true);
    if (!ok || !context.mounted) return;
    try {
      await api.post('/client/appointments/${a['id']}/cancel');
      if (context.mounted) toast(context, 'Booking cancelled');
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _review(BuildContext context, Json a, Future<void> Function() reload) async {
    final r = await showModalBottomSheet<(int, String)>(context: context, isScrollControlled: true, builder: (_) => _ReviewSheet(doctor: a.objOrNull('doctor')?.str('name') ?? 'your doctor'));
    if (r == null || !context.mounted) return;
    try {
      await api.post('/client/appointments/${a['id']}/review', {'rating': r.$1, 'comment': r.$2.isEmpty ? null : r.$2});
      if (context.mounted) toast(context, 'Thank you for your review!');
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => dataOf(await api.get('/client/appointments/$id')),
        builder: (context, a, reload) {
          final online = a.flag('is_online');
          final doc = a.objOrNull('doctor');
          final pay = a.objOrNull('payment');
          final paid = pay?.str('status') == 'paid';
          final (icon, title, text) = head(a);
          final (bg, fg) = toneColors(Pill.toneOf(a.str('status')));
          final status = a.str('status');
          final steps = [
            ('Request sent', a.str('created_at'), true),
            ('Confirmed by reception', a.str('approved_at'), status == 'approved' || status == 'completed'),
            ('Paid', pay?.str('paid_at') ?? '', paid),
            (online ? 'Session done' : 'Visit done', a.str('completed_at'), status == 'completed'),
          ];
          return Scaffold(
            appBar: lvAppBar(context, '${online ? 'Online session' : 'Appointment'} #${a['id']}'),
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, color: fg, size: 26),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: serif(20, color: fg)), if (text.isNotEmpty) Text(text, style: TextStyle(color: fg, fontSize: 13, height: 1.4))])),
                ]),
              ),
              const SizedBox(height: 12),
              LvCard(
                child: Column(children: [
                  Row(children: [
                    if (doc != null) Avatar(name: doc.str('name'), hue: doc['hue'] as num?, size: 48) else const IconBox(Icons.auto_awesome_rounded, tone: Tone.gold, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(doc?.str('name') ?? 'Doctor to be assigned', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                        Muted(doc?.str('specialty') ?? 'Reception will choose', size: 12.5),
                      ]),
                    ),
                    if (doc != null && status == 'completed')
                      CircleIconButton(Icons.chat_bubble_outline_rounded, boxed: true, onTap: () async {
                        try {
                          final c = dataOf(await api.post('/client/chats/${doc['id']}'));
                          if (context.mounted) context.push('/chat/${c['id']}', extra: {'title': doc.str('name')});
                        } catch (e) {
                          if (context.mounted) showError(context, e);
                        }
                      }),
                  ]),
                  const SizedBox(height: 12),
                  KVList([
                    KV(online ? 'Session' : 'Treatment', online ? 'Online consultation · ${a.integer('duration_minutes')} min' : a.obj('service').str('name')),
                    KV('Date', DateFormat('EEEE, d MMMM').format(parseDate(a.str('starts_at')) ?? DateTime.now())),
                    KV('Time', '${a.str('time')} · ${a.integer('duration_minutes')} min'),
                    KV(online ? 'Where' : 'Branch', online ? 'Video call' : a.obj('branch').str('name', '—')),
                    if (a.str('note').isNotEmpty) KV('Your note', a.str('note')),
                  ]),
                ]),
              ),
              if (online && status == 'approved') ...[
                const SizedBox(height: 12),
                LvCard(
                  color: a.str('video_link').isNotEmpty ? C.mint : Colors.white,
                  borderColor: a.str('video_link').isNotEmpty ? C.mint : C.line,
                  child: Row(children: [
                    IconBox(a.str('video_link').isNotEmpty ? Icons.videocam_rounded : Icons.lock_outline_rounded, tone: a.str('video_link').isNotEmpty ? Tone.teal : Tone.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.str('video_link').isNotEmpty ? 'Your video link is ready' : 'Video link unlocks after payment', style: const TextStyle(fontWeight: FontWeight.w500)),
                        Muted(a.str('video_link').isNotEmpty ? 'Find a quiet, well-lit spot and join on time.' : 'Pay to secure your slot — reception can’t hold it unpaid.', size: 12.5),
                      ]),
                    ),
                    if (a.str('video_link').isNotEmpty)
                      LvButton('Join', small: true, expand: false, onTap: () => launchUrl(Uri.parse(a.str('video_link')), mode: LaunchMode.externalApplication)),
                  ]),
                ),
              ],
              if (status == 'pending' && a['change_request'] is Map) ...[
                const SizedBox(height: 12),
                ChangeRequestCard(a: a, onChanged: reload),
              ],
              if (!['declined', 'cancelled'].contains(status)) ...[
                const SizedBox(height: 12),
                LvCard(child: Steps(steps: [for (final (t, at, done) in steps) StepItem(t, done ? (at.isEmpty ? '' : when(at)) : '', done)])),
              ],
              if (pay != null) ...[
                SectionTitle('Payment', top: 20),
                LvCard(
                  child: Column(children: [
                    Row(children: [const Expanded(child: Muted('Status', size: 14)), Pill(pay.str('status') == 'in_review' ? 'In review' : pay.str('status'))]),
                    const SizedBox(height: 4),
                    KVList([
                      KV('Price', etb(pay['amount'] as num?)),
                      if (pay.integer('discount_amount') > 0) KV('Discount', '−${etb(pay['discount_amount'] as num?)}', valueColor: C.tealDeep),
                      if (pay.integer('gift_card_amount') > 0) KV('Gift card', '−${etb(pay['gift_card_amount'] as num?)}', valueColor: C.tealDeep),
                      if (paid && pay.objOrNull('method') != null) KV('Method', pay.enumLabel('method')),
                      KV(paid ? 'Paid' : 'To pay', etb(paid ? (pay.integer('amount') - pay.integer('discount_amount') - pay.integer('gift_card_amount')) : pay['due_amount'] as num?), total: true),
                    ]),
                    if (['unpaid', 'failed', 'in_review', 'pending'].contains(pay.str('status')) && !['declined', 'cancelled'].contains(status)) ...[
                      const SizedBox(height: 10),
                      LvButton(pay.str('status') == 'in_review' ? 'View receipt status' : 'Pay now', icon: Icons.payments_outlined, onTap: () async {
                        await context.push('/pay/${pay['id']}');
                        reload();
                      }),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 20),
              if (a.flag('can_review')) LvButton('Rate your visit', icon: Icons.star_outline_rounded, kind: BtnKind.gold, onTap: () => _review(context, a, reload)),
              if (a.flag('can_cancel')) ...[const SizedBox(height: 10), LvButton('Cancel booking', kind: BtnKind.danger, onTap: () => _cancel(context, a, reload))],
            ]),
          );
        },
      );
}

class StepItem {
  const StepItem(this.title, this.sub, this.done);
  final String title;
  final String sub;
  final bool done;
}

/// Vertical progress steps (`.steps`).
class Steps extends StatelessWidget {
  const Steps({super.key, required this.steps});
  final List<StepItem> steps;
  @override
  Widget build(BuildContext context) {
    final now = steps.indexWhere((s) => !s.done);
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: steps[i].done ? C.dark : Colors.white,
                  border: Border.all(color: steps[i].done ? C.dark : (i == now ? C.gold : C.line), width: 2),
                  boxShadow: i == now ? [const BoxShadow(color: C.goldSoft, spreadRadius: 4)] : null,
                ),
                child: steps[i].done ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
              ),
              if (i < steps.length - 1) Expanded(child: Container(width: 2, color: steps[i].done ? C.dark : C.line)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: i < steps.length - 1 ? 18 : 0, top: 2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(steps[i].title, style: TextStyle(fontWeight: FontWeight.w500, color: steps[i].done || i == now ? C.ink : C.muted)),
                  if (steps[i].sub.isNotEmpty) Muted(steps[i].sub, size: 12),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.doctor});
  final String doctor;
  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int rating = 5;
  final comment = TextEditingController();
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('How was your visit?', style: serif(24)),
          Muted('Your review helps ${widget.doctor} and other clients.', align: TextAlign.center),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                iconSize: 38,
                onPressed: () => setState(() => rating = i),
                icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: C.gold),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(hintText: 'Tell us more (optional)')),
          const SizedBox(height: 16),
          LvButton('Send review', onTap: () => Navigator.pop(context, (rating, comment.text.trim()))),
        ]),
      );
}


/// Reception asked the client to change a pending booking (the doctor is busy): suggested times / doctors, or pick any
/// free time. POST /client/appointments/{id}/change.
class ChangeRequestCard extends StatefulWidget {
  const ChangeRequestCard({super.key, required this.a, required this.onChanged});
  final Json a;
  final Future<void> Function() onChanged;
  @override
  State<ChangeRequestCard> createState() => _ChangeRequestCardState();
}

class _ChangeRequestCardState extends State<ChangeRequestCard> {
  bool busy = false;

  Json get cr => Map<String, dynamic>.from(widget.a['change_request'] as Map);

  static String _day(String ymd) {
    final d = DateTime.tryParse(ymd);
    if (d == null) return ymd;
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${wd[d.weekday - 1]} ${d.day} ${mo[d.month - 1]}';
  }

  Future<void> _change(Map<String, dynamic> body, String what) async {
    final ok = await confirm(context, title: 'Change your booking?', body: '$what\nReception will confirm it and let you know.', ok: 'Change');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      await api.post('/client/appointments/${widget.a['id']}/change', body);
      if (mounted) toast(context, 'Booking changed — waiting for confirmation');
      await widget.onChanged();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickTime() async {
    final a = widget.a;
    final picked = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _TimePicker(serviceId: a.obj('service')['id'] as int?, doctorId: a.objOrNull('doctor')?['id'] as int?, branchId: a.objOrNull('branch')?['id'] as int?),
    );
    if (picked != null && mounted) await _change({'date': picked.$1, 'time': picked.$2}, 'New time: ${_day(picked.$1)} at ${picked.$2}');
  }

  @override
  Widget build(BuildContext context) {
    final kind = cr.str('kind');
    final times = cr.list('times');
    final doctors = cr.list('doctors');
    final doctorName = widget.a.objOrNull('doctor')?.str('name') ?? 'Your doctor';
    final ask = switch (kind) { 'time' => 'Choose another time.', 'doctor' => 'Choose another doctor.', _ => 'Choose another time or another doctor.' };
    return LvCard(
      color: const Color(0xFFFDF6EA),
      borderColor: const Color(0xFFF0DCB5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.event_repeat_rounded, color: Color(0xFF8A5A12)),
          SizedBox(width: 8),
          Expanded(child: Text('Please change your booking', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF8A5A12)))),
        ]),
        const SizedBox(height: 6),
        Text('$doctorName isn’t available at ${widget.a.str('time')} on ${_day(widget.a.str('date'))}. $ask', style: const TextStyle(fontSize: 13.5, height: 1.4)),
        if (cr.str('message').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('“${cr.str('message')}”', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic))),
        if (times.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Muted('Free times', size: 12),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in times)
              ActionChip(
                label: Text('${_day(t.str('date'))} · ${t.str('time')}'),
                onPressed: busy ? null : () => _change({'date': t.str('date'), 'time': t.str('time')}, 'New time: ${_day(t.str('date'))} at ${t.str('time')}'),
              ),
          ]),
        ],
        if (doctors.isNotEmpty) ...[
          const SizedBox(height: 12),
          Muted('Doctors free at ${widget.a.str('time')}', size: 12),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in doctors)
              ActionChip(
                avatar: const Icon(Icons.person_outline_rounded, size: 18),
                label: Text(d.str('name')),
                onPressed: busy ? null : () => _change({'doctor_id': d['id']}, 'New doctor: ${d.str('name')} (same time)'),
              ),
          ]),
        ],
        if (kind != 'doctor') ...[
          const SizedBox(height: 12),
          LvButton('Pick another time', icon: Icons.schedule_rounded, kind: BtnKind.ghost, busy: busy, onTap: _pickTime),
        ],
      ]),
    );
  }
}

/// Bottom sheet: pick a date and one of the free times (GET /catalog/availability).
class _TimePicker extends StatefulWidget {
  const _TimePicker({required this.serviceId, this.doctorId, this.branchId});
  final int? serviceId;
  final int? doctorId;
  final int? branchId;
  @override
  State<_TimePicker> createState() => _TimePickerState();
}

class _TimePickerState extends State<_TimePicker> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  List<Json>? slots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => slots = null);
    try {
      final r = dataOf(await api.get('/catalog/availability', {
        'service_id': widget.serviceId,
        'date': ymd(date),
        'doctor_id': widget.doctorId,
        'branch_id': widget.doctorId == null ? widget.branchId : null,
      }));
      if (mounted) setState(() => slots = r.list('slots'));
    } catch (_) {
      if (mounted) setState(() => slots = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final free = (slots ?? const <Json>[]).where((x) => x['available'] == true).toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pick another time', style: serif(22)),
          const SizedBox(height: 10),
          LvTile(
            icon: Icons.calendar_month_outlined,
            title: dayLong(date.toIso8601String()),
            subtitle: 'Tap to choose another day',
            onTap: () async {
              final now = DateTime.now();
              final d = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 60)), initialDate: date);
              if (d != null) {
                date = d;
                _load();
              }
            },
          ),
          const SizedBox(height: 12),
          if (slots == null)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: C.dark)))
          else if (free.isEmpty)
            const Muted('No free times this day — try another day.')
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sl in free) ActionChip(label: Text(sl.str('time')), onPressed: () => Navigator.pop(context, (ymd(date), sl.str('time')))),
            ]),
        ]),
      ),
    );
  }
}
