import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/reminders.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

/// "My reminders": today's doses to tick off, and every medicine with its reminder switch.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  bool loading = true;

  @override
  void initState() {
    super.initState();
    reminders.sync().whenComplete(() {
      if (mounted) setState(() => loading = false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Medicine reminders', subtitle: 'From your doctor’s prescriptions'),
        body: ListenableBuilder(
          listenable: reminders,
          builder: (context, _) {
            if (loading && reminders.items.isEmpty) return const Center(child: CircularProgressIndicator(color: C.dark));
            final today = reminders.dosesOn(DateTime.now());
            final done = today.where((d) => reminders.taken.contains(d.key)).length;
            final current = reminders.items.where((i) => i.obj('reminder')['active'] == true).toList();
            final finished = reminders.items.where((i) => i.obj('reminder')['active'] != true).toList();
            return RefreshIndicator(
              color: C.dark,
              onRefresh: reminders.sync,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
                if (!reminders.supported)
                  const Banner2(tone: Tone.grey, text: Text('Reminders ring on the Lavish phone app (Android or iPhone).'))
                else if (reminders.allowed == false && current.isNotEmpty)
                  Banner2(
                    tone: Tone.warn,
                    icon: Icons.notifications_off_outlined,
                    text: const Text('Notifications are off, so your reminders can’t ring. Tap to turn them on.'),
                    onTap: () => reminders.askPermission(),
                  ),
                if (reminders.items.isEmpty)
                  const Empty(
                    icon: Icons.alarm_rounded,
                    title: 'No reminders yet',
                    text: 'When your doctor adds times to a prescription — for example every morning at 8:00 for two weeks — your phone reminds you here.',
                  )
                else ...[
                  if (today.isNotEmpty) ...[
                    SectionTitle('Today · ${DateFormat('EEE d MMM').format(DateTime.now())}', top: 10, action: '$done of ${today.length} taken'),
                    LvList(children: [for (final d in today) _DoseTile(d: d)]),
                  ],
                  if (current.isNotEmpty) ...[
                    const SectionTitle('Your medicines'),
                    for (final i in current) _MedicineCard(item: i),
                  ],
                  if (finished.isNotEmpty) ...[
                    const SectionTitle('Finished'),
                    for (final i in finished) _MedicineCard(item: i, finished: true),
                  ],
                  const SizedBox(height: 10),
                  Muted('Reminders keep ringing until the last day your doctor set — even without internet. Open the app at least every ${MedReminders.windowDays} days to keep long courses going.', size: 12),
                ],
              ]),
            );
          },
        ),
      );
}

class _DoseTile extends StatelessWidget {
  const _DoseTile({required this.d});
  final Dose d;
  @override
  Widget build(BuildContext context) {
    final taken = reminders.taken.contains(d.key);
    final late = !taken && d.at.isBefore(DateTime.now());
    return LvTile(
      leading: Container(
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: taken ? C.okSoft : (late ? C.warnSoft : C.mint), borderRadius: BorderRadius.circular(12)),
        child: Text(d.time, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w600, color: taken ? C.ok : (late ? C.warnInk : C.tealDeep))),
      ),
      title: d.name,
      subtitle: taken ? 'Taken' : (late ? 'Not marked yet' : (d.instructions.isEmpty ? 'Coming up' : d.instructions)),
      trailing: Checkbox(
        value: taken,
        activeColor: C.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        onChanged: (v) => reminders.setTaken(d, v ?? false),
      ),
      onTap: () => reminders.setTaken(d, !taken),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.item, this.finished = false});
  final Json item;
  final bool finished;
  @override
  Widget build(BuildContext context) {
    final r = item.obj('reminder');
    final on = !reminders.off.contains(item['id']);
    return LvCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => context.push('/prescription/${item['prescription_id']}'),
      child: Row(children: [
        IconBox(Icons.medication_rounded, tone: finished ? Tone.grey : Tone.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.str('name'), style: const TextStyle(fontWeight: FontWeight.w500)),
            Muted('⏰ ${(r['times'] as List? ?? []).join(' · ')}', size: 12.5),
            Muted(
              [
                r.str('ends_on').isEmpty ? 'No end date' : (finished ? 'Ended ${dayLong(r.str('ends_on'))}' : 'Until ${dayLong(r.str('ends_on'))}'),
                if (item.str('doctor').isNotEmpty) item.str('doctor'),
              ].join(' · '),
              size: 12,
            ),
          ]),
        ),
        if (!finished)
          Switch(
            value: on,
            activeThumbColor: C.dark,
            onChanged: (v) async {
              if (!v && !await confirm(context, title: 'Stop reminders for ${item.str('name')}?', body: 'You can turn them back on any time.', ok: 'Stop reminders', danger: true)) return;
              await reminders.setOn(item['id'] as int, v);
            },
          ),
      ]),
    );
  }
}

/// Small card for Home: today's progress, opens the reminders screen.
class TodayMedicinesCard extends StatelessWidget {
  const TodayMedicinesCard({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: reminders,
        builder: (context, _) {
          final today = reminders.dosesOn(DateTime.now());
          if (today.isEmpty) return const SizedBox.shrink();
          final done = today.where((d) => reminders.taken.contains(d.key)).length;
          final next = today.where((d) => !reminders.taken.contains(d.key) && d.at.isAfter(DateTime.now())).firstOrNull;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: LvCard(
              onTap: () => context.push('/reminders'),
              child: Row(children: [
                const IconBox(Icons.alarm_rounded, tone: Tone.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Today’s medicines · $done of ${today.length} taken', style: const TextStyle(fontWeight: FontWeight.w500)),
                    Muted(next == null ? (done == today.length ? 'All done for today ✓' : 'Tap to mark what you took') : 'Next: ${next.name} at ${next.time}', size: 12.5),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C3C0)),
              ]),
            ),
          );
        },
      );
}
