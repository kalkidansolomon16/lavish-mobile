import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../client/care.dart' show Bubble, Composer;

/// Client: doctors who treated me (unlocked) or approved my booking (locked until the first treatment).
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  Future<void> _open(BuildContext context, Json row, Future<void> Function() reload) async {
    final d = row.obj('doctor');
    if (row.flag('locked')) return toast(context, 'Chat with ${d.str('name')} unlocks after your first treatment with them.');
    try {
      var id = row['conversation_id'];
      id ??= dataOf(await api.post('/client/chats/${d['id']}'))['id'];
      if (context.mounted) await context.push('/chat/$id', extra: {'title': d.str('name'), 'subtitle': d.str('specialty')});
      await reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Chat'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/client/chats')),
          builder: (context, rows, reload) => rows.isEmpty
              ? ListView(children: [
                  Empty(
                    icon: Icons.forum_outlined,
                    title: 'Chat with your doctor',
                    text: 'After your first treatment you can message your doctor here — ask questions or send a photo of how your skin is healing.',
                    action: 'Book a treatment',
                    onAction: () => context.push('/book'),
                  ),
                ])
              : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
                  LvList(children: [
                    for (final r in rows)
                      LvTile(
                        leading: Avatar(name: r.obj('doctor').str('name'), hue: r.obj('doctor')['hue'] as num?, url: r.obj('doctor').str('photo_url'), size: 48),
                        title: r.obj('doctor').str('name'),
                        subtitle: r.flag('locked')
                            ? 'Unlocks after your first treatment'
                            : r.objOrNull('last_message') == null
                                ? r.obj('doctor').str('specialty')
                                : '${r.obj('last_message').flag('mine') ? 'You: ' : ''}${r.obj('last_message').str('body')}',
                        trailing: r.flag('locked')
                            ? const Icon(Icons.lock_outline_rounded, color: C.muted, size: 20)
                            : Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                                Muted(ago(r.objOrNull('last_message')?.str('created_at')), size: 11.5),
                                if (r.integer('unread') > 0) ...[const SizedBox(height: 4), CountBubble(r.integer('unread'))],
                              ]),
                        onTap: () => _open(context, r, reload),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  const Banner2(text: Text('Your doctor replies during working hours. For anything urgent, call the clinic.')),
                ]),
        ),
      );
}

/// Student: chats with my teachers (one per enrolment).
class TeacherChatsScreen extends StatelessWidget {
  const TeacherChatsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Teacher'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/conversations', {'type': 'student_teacher'})),
          builder: (context, rows, reload) => rows.isEmpty
              ? ListView(children: const [Empty(icon: Icons.forum_outlined, title: 'No chats yet', text: 'When you are enrolled, you can ask your teacher questions here.')])
              : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
                  LvList(children: [
                    for (final c in rows)
                      LvTile(
                        leading: const IconBox(Icons.school_rounded, size: 48),
                        title: c.str('title'),
                        subtitle: c.objOrNull('last_message') == null ? (c.str('about').isEmpty ? 'Ask your teacher a question' : c.str('about')) : '${c.obj('last_message').flag('mine') ? 'You: ' : ''}${c.obj('last_message').str('body')}',
                        trailing: c.integer('unread') > 0 ? CountBubble(c.integer('unread')) : Muted(ago(c.objOrNull('last_message')?.str('created_at')), size: 11.5),
                        onTap: () async {
                          await context.push('/chat/${c['id']}', extra: {'title': c.str('title'), 'subtitle': c.str('about')});
                          reload();
                        },
                      ),
                  ]),
                ]),
        ),
      );
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.id, this.title = 'Chat', this.subtitle});
  final int id;
  final String title;
  final String? subtitle;
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final msgs = <Json>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  bool loading = true;
  bool sending = false;
  bool hasMore = true;
  bool locked = false;
  Object? error;
  String title = '';

  @override
  void initState() {
    super.initState();
    title = widget.title;
    _first();
    timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
    scroll.addListener(() {
      if (scroll.position.pixels >= scroll.position.maxScrollExtent - 80) _older();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _first() async {
    try {
      final c = dataOf(await api.get('/conversations/${widget.id}'));
      locked = c.flag('locked');
      if (title == 'Chat') title = c.str('title', 'Chat');
      final r = listOf(await api.get('/conversations/${widget.id}/messages'));
      setState(() {
        msgs
          ..clear()
          ..addAll(r);
        hasMore = r.length >= 30;
        loading = false;
      });
      api.post('/conversations/${widget.id}/read').catchError((_) => null);
    } catch (e) {
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  Future<void> _poll() async {
    if (loading || msgs.isEmpty && error != null) return;
    try {
      final after = msgs.isEmpty ? null : msgs.first['id'];
      final r = listOf(await api.get('/conversations/${widget.id}/messages', {'after_id': after}));
      final fresh = r.where((m) => !msgs.any((x) => x['id'] == m['id'])).toList();
      if (fresh.isNotEmpty && mounted) {
        setState(() => msgs.insertAll(0, fresh));
        api.post('/conversations/${widget.id}/read').catchError((_) => null);
      }
    } catch (_) {}
  }

  bool _loadingOlder = false;
  Future<void> _older() async {
    if (!hasMore || _loadingOlder || msgs.isEmpty) return;
    _loadingOlder = true;
    try {
      final r = listOf(await api.get('/conversations/${widget.id}/messages', {'before_id': msgs.last['id']}));
      setState(() {
        msgs.addAll(r);
        hasMore = r.length >= 30;
      });
    } catch (_) {
    } finally {
      _loadingOlder = false;
    }
  }

  Future<void> _send({List<UploadFile> files = const []}) async {
    final body = input.text.trim();
    if (body.isEmpty && files.isEmpty) return;
    setState(() => sending = true);
    try {
      final m = dataOf(files.isEmpty
          ? await api.post('/conversations/${widget.id}/messages', {'body': body})
          : await api.upload('/conversations/${widget.id}/messages', {'body': body.isEmpty ? null : body}, {'files[]': files}));
      input.clear();
      setState(() => msgs.insert(0, m));
      if (scroll.hasClients) scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _attach() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
    if (x == null) return;
    final b = await x.readAsBytes();
    if (b.length > 8 * 1024 * 1024) {
      if (mounted) toast(context, 'That photo is too large', error: true);
      return;
    }
    await _send(files: [UploadFile(b, x.name.contains('.') ? x.name : '${x.name}.jpg')]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          shape: const Border(bottom: BorderSide(color: C.line)),
          titleSpacing: 0,
          title: Row(children: [
            Avatar(name: title, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: serif(19), overflow: TextOverflow.ellipsis),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty) Text(widget.subtitle!, style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
          ]),
        ),
        body: Column(children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: C.dark))
                : error != null
                    ? ErrorBox(error: error!, onRetry: () {
                        setState(() {
                          loading = true;
                          error = null;
                        });
                        _first();
                      })
                    : msgs.isEmpty
                        ? const Center(child: Muted('No messages yet — say hello 👋'))
                        : ListView.builder(
                            controller: scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                            itemCount: msgs.length,
                            itemBuilder: (_, i) {
                              final m = msgs[i];
                              final mine = m.flag('mine');
                              final att = m.list('attachments');
                              final newDay = i == msgs.length - 1 || dayLong(msgs[i + 1].str('created_at')) != dayLong(m.str('created_at'));
                              return Column(children: [
                                if (newDay)
                                  Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                                    decoration: BoxDecoration(color: C.seg, borderRadius: BorderRadius.circular(99)),
                                    child: Text(dayShort(m.str('created_at')), style: const TextStyle(fontSize: 11, color: C.muted)),
                                  ),
                                Align(
                                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Bubble(
                                    mine: mine,
                                    text: m.str('body'),
                                    time: ago(m.str('created_at')).contains(':') ? ago(m.str('created_at')) : when(m.str('created_at')),
                                    images: [for (final a in att) if (a.flag('is_image')) a.str('url')],
                                    files: [for (final a in att) if (!a.flag('is_image')) (a.str('name'), a.str('url'))],
                                  ),
                                ),
                              ]);
                            },
                          ),
          ),
          if (locked)
            const Padding(padding: EdgeInsets.all(16), child: Banner2(tone: Tone.grey, icon: Icons.lock_outline_rounded, text: Text('This chat is read-only.')))
          else
            Composer(controller: input, onSend: () => _send(), sending: sending, onAttach: _attach),
        ]),
      );
}
