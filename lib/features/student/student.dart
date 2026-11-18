import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import '../client/home.dart' show LvTabBar;

class StudentShell extends StatelessWidget {
  const StudentShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  static const tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.school_outlined, Icons.school_rounded, 'Courses'),
    (Icons.forum_outlined, Icons.forum_rounded, 'Teacher'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: LvTabBar(index: shell.currentIndex, tabs: tabs, onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex)),
      );
}

Color courseColor(Json c, [double l = .38]) => HSLColor.fromAHSL(1, ((c['hue'] as num?) ?? 185).toDouble(), .42, l).toColor();

// ---------------------------------------------------------------- home

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  Future<Map<String, dynamic>> _load() async {
    final r = await Future.wait([api.get('/student/enrollments'), api.get('/student/sessions').catchError((_) => null)]);
    session.refreshUnread();
    return {'enrollments': listOf(r[0]), 'sessions': r[1] == null ? <Json>[] : listOf(r[1])};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StatusBarScrim(child: Loader<Map<String, dynamic>>(
          load: _load,
          builder: (context, d, _) {
            final list = d['enrollments'] as List<Json>;
            final active = list.where((e) => e.str('status') == 'active').firstOrNull ?? list.firstOrNull;
            final sessions = d['sessions'] as List<Json>;
            return ListView(padding: EdgeInsets.zero, children: [
              TealHeader(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 14, 20, 26),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Avatar(name: session.name, size: 46, hue: 38, url: session.user?['avatar_url']?.toString()),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${greeting()},', style: const TextStyle(color: C.mint, fontSize: 13)),
                        Text(firstName(session.name), style: serif(28, color: Colors.white, height: 1)),
                      ]),
                    ),
                    ListenableBuilder(listenable: session, builder: (_, _) => CircleIconButton(Icons.notifications_outlined, onDark: true, dot: session.unread > 0, onTap: () => context.push('/notifications'))),
                  ]),
                  if (active != null) ...[
                    const SizedBox(height: 22),
                    InkWell(
                      onTap: () => context.push('/my-course/${active['id']}'),
                      child: Row(children: [
                        _Ring(progress: active.integer('progress')),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('LAVISH ACADEMY', style: TextStyle(color: C.gold, fontSize: 11, letterSpacing: 1.6)),
                            Text(active.obj('course').str('title'), style: serif(22, color: Colors.white)),
                            Text(active['current_week'] != null ? 'Week ${active['current_week']} of ${active.obj('course').integer('weeks')}' : active.str('status'), style: const TextStyle(color: C.mint, fontSize: 13)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ]),
                    ),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (list.isEmpty) ...[
                    const SizedBox(height: 20),
                    Empty(icon: Icons.school_outlined, title: 'No courses yet', text: 'When the academy enrols you, your course appears here.', action: 'Browse courses', onAction: () => context.go('/s-courses')),
                  ],
                  if (active != null && !active.flag('paid')) ...[
                    const SizedBox(height: 16),
                    const Banner2(tone: Tone.warn, icon: Icons.payments_outlined, text: Text('Your course fee is not marked as paid yet. Please settle it with the academy.')),
                  ],
                  if (sessions.isNotEmpty) ...[
                    const SectionTitle('Upcoming classes'),
                    LvList(children: [
                      for (final s in sessions.take(5))
                        LvTile(
                          icon: Icons.event_rounded,
                          title: s.str('title'),
                          subtitle: '${dayShort(s.str('starts_at'))} · ${s.str('time')}${s.str('room').isNotEmpty ? ' · ${s.str('room')}' : ''}${s.objOrNull('teacher') != null ? ' · ${s.obj('teacher').str('name')}' : ''}',
                        ),
                    ]),
                  ],
                  if (list.isNotEmpty) ...[
                    const SectionTitle('My courses'),
                    for (final e in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LvCard(
                          onTap: () => context.push('/my-course/${e['id']}'),
                          child: Row(children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(gradient: LinearGradient(colors: [courseColor(e.obj('course'), .45), courseColor(e.obj('course'), .28)]), borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.school_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.obj('course').str('title'), style: const TextStyle(fontWeight: FontWeight.w500)),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(99),
                                  child: LinearProgressIndicator(value: e.integer('progress') / 100, minHeight: 6, backgroundColor: C.mint, color: C.gold),
                                ),
                                const SizedBox(height: 4),
                                Muted('${e.integer('progress')}% · ${e.str('status')}', size: 12),
                              ]),
                            ),
                            if (e.objOrNull('certificate') != null) ...[const SizedBox(width: 8), const Icon(Icons.workspace_premium_rounded, color: C.gold)],
                          ]),
                        ),
                      ),
                  ],
                ]),
              ),
            ]);
          },
        )),
      );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress});
  final int progress;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        height: 76,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 76, height: 76, child: CircularProgressIndicator(value: progress / 100, strokeWidth: 7, color: C.gold, backgroundColor: Colors.white.withValues(alpha: .18))),
          Text('$progress%', style: serif(20, color: Colors.white)),
        ]),
      );
}

// ---------------------------------------------------------------- catalogue

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Courses'),
        body: Loader<List<Json>>(
          load: () async => listOf(await api.get('/catalog/courses')),
          builder: (context, list, _) => list.isEmpty
              ? ListView(children: const [Empty(icon: Icons.school_outlined, title: 'No courses listed', text: 'Ask the academy about upcoming intakes.')])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (_, i) => _CourseCard(c: list[i]),
                ),
        ),
      );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.c});
  final Json c;
  @override
  Widget build(BuildContext context) => LvCard(
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/course/${c['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            alignment: Alignment.bottomLeft,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: [courseColor(c, .45), courseColor(c, .26)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: Text(c.str('title'), style: serif(22, color: Colors.white))),
              const Icon(Icons.school_rounded, color: Colors.white70, size: 30),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Row(children: [
              Expanded(child: Muted([c.str('level'), '${c.integer('weeks')} weeks', c.str('mode'), if (c.objOrNull('branch') != null && !c.str('mode').contains(c.obj('branch').str('name'))) c.obj('branch').str('name')].where((x) => x.isNotEmpty).join(' · '), size: 12.5)),
              Text(etb(c['price'] as num?), style: serif(17)),
            ]),
          ),
        ]),
      );
}

class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/catalog/courses/$id')),
          builder: (context, c, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
            Container(
              height: 150,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [courseColor(c, .45), courseColor(c, .26)])),
              child: Text(c.str('title'), style: serif(28, color: Colors.white)),
            ),
            const SizedBox(height: 14),
            LvCard(
              child: KVList([
                KV('Length', '${c.integer('weeks')} weeks'),
                if (c.str('level').isNotEmpty) KV('Level', c.str('level')),
                if (c.str('mode').isNotEmpty) KV('Format', c.str('mode')),
                if (c.str('starts_on').isNotEmpty) KV('Starts', dayLong(c.str('starts_on'))),
                KV('Fee', etb(c['price'] as num?), total: true),
              ]),
            ),
            if (c.str('about').isNotEmpty) ...[const SectionTitle('About'), Text(c.str('about'), style: const TextStyle(height: 1.55, color: Color(0xFF4A4A4A)))],
            if (c.str('requirement').isNotEmpty) ...[const SizedBox(height: 12), Banner2(icon: Icons.checklist_rounded, text: Text('Requirement: ${c.str('requirement')}'))],
            if (c.list('teachers').isNotEmpty) ...[
              const SectionTitle('Teachers'),
              LvList(children: [for (final t in c.list('teachers')) LvTile(leading: Avatar(name: t.str('name'), size: 38), title: t.str('name'), subtitle: t.str('specialty'))]),
            ],
            if ((c['module_titles'] as List?)?.isNotEmpty == true) ...[
              const SectionTitle('What you’ll learn'),
              LvCard(
                child: Column(children: [
                  for (final (i, t) in (c['module_titles'] as List).indexed)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(10)), child: Text('${i + 1}', style: const TextStyle(color: C.muted, fontWeight: FontWeight.w500))),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t.toString())),
                      ]),
                    ),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            Banner2(
              tone: Tone.gold,
              icon: Icons.info_outline_rounded,
              text: Text('To enrol, visit the academy or call ${session.config['academy_phone'] ?? 'the academy'}. They create your student login.'),
              onTap: session.config['academy_phone'] == null ? null : () => launchUrl(Uri.parse('tel:${session.config['academy_phone'].toString().replaceAll(' ', '')}')),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- my course

class MyCourseScreen extends StatelessWidget {
  const MyCourseScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => Loader<Json>(
        load: () async => dataOf(await api.get('/student/enrollments/$id')),
        builder: (context, d, reload) {
          final e = d.obj('enrollment');
          final course = e.obj('course');
          final modules = d.list('modules');
          return Scaffold(
            appBar: lvAppBar(context, course.str('title'), subtitle: '${e.integer('progress')}% complete'),
            body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 30), children: [
              ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: e.integer('progress') / 100, minHeight: 8, backgroundColor: C.mint, color: C.gold)),
              const SizedBox(height: 14),
              Row(children: [
                if (e['conversation_id'] != null)
                  Expanded(child: LvButton('Ask my teacher', icon: Icons.forum_outlined, kind: BtnKind.soft, onTap: () => context.push('/chat/${e['conversation_id']}', extra: {'title': 'Teacher', 'subtitle': course.str('title')}))),
                if (e.objOrNull('certificate') != null) ...[
                  const SizedBox(width: 10),
                  Expanded(child: LvButton('Certificate', icon: Icons.workspace_premium_rounded, kind: BtnKind.gold, onTap: () => context.push('/certificate/${e['id']}'))),
                ],
              ]),
              if (d.list('upcoming_sessions').isNotEmpty) ...[
                const SectionTitle('Next classes'),
                LvList(children: [
                  for (final s in d.list('upcoming_sessions').take(3))
                    LvTile(icon: Icons.event_rounded, title: s.str('title'), subtitle: '${dayShort(s.str('starts_at'))} · ${s.str('time')}${s.str('room').isNotEmpty ? ' · ${s.str('room')}' : ''}'),
                ]),
              ],
              const SectionTitle('Modules'),
              if (modules.isEmpty)
                const Muted('Your teacher publishes each week’s lesson here.')
              else
                LvCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Column(children: [
                    for (final (i, m) in modules.indexed) ...[
                      if (i > 0) const Divider(height: 1, color: C.line),
                      _ModuleRow(m: m, onTap: () async {
                        await context.push('/lesson/${m['id']}');
                        reload();
                      }),
                    ],
                  ]),
                ),
            ]),
          );
        },
      );
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.m, required this.onTap});
  final Json m;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final sub = m.objOrNull('submission');
    final done = sub?.str('status') == 'graded';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? C.dark : (sub != null ? C.gold : C.bg), borderRadius: BorderRadius.circular(10)),
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
                : Text('${m.integer('week')}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: sub != null ? C.ink : C.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.str('title'), style: const TextStyle(fontWeight: FontWeight.w500)),
              Muted(
                [
                  'Week ${m.integer('week')}',
                  if (m.objOrNull('video') != null) '${m.obj('video').integer('minutes')} min video',
                  if (m.objOrNull('exercise') != null) sub == null ? 'exercise to do' : 'exercise ${sub.str('status')}${sub.str('grade').isNotEmpty ? ' · ${sub.str('grade')}' : ''}',
                ].join(' · '),
                size: 12,
              ),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFC4C3C0)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- lesson

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.id});
  final int id;
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final key = GlobalKey<LoaderState<Json>>();
  final body = TextEditingController();
  final files = <PlatformFile>[];
  bool busy = false;

  Future<void> _pick() async {
    final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'mp4', 'mov']);
    if (r.isEmpty) return;
    setState(() => files.addAll(r.take(4 - files.length)));
  }

  Future<void> _submit(Json m) async {
    if (body.text.trim().isEmpty && files.isEmpty) return toast(context, 'Write your answer or attach a file', error: true);
    final ok = await confirm(context, title: 'Hand in this exercise?', body: '${m.obj('exercise').str('title')}\nYour teacher is notified.', ok: 'Hand in');
    if (!ok || !mounted) return;
    setState(() => busy = true);
    try {
      final up = <UploadFile>[];
      for (final f in files) {
        final b = await f.readAsBytes();
        if (b.length > 10 * 1024 * 1024) throw ApiException(422, 'too_big', '${f.name} is over 10 MB.');
        up.add(UploadFile(b, f.name));
      }
      await api.upload('/student/modules/${widget.id}/submission', {'body': body.text.trim().isEmpty ? null : body.text.trim()}, {'files[]': up});
      if (!mounted) return;
      toast(context, 'Handed in — your teacher will grade it');
      setState(() {
        files.clear();
        body.clear();
      });
      await key.currentState?.reload();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Loader<Json>(
          key: key,
          load: () async => dataOf(await api.get('/student/modules/${widget.id}')),
          builder: (context, m, _) {
            final v = m.objOrNull('video');
            final ex = m.objOrNull('exercise');
            final sub = m.objOrNull('submission');
            final canSubmit = ex != null && sub?.str('status') != 'graded';
            return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
              Label('Week ${m.integer('week')}'),
              Text(m.str('title'), style: serif(28)),
              const SizedBox(height: 14),
              if (v != null)
                InkWell(
                  onTap: v.str('url').isEmpty ? null : () => launchUrl(Uri.parse(v.str('url')), mode: LaunchMode.externalApplication),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: const RadialGradient(center: Alignment(-.4, -.6), radius: 1.3, colors: [Color(0xFF1B4F52), Color(0xFF0B1F20)])),
                    child: Stack(children: [
                      Center(
                        child: Container(width: 68, height: 68, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), shape: BoxShape.circle), child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40)),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: Row(children: [
                          Expanded(child: Text(v.str('title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                          if (v.integer('minutes') > 0) Text('${v.integer('minutes')} min', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
                )
              else
                const Banner2(tone: Tone.grey, icon: Icons.videocam_off_outlined, text: Text('No video for this week.')),
              if (ex != null) ...[
                const SectionTitle('Exercise'),
                LvCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ex.str('title'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (ex.str('due_on').isNotEmpty) Muted('Due ${dayLong(ex.str('due_on'))}', size: 12.5),
                    if (ex.str('instructions').isNotEmpty) ...[const SizedBox(height: 8), Text(ex.str('instructions'), style: const TextStyle(height: 1.5))],
                  ]),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 12),
                  LvCard(
                    color: sub.str('status') == 'graded' ? C.okSoft : (sub.str('status') == 'returned' ? C.badSoft : C.warnSoft),
                    borderColor: Colors.transparent,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(sub.str('status') == 'graded' ? 'Graded${sub.str('grade').isNotEmpty ? ' · ${sub.str('grade')}' : ''}' : sub.str('status') == 'returned' ? 'Returned for changes' : 'Handed in — waiting for grading', style: const TextStyle(fontWeight: FontWeight.w600))),
                        Muted(dayLong(sub.str('submitted_at')), size: 12),
                      ]),
                      if (sub.str('body').isNotEmpty) ...[const SizedBox(height: 6), Text(sub.str('body'), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.45, color: Color(0xFF4A4A4A)))],
                      if (sub.str('feedback').isNotEmpty) ...[const SizedBox(height: 6), Text('Teacher: ${sub.str('feedback')}', style: const TextStyle(height: 1.45))],
                      if (sub.list('attachments').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        for (final a in sub.list('attachments')) Text('📎 ${a.str('name')}', style: const TextStyle(fontSize: 12.5)),
                      ],
                    ]),
                  ),
                ],
                if (canSubmit) ...[
                  SectionTitle(sub == null ? 'Your answer' : 'Hand in again', top: 20),
                  TextField(controller: body, maxLines: 5, decoration: const InputDecoration(hintText: 'Write your answer, or attach your work below…')),
                  const SizedBox(height: 10),
                  for (final (i, f) in files.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: LvCard(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.attach_file_rounded, size: 18, color: C.dark),
                          const SizedBox(width: 8),
                          Expanded(child: Text(f.name, overflow: TextOverflow.ellipsis)),
                          IconButton(onPressed: () => setState(() => files.removeAt(i)), icon: const Icon(Icons.close_rounded, size: 18)),
                        ]),
                      ),
                    ),
                  if (files.length < 4) LvButton('Attach a file', kind: BtnKind.ghost, icon: Icons.upload_file_rounded, onTap: _pick),
                  const SizedBox(height: 10),
                  const Muted('PDF, Word, photos or a short video · up to 4 files, 10 MB each', size: 12),
                  const SizedBox(height: 14),
                  LvButton('Hand in', icon: Icons.send_rounded, busy: busy, onTap: () => _submit(m)),
                ],
              ],
            ]);
          },
        ),
      );
}

// ---------------------------------------------------------------- certificate

class CertificateScreen extends StatelessWidget {
  const CertificateScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Certificate'),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/student/enrollments/$id/certificate')),
          builder: (context, c, _) => ListView(padding: const EdgeInsets.all(20), children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 22),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: C.dark, width: 6)),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(border: Border.all(color: C.gold, width: 1.5)),
                child: Column(children: [
                  ColorFiltered(colorFilter: const ColorFilter.mode(C.dark, BlendMode.srcIn), child: Image.asset('assets/img/logo-white.png', width: 110)),
                  const SizedBox(height: 10),
                  Text('Certificate of Completion', textAlign: TextAlign.center, style: serif(24, color: C.tealDeep)),
                  const SizedBox(height: 12),
                  const Muted('This certifies that', size: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.gold))),
                    child: Text(c.str('student_name'), style: serif(26)),
                  ),
                  Muted('has completed the ${c.integer('weeks')}-week course', size: 12),
                  const SizedBox(height: 4),
                  Text(c.str('course_title'), textAlign: TextAlign.center, style: serif(19)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(dayLong(c.str('issued_at')), style: serif(14)), const Muted('Date', size: 10.5)])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(c.str('issued_by', 'Lavish Academy'), style: serif(14)), const Muted('Issued by', size: 10.5)])),
                  ]),
                  const SizedBox(height: 10),
                  Muted('No. ${c.str('number')}', size: 11),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            const Banner2(text: Text('Ask the academy for a printed copy with the official stamp.')),
          ]),
        ),
      );
}
