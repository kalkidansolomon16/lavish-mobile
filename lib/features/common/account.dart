import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/icons.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

// ---------------------------------------------------------------- notifications

/// Where a notification's `target` opens in the app.
String? routeForTarget(Map? t) {
  if (t == null) return null;
  final id = t['id'];
  return switch (t['screen']) {
    'appointment' => '/appointment/$id',
    'order' => '/order/$id',
    'prescription' => '/prescription/$id',
    'complaint' => '/complaint/$id',
    'product' => '/product/$id',
    'payment' || 'pay' => '/pay/$id',
    'rewards' => '/rewards',
    'points_requests' => '/rewards/requests',
    'reward_catalog' => '/rewards/catalog',
    'vouchers' => '/rewards/vouchers',
    'gift_card' => id == null ? '/gift-cards' : '/gift-card/$id',
    'gift_cards' => '/gift-cards',
    'chat' => '/chats',
    's-chat' => '/chat/$id',
    'lesson' => '/lesson/$id',
    'my-course' => '/my-course/$id',
    'certificate' => '/certificate/$id',
    _ => null,
  };
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final key = GlobalKey<LoaderState<List<Json>>>();
    return Scaffold(
      appBar: lvAppBar(context, 'Notifications', actions: [
        TextButton(
          onPressed: () async {
            await api.post('/notifications/read-all').catchError((_) => null);
            session.refreshUnread();
            key.currentState?.reload();
          },
          child: const Text('Mark all read', style: TextStyle(color: C.dark)),
        ),
      ]),
      body: Loader<List<Json>>(
        key: key,
        load: () async => listOf(await api.get('/notifications', {'per_page': 50})),
        builder: (context, list, reload) => list.isEmpty
            ? ListView(children: const [Empty(icon: Icons.notifications_none_rounded, title: 'You’re all caught up', text: 'Updates about your bookings, orders and rewards appear here.')])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = list[i];
                  final unread = n['read'] != true;
                  return LvCard(
                    color: unread ? const Color(0xFFF2F8F7) : Colors.white,
                    borderColor: unread ? const Color(0xFFCFE3DF) : C.line,
                    padding: const EdgeInsets.all(14),
                    onTap: () async {
                      if (unread) {
                        api.post('/notifications/${n['id']}/read').then((_) => session.refreshUnread()).catchError((_) {});
                      }
                      final r = routeForTarget(n['target'] as Map?);
                      if (r != null) await context.push(r);
                      reload();
                    },
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      IconBox(iconFor(n.str('icon'), Icons.notifications_rounded), tone: n.str('type').startsWith('rewards') || n.str('type').startsWith('gift') ? Tone.gold : Tone.teal, small: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(n.str('title'), style: TextStyle(fontWeight: unread ? FontWeight.w600 : FontWeight.w500))),
                            Muted(ago(n.str('created_at')), size: 11.5),
                          ]),
                          const SizedBox(height: 2),
                          Text(n.str('body'), style: const TextStyle(color: Color(0xFF4A4A4A), fontSize: 13, height: 1.4)),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------- news

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key, required this.id});
  final int id;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Loader<Json>(
          load: () async => dataOf(await api.get('/catalog/news/$id')),
          builder: (context, n, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
            if (n.str('image_url').isNotEmpty) ...[
              ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(n.str('image_url'), height: 210, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
              const SizedBox(height: 16),
            ],
            Row(children: [Pill(n.str('tag', 'News'), tone: Tone.gold), const SizedBox(width: 8), Muted(dayLong(n.str('published_at', n.str('created_at'))), size: 12.5)]),
            const SizedBox(height: 10),
            Text(n.str('title'), style: serif(28)),
            const SizedBox(height: 12),
            Text(n.str('body'), style: const TextStyle(height: 1.6, fontSize: 15, color: Color(0xFF3A3A3A))),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- profile

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.student = false});
  final bool student;

  Future<void> _avatar(BuildContext context) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (x == null) return;
    try {
      final u = dataOf(await api.upload('/auth/me/avatar', {}, {'avatar': [UploadFile(await x.readAsBytes(), x.name.contains('.') ? x.name : '${x.name}.jpg')]}));
      session.setUser(u);
      if (context.mounted) toast(context, 'Photo updated');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StatusBarScrim(child: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final u = session.user ?? {};
            final branch = u['preferred_branch'] is Map ? Map<String, dynamic>.from(u['preferred_branch']) : null;
            return ListView(padding: EdgeInsets.zero, children: [
              TealHeader(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 20, 20, 60),
                child: Column(children: [
                  GestureDetector(
                    onTap: () => _avatar(context),
                    child: Stack(children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .25), width: 4)),
                        child: Avatar(name: u['name']?.toString() ?? '', size: 84, hue: 28, url: u['avatar_url']?.toString()),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(padding: const EdgeInsets.all(5), decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle), child: const Icon(Icons.photo_camera_rounded, size: 15, color: C.ink)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(u['name']?.toString() ?? '', style: serif(26, color: Colors.white)),
                  Text([u['phone_local'] ?? u['phone'], if (!student && branch != null) branch['name']].whereType<Object>().join(' · '), style: const TextStyle(color: C.mint, fontSize: 13)),
                ]),
              ),
              Transform.translate(
                offset: const Offset(0, -36),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (!student) ...[
                      LvList(children: [
                        LvTile(icon: Icons.event_note_rounded, title: 'My appointments', onTap: () => context.push('/appointments')),
                        LvTile(icon: Icons.receipt_long_rounded, title: 'Payments & receipts', onTap: () => context.push('/payments')),
                        LvTile(icon: Icons.shopping_bag_outlined, title: 'My orders', onTap: () => context.push('/orders')),
                        LvTile(icon: Icons.medication_outlined, title: 'Prescriptions', onTap: () => context.push('/prescriptions')),
                        LvTile(icon: Icons.alarm_rounded, iconTone: Tone.gold, title: 'Medicine reminders', onTap: () => context.push('/reminders')),
                        LvTile(icon: Icons.card_giftcard_rounded, iconTone: Tone.gold, title: 'Gift cards', onTap: () => context.push('/gift-cards')),
                        LvTile(icon: Icons.support_agent_rounded, title: 'Help & feedback', onTap: () => context.push('/complaints')),
                      ]),
                      const SizedBox(height: 14),
                    ],
                    LvList(children: [
                      LvTile(icon: Icons.person_outline_rounded, title: 'Edit profile', onTap: () => context.push('/profile/edit')),
                      LvTile(icon: Icons.lock_outline_rounded, title: 'Change password', onTap: () => context.push('/profile/password')),
                      LvTile(icon: Icons.notifications_none_rounded, title: 'Notifications', onTap: () => context.push('/notifications')),
                      if (session.config['academy_phone'] != null)
                        LvTile(
                          icon: Icons.call_outlined,
                          title: student ? 'Call the academy' : 'Call Lavish',
                          subtitle: session.config['academy_phone'].toString(),
                          onTap: () => launchUrl(Uri.parse('tel:${session.config['academy_phone'].toString().replaceAll(' ', '')}')),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    LvButton('Sign out', kind: BtnKind.danger, icon: Icons.logout_rounded, onTap: () async {
                      if (await confirm(context, title: 'Sign out?', body: 'You’ll need your phone number and password to sign in again.', ok: 'Sign out', danger: true)) {
                        await session.logout();
                      }
                    }),
                    const SizedBox(height: 16),
                    Center(child: Muted('Lavish Medical Spa · v1.0 (build ${AppConfig.build})', size: 11.5)),
                  ]),
                ),
              ),
            ]);
          },
        )),
      );
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final u = session.user ?? {};
  late final name = TextEditingController(text: u['name']?.toString() ?? '');
  late final email = TextEditingController(text: u['email']?.toString() ?? '');
  late String gender = u['gender']?.toString() ?? 'Female';
  late String locale = u['locale']?.toString() ?? 'en';
  late int? branchId = u['preferred_branch'] is Map ? u['preferred_branch']['id'] as int? : null;
  DateTime? dob;
  List<Json> branches = [];
  bool busy = false;

  @override
  void initState() {
    super.initState();
    dob = parseDate(u['date_of_birth']?.toString());
    if (session.isClient) api.get('/catalog/branches').then((r) => mounted ? setState(() => branches = listOf(r)) : null).catchError((_) => null);
  }

  Future<void> _save() async {
    if (!await confirm(context, title: 'Save your profile?', ok: 'Save')) return;
    setState(() => busy = true);
    try {
      await session.updateMe({
        'name': name.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'locale': locale,
        if (session.isClient) ...{'gender': gender, 'preferred_branch_id': branchId, 'date_of_birth': dob == null ? null : ymd(dob!)},
      });
      if (!mounted) return;
      toast(context, 'Profile saved');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Edit profile'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Field(label: 'Full name', controller: name, icon: Icons.person_outline_rounded),
          Field(label: 'Email', controller: email, icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
          if (session.isClient) ...[
            const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Gender', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
            Seg<String>(items: const [('Female', 'Female'), ('Male', 'Male')], value: gender, onChanged: (v) => setState(() => gender = v)),
            const SizedBox(height: 14),
            LvList(children: [
              LvTile(
                icon: Icons.cake_outlined,
                title: dob == null ? 'Add your birthday' : 'Birthday · ${dayLong(dob!.toIso8601String())}',
                subtitle: 'We send you birthday points every year',
                onTap: () async {
                  final d = await showDatePicker(context: context, firstDate: DateTime(1930), lastDate: DateTime.now(), initialDate: dob ?? DateTime(1995));
                  if (d != null) setState(() => dob = d);
                },
              ),
            ]),
            const SizedBox(height: 14),
            if (branches.isNotEmpty)
              DropdownButtonFormField<int>(
                key: ValueKey('branches-${branches.length}'),
                initialValue: branchId,
                hint: const Text('Choose a branch', style: TextStyle(color: C.muted)),
                decoration: const InputDecoration(labelText: 'Preferred branch', prefixIcon: Icon(Icons.location_on_outlined, color: C.muted, size: 20)),
                items: [for (final b in branches) DropdownMenuItem(value: b['id'] as int, child: Text(b.str('name')))],
                onChanged: (v) => setState(() => branchId = v),
              ),
            const SizedBox(height: 14),
          ],
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Language for messages', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          Seg<String>(items: const [('en', 'English'), ('am', 'አማርኛ')], value: locale, onChanged: (v) => setState(() => locale = v)),
        ]),
        bottomNavigationBar: FootBar(child: LvButton('Save', onTap: _save, busy: busy)),
      );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final current = TextEditingController();
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  bool busy = false;

  Future<void> _save() async {
    if (p1.text.length < 8) return toast(context, 'Use at least 8 characters', error: true);
    if (p1.text != p2.text) return toast(context, 'The two passwords don’t match', error: true);
    if (!await confirm(context, title: 'Change your password?', ok: 'Change password')) return;
    setState(() => busy = true);
    try {
      await session.changePassword(current.text, p1.text);
      if (!mounted) return;
      toast(context, 'Password changed');
      context.pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Change password'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          PasswordField(label: 'Current password', controller: current),
          PasswordField(label: 'New password', controller: p1, hint: 'At least 8 characters'),
          PasswordField(label: 'Confirm new password', controller: p2),
        ]),
        bottomNavigationBar: FootBar(child: LvButton('Save', onTap: _save, busy: busy)),
      );
}
