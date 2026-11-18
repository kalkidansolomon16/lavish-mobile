import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'shop.dart';

// ---------------------------------------------------------------- prescriptions

class PrescriptionsScreen extends StatelessWidget {
  const PrescriptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Prescriptions'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/client/prescriptions')),
          builder: (context, list, _) => list.isEmpty
              ? ListView(children: const [Empty(icon: Icons.medication_outlined, title: 'No prescriptions yet', text: 'Products your doctor recommends after a visit appear here.')])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return LvCard(
                      onTap: () => context.push('/prescription/${p['id']}'),
                      child: Row(children: [
                        const IconBox(Icons.medication_rounded, tone: Tone.gold),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.obj('doctor').str('name', 'Your doctor'), style: const TextStyle(fontWeight: FontWeight.w500)),
                            Muted('${p.list('items').length} item${p.list('items').length == 1 ? '' : 's'} · ${dayLong(p.str('created_at'))}', size: 12.5),
                          ]),
                        ),
                        Pill(p.str('status') == 'sent' ? 'New' : p.str('status'), tone: p.str('status') == 'sent' ? Tone.gold : Tone.ok),
                      ]),
                    );
                  },
                ),
        ),
      );
}

class PrescriptionScreen extends StatelessWidget {
  const PrescriptionScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => dataOf(await api.get('/client/prescriptions/$id')),
        builder: (context, p, _) {
          final items = p.list('items');
          final orderable = items.where((i) => !i.flag('is_custom') && i.obj('product')['in_stock'] == true).toList();
          return Scaffold(
            appBar: lvAppBar(context, 'Prescription', subtitle: '${p.obj('doctor').str('name')} · ${dayLong(p.str('created_at'))}'),
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (items.any((i) => i.objOrNull('reminder') != null)) ...[
                Banner2(
                  tone: Tone.gold,
                  icon: Icons.alarm_rounded,
                  text: const Text('Your doctor set reminders for this prescription. Your phone will remind you at those times.'),
                  trailing: LinkText('Open', size: 13, onTap: () => context.push('/reminders')),
                ),
                const SizedBox(height: 12),
              ],
              if (p.str('note').isNotEmpty) ...[
                LvCard(color: C.goldSoft, borderColor: const Color(0xFFEAD8CC), child: Text(p.str('note'), style: const TextStyle(height: 1.5, color: Color(0xFF6C4B39)))),
                const SizedBox(height: 12),
              ],
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: LvCard(
                    onTap: i.flag('is_custom') ? null : () => context.push('/product/${i.obj('product')['id']}'),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (i.flag('is_custom'))
                        const IconBox(Icons.local_pharmacy_outlined, tone: Tone.grey, size: 56)
                      else
                        SizedBox(width: 56, child: ProductArt(product: i.obj('product'), height: 56, radius: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.flag('is_custom') ? i.str('custom_name') : i.obj('product').str('name'), style: const TextStyle(fontWeight: FontWeight.w500)),
                          Muted(i.flag('is_custom') ? 'From a pharmacy' : '${etb(i.obj('product')['price'] as num?)} · qty ${i.integer('quantity', 1)}', size: 12.5),
                          if (i.str('instructions').isNotEmpty) ...[const SizedBox(height: 6), Text(i.str('instructions'), style: const TextStyle(fontSize: 13, height: 1.4))],
                          if (i.objOrNull('reminder') != null) ...[
                            const SizedBox(height: 6),
                            Pill(
                              '⏰ ${(i.obj('reminder')['times'] as List).join(' · ')}${i.obj('reminder').str('ends_on').isEmpty ? '' : ' · until ${dayShort(i.obj('reminder').str('ends_on'))}'}',
                              tone: i.obj('reminder')['active'] == true ? Tone.gold : Tone.grey,
                            ),
                          ],
                          if (!i.flag('is_custom') && i.obj('product')['in_stock'] != true) ...[const SizedBox(height: 6), const Pill('Out of stock', tone: Tone.grey)],
                        ]),
                      ),
                    ]),
                  ),
                ),
            ]),
            bottomNavigationBar: orderable.isEmpty || p.str('status') == 'ordered'
                ? null
                : FootBar(
                    child: LvButton('Order ${orderable.length} item${orderable.length == 1 ? '' : 's'}', icon: Icons.shopping_bag_outlined, onTap: () {
                      for (final i in orderable) {
                        cart.add(i.obj('product'), i.integer('quantity', 1));
                      }
                      cart.prescriptionId = p['id'] as int;
                      context.push('/cart');
                    }),
                  ),
          );
        },
      );
}

// ---------------------------------------------------------------- complaints

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<LoaderState<List<Json>>>();
    return Scaffold(
      appBar: lvAppBar(context, 'Help & feedback'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.gold,
        foregroundColor: C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () async {
          await context.push('/complaints/new');
          key.currentState?.reload();
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w500)),
      ),
      body: Loader<List<Json>>(
        key: key,
        load: () async => listOf(await api.get('/client/complaints')),
        builder: (context, list, reload) => list.isEmpty
            ? ListView(children: const [Empty(icon: Icons.support_agent_rounded, title: 'How can we help?', text: 'Tell us about a treatment, appointment, order or anything else. Client care replies here.')])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final c = list[i];
                  return LvCard(
                    onTap: () async {
                      await context.push('/complaint/${c['id']}');
                      reload();
                    },
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(c.str('subject'), style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15))),
                        Pill(c.str('status')),
                      ]),
                      const SizedBox(height: 4),
                      Muted('${c.str('reference')} · ${c.str('category')} · ${dayLong(c.str('created_at'))}', size: 12),
                      if (c.str('latest_reply').isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Banner2(icon: Icons.reply_rounded, text: Text(c.str('latest_reply'), maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ],
                    ]),
                  );
                },
              ),
      ),
    );
  }
}

class NewComplaintScreen extends StatefulWidget {
  const NewComplaintScreen({super.key});
  @override
  State<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  static const categories = ['Treatment', 'Appointment', 'Order', 'Staff', 'App', 'Other'];
  String category = 'Treatment';
  String priority = 'medium';
  final subject = TextEditingController();
  final message = TextEditingController();
  final photos = <XFile>[];
  bool busy = false;

  Future<void> _addPhoto() async {
    if (photos.length >= 4) return toast(context, 'Up to 4 photos', error: true);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
    if (x != null) setState(() => photos.add(x));
  }

  Future<void> _send() async {
    if (subject.text.trim().length < 3) return toast(context, 'Add a short subject', error: true);
    if (message.text.trim().length < 10) return toast(context, 'Tell us a little more (at least 10 characters)', error: true);
    final ok = await confirm(context, title: 'Send to client care?', body: '${subject.text.trim()}\nWe usually reply within one working day.', ok: 'Send');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final files = <UploadFile>[];
      for (final p in photos) {
        files.add(UploadFile(await p.readAsBytes(), p.name.contains('.') ? p.name : '${p.name}.jpg'));
      }
      await api.upload('/client/complaints', {'category': category, 'subject': subject.text.trim(), 'message': message.text.trim(), 'priority': priority}, {'photos[]': files});
      if (!mounted) return;
      toast(context, 'Sent — client care will reply here');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'New message', subtitle: 'Client care reads every message'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('What is it about?', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in categories)
              ChoiceChip(
                label: Text(c),
                selected: category == c,
                onSelected: (_) => setState(() => category = c),
                selectedColor: C.dark,
                labelStyle: TextStyle(color: category == c ? Colors.white : C.ink, fontSize: 13),
                backgroundColor: Colors.white,
                side: BorderSide(color: category == c ? C.dark : C.line),
                shape: const StadiumBorder(),
                showCheckmark: false,
              ),
          ]),
          const SizedBox(height: 16),
          Field(label: 'Subject', controller: subject, hint: 'e.g. Redness after my peel'),
          Field(label: 'Message', controller: message, hint: 'Tell us what happened…', maxLines: 5),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('How urgent?', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          Seg<String>(items: const [('low', 'Low'), ('medium', 'Normal'), ('high', 'Urgent')], value: priority, onChanged: (v) => setState(() => priority = v)),
          const SizedBox(height: 16),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Photos (optional)', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          Row(children: [
            for (final (i, p) in photos.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Stack(clipBehavior: Clip.none, children: [
                  FutureBuilder(
                    future: p.readAsBytes(),
                    builder: (_, s) => ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: s.hasData ? Image.memory(s.data!, width: 74, height: 74, fit: BoxFit.cover) : Container(width: 74, height: 74, color: C.goldSoft),
                    ),
                  ),
                  Positioned(
                    right: -6,
                    top: -6,
                    child: InkWell(
                      onTap: () => setState(() => photos.removeAt(i)),
                      child: Container(decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle), padding: const EdgeInsets.all(3), child: const Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                    ),
                  ),
                ]),
              ),
            if (photos.length < 4)
              InkWell(
                onTap: _addPhoto,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFCFCDCA), width: 1.5)),
                  child: const Icon(Icons.add_a_photo_outlined, color: C.muted),
                ),
              ),
          ]),
        ]),
        bottomNavigationBar: FootBar(child: LvButton('Send', icon: Icons.send_rounded, onTap: _send, busy: busy)),
      );
}

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key, required this.id});
  final int id;
  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final key = GlobalKey<LoaderState<Json>>();
  final reply = TextEditingController();
  bool sending = false;

  Future<void> _send() async {
    if (reply.text.trim().isEmpty) return;
    setState(() => sending = true);
    try {
      await api.post('/client/complaints/${widget.id}/messages', {'body': reply.text.trim()});
      reply.clear();
      await key.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _feedback() async {
    int rating = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text('Was this resolved well?', style: serif(22)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++) IconButton(onPressed: () => set(() => rating = i), icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: C.gold, size: 32)),
            ]),
            TextField(controller: comment, maxLines: 2, decoration: const InputDecoration(hintText: 'Anything to add? (optional)')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send'))],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await api.post('/client/complaints/${widget.id}/feedback', {'rating': rating, 'comment': comment.text.trim().isEmpty ? null : comment.text.trim()});
      if (mounted) toast(context, 'Thank you for your feedback');
      await key.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Message', white: true),
        body: Loader<Json>(
          key: key,
          load: () async => dataOf(await api.get('/client/complaints/${widget.id}')),
          builder: (context, c, _) => Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 20), children: [
                LvCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(c.str('subject'), style: serif(20))), Pill(c.str('status'))]),
                    Muted('${c.str('reference')} · ${c.str('category')} · ${when(c.str('created_at'))}', size: 12),
                    const SizedBox(height: 10),
                    Text(c.str('message'), style: const TextStyle(height: 1.5)),
                    if (c.list('attachments').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final a in c.list('attachments'))
                          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(a.str('url'), width: 74, height: 74, fit: BoxFit.cover, errorBuilder: (_, _, _) => const IconBox(Icons.image_outlined))),
                      ]),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                for (final m in c.list('messages'))
                  Align(
                    alignment: m.flag('from_staff') ? Alignment.centerLeft : Alignment.centerRight,
                    child: Bubble(mine: !m.flag('from_staff'), text: m.str('body'), time: '${m.flag('from_staff') ? '${m.str('author')} · ' : ''}${when(m.str('created_at'))}'),
                  ),
                if (c.flag('can_give_feedback')) ...[const SizedBox(height: 12), LvButton('Rate how we handled it', kind: BtnKind.gold, icon: Icons.star_outline_rounded, onTap: _feedback)],
                if (c.objOrNull('feedback') != null) ...[
                  const SizedBox(height: 12),
                  Banner2(tone: Tone.ok, icon: Icons.star_rounded, text: Text('You rated this ${c.obj('feedback').integer('rating')}/5. Thank you!')),
                ],
              ]),
            ),
            Composer(controller: reply, onSend: _send, sending: sending, hint: c.str('status') == 'resolved' ? 'Reply to reopen…' : 'Write a reply…'),
          ]),
        ),
      );
}

/// Chat bubble (`.bubble`).
class Bubble extends StatelessWidget {
  const Bubble({super.key, required this.mine, required this.text, required this.time, this.images = const [], this.files = const []});
  final bool mine;
  final String text;
  final String time;
  final List<String> images;
  final List<(String, String)> files;
  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(images.isNotEmpty && text.isEmpty ? 4 : 0),
        decoration: BoxDecoration(
          color: mine ? C.dark : Colors.white,
          border: Border.all(color: mine ? C.dark : C.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 6),
            bottomRight: Radius.circular(mine ? 6 : 18),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final u in images)
            Padding(
              padding: const EdgeInsets.all(4),
              child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(u, width: 200, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 200, height: 120))),
            ),
          for (final (name, _) in files)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.attach_file_rounded, size: 16, color: mine ? Colors.white : C.dark), const SizedBox(width: 4), Flexible(child: Text(name, style: TextStyle(color: mine ? Colors.white : C.dark, decoration: TextDecoration.underline)))]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (text.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text(text, style: TextStyle(color: mine ? Colors.white : C.ink, fontSize: 14.5, height: 1.4))),
              const SizedBox(height: 3),
              Text(time, style: TextStyle(fontSize: 10.5, color: (mine ? Colors.white : C.ink).withValues(alpha: .6))),
            ]),
          ),
        ]),
      );
}

/// Message composer (`.composer`).
class Composer extends StatelessWidget {
  const Composer({super.key, required this.controller, required this.onSend, this.sending = false, this.hint = 'Write a message…', this.onAttach});
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;
  final String hint;
  final VoidCallback? onAttach;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.paddingOf(context).bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
        child: Row(children: [
          if (onAttach != null) ...[CircleIconButton(Icons.attach_file_rounded, onTap: onAttach), const SizedBox(width: 4)],
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: C.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: C.dark)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: C.dark,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: sending ? null : onSend,
              child: SizedBox(
                width: 46,
                height: 46,
                child: sending ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      );
}
