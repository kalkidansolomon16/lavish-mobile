import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/phone_field.dart';
import '../../widgets/ui.dart';

// ---------------------------------------------------------------- splash

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(-.4, -.6), radius: 1.4, colors: [C.tealGlow, C.dark, C.tealNight], stops: [0, .45, 1])),
          child: Stack(children: [
            Positioned.fill(child: Opacity(opacity: .12, child: Image.asset('assets/img/pattern.png', repeat: ImageRepeat.repeat, fit: BoxFit.none))),
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Image.asset('assets/img/logo-white.png', width: 220),
                const SizedBox(height: 10),
                const Text('MEDICAL SPA · ACADEMY', style: TextStyle(color: C.gold, letterSpacing: 4, fontSize: 11)),
              ]),
            ),
            const Positioned(left: 0, right: 0, bottom: 70, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: C.gold)))),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- welcome

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(padding: EdgeInsets.zero, children: [
          TealHeader(
            radius: 34,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.paddingOf(context).top + 18, 24, 34),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.asset('assets/img/logo-white.png', width: 120),
              const SizedBox(height: 46),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Beauty, care\n& learning —\n'),
                  TextSpan(text: 'in your pocket.', style: serif(40, weight: FontWeight.w500, color: C.gold, height: 1.02).copyWith(fontStyle: FontStyle.italic)),
                ]),
                style: serif(40, weight: FontWeight.w500, color: Colors.white, height: 1.02),
              ),
              const SizedBox(height: 12),
              const Text('Book treatments with our doctors, shop aftercare and grow your career with Lavish Academy.', style: TextStyle(color: C.mint, height: 1.5)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Label('How will you use Lavish?'),
              const SizedBox(height: 4),
              _RoleCard(icon: Icons.spa_rounded, title: 'I’m a client', text: 'Book appointments, shop products & chat with your doctor', onTap: () => context.push('/register')),
              _RoleCard(icon: Icons.school_rounded, gold: true, title: 'I’m a student', text: 'Log in with the student account the academy gave you', onTap: () => context.push('/login?role=student')),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Muted('Already have an account? ', size: 14),
                LinkText('Log in', onTap: () => context.push('/login')),
              ]),
              const SizedBox(height: 16),
              const Center(child: Muted('Build ${AppConfig.build}', size: 11)),
            ]),
          ),
        ]),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.text, required this.onTap, this.gold = false});
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;
  final bool gold;
  @override
  Widget build(BuildContext context) => LvCard(
        margin: const EdgeInsets.only(top: 12),
        onTap: onTap,
        child: Row(children: [
          IconBox(icon, tone: gold ? Tone.gold : Tone.teal, size: 50),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: serif(21)), Muted(text, size: 12.5)])),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      );
}

// ---------------------------------------------------------------- login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.student = false});
  final bool student;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phone = PhoneController();
  final password = TextEditingController();
  bool busy = false;

  Future<void> submit() async {
    if (phone.text.trim().isEmpty || password.text.isEmpty) return toast(context, 'Enter your phone number and password', error: true);
    setState(() => busy = true);
    try {
      await session.login(phone.full, password.text);
      // The router opens the right home (client / student / set password).
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'phone_not_verified') {
        final p = e.details['phone']?.toString() ?? phone.full;
        toast(context, 'Verify your phone first — we sent you a new code');
        try {
          await session.resendOtp(p, 'register');
        } catch (_) {}
        if (mounted) context.push('/otp', extra: {'phone': p, 'purpose': 'register'});
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
        Center(child: ColorFiltered(colorFilter: const ColorFilter.mode(C.dark, BlendMode.srcIn), child: Image.asset('assets/img/logo-white.png', width: 150))),
        const SizedBox(height: 24),
        Text(s ? 'Student login' : 'Welcome back', textAlign: TextAlign.center, style: serif(30)),
        const SizedBox(height: 4),
        Muted(s ? 'Use the login the academy gave you' : 'Log in to continue', align: TextAlign.center, size: 14),
        const SizedBox(height: 24),
        PhoneField(label: 'Phone number', controller: phone, textInputAction: TextInputAction.next),
        PasswordField(label: s ? 'Password from the academy' : 'Password', controller: password, onSubmitted: (_) => submit()),
        if (!s) Align(alignment: Alignment.centerRight, child: LinkText('Forgot password?', size: 13, onTap: () => context.push('/forgot'))),
        const SizedBox(height: 20),
        LvButton('Log in', onTap: submit, busy: busy),
        const SizedBox(height: 16),
        if (s) ...[
          Banner2(
            text: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Student accounts are created by the academy. To enrol, or if you forgot your password, visit the academy or call '),
              TextSpan(text: session.config['academy_phone']?.toString() ?? 'the academy', style: const TextStyle(fontWeight: FontWeight.w600)),
              const TextSpan(text: '.'),
            ])),
            onTap: () => _call(session.config['academy_phone']?.toString()),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Muted('Not a student? ', size: 14), LinkText('Client log in', onTap: () => context.pushReplacement('/login'))]),
        ] else
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Muted('New to Lavish? ', size: 14), LinkText('Create an account', onTap: () => context.push('/register'))]),
      ]),
    );
  }
}

Future<void> _call(String? phone) async {
  if (phone == null || phone.isEmpty) return;
  await launchUrl(Uri.parse('tel:${phone.replaceAll(' ', '')}'));
}

// ---------------------------------------------------------------- register

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final phone = PhoneController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPw = TextEditingController();
  final referral = TextEditingController();
  String gender = 'Female';
  int? branchId;
  List<Json> branches = [];
  bool agree = true;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    api.get('/catalog/branches').then((r) {
      if (!mounted) return;
      setState(() {
        branches = listOf(r);
        branchId = branches.firstWhere((b) => b.flag('is_main'), orElse: () => branches.isEmpty ? {} : branches.first)['id'] as int?;
      });
    }).catchError((e) { if (mounted) showError(context, e); });
  }

  Future<void> submit() async {
    if (name.text.trim().length < 2) return toast(context, 'Enter your full name', error: true);
    if (!phone.looksValid) return toast(context, 'Enter your phone number', error: true);
    if (password.text.length < 8) return toast(context, 'Password must be at least 8 characters', error: true);
    if (confirmPw.text != password.text) return toast(context, 'The two passwords don’t match', error: true);
    if (!agree) return toast(context, 'Please accept the terms to continue', error: true);
    setState(() => busy = true);
    try {
      final p = await session.register({
        'name': name.text.trim(),
        'phone': phone.full,
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'gender': gender,
        'preferred_branch_id': branchId,
        'password': password.text,
        'password_confirmation': confirmPw.text,
        if (referral.text.trim().isNotEmpty) 'referral_code': referral.text.trim(),
      });
      if (mounted) context.push('/otp', extra: {'phone': p, 'purpose': 'register'});
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Create account', subtitle: 'It takes less than a minute'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          Field(label: 'Full name', controller: name, icon: Icons.person_outline_rounded, hint: 'e.g. Tigist Worku'),
          PhoneField(label: 'Phone number', controller: phone),
          Field(label: 'Email (optional)', controller: email, icon: Icons.mail_outline_rounded, hint: 'you@example.com', keyboard: TextInputType.emailAddress),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Gender', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          Seg<String>(items: const [('Female', 'Female'), ('Male', 'Male')], value: gender, onChanged: (v) => setState(() => gender = v)),
          const SizedBox(height: 14),
          const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Preferred branch', style: TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w500))),
          DropdownButtonFormField<int>(
            // Rebuilt when the branches arrive, so the main branch is shown pre-selected.
            key: ValueKey('branches-${branches.length}'),
            initialValue: branchId,
            hint: Text(branches.isEmpty ? 'Loading branches…' : 'Choose a branch', style: const TextStyle(color: C.muted)),
            items: [for (final b in branches) DropdownMenuItem(value: b['id'] as int, child: Text(b.str('name')))],
            onChanged: (v) => setState(() => branchId = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.location_on_outlined, color: C.muted, size: 20)),
          ),
          const SizedBox(height: 14),
          PasswordField(label: 'Password', controller: password, hint: 'At least 8 characters'),
          PasswordField(label: 'Confirm password', controller: confirmPw, hint: 'Type it again'),
          Field(label: 'Friend’s referral code (optional)', controller: referral, icon: Icons.card_giftcard_rounded, hint: 'e.g. TIGIST7K'),
          InkWell(
            onTap: () => setState(() => agree = !agree),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(color: agree ? C.dark : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: agree ? C.dark : C.line, width: 1.5)),
                child: agree ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
              ),
              const SizedBox(width: 10),
              const Expanded(child: Muted('I agree to Lavish’s Terms of Service and Privacy Policy, including how my medical information is stored.')),
            ]),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Muted('Academy student? ', size: 12.5), LinkText('Log in with your student account', size: 12.5, onTap: () => context.push('/login?role=student'))]),
        ]),
        bottomNavigationBar: FootBar(child: LvButton('Create account', onTap: submit, busy: busy)),
      );
}

// ---------------------------------------------------------------- OTP

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, required this.purpose});
  final String phone;
  final String purpose; // register | reset
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final code = TextEditingController();
  final password = TextEditingController();
  final confirmPw = TextEditingController();
  bool busy = false;
  int wait = 60;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() {
    timer?.cancel();
    wait = 60;
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => wait = wait > 0 ? wait - 1 : 0);
      if (wait == 0) t.cancel();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> submit() async {
    if (code.text.length != 6) return toast(context, 'Enter the 6-digit code', error: true);
    if (widget.purpose == 'reset' && password.text.length < 8) return toast(context, 'New password must be at least 8 characters', error: true);
    if (widget.purpose == 'reset' && confirmPw.text != password.text) return toast(context, 'The two passwords don’t match', error: true);
    setState(() => busy = true);
    try {
      if (widget.purpose == 'reset') {
        await session.reset(widget.phone, code.text, password.text);
      } else {
        await session.verify(widget.phone, code.text);
      }
      if (mounted) toast(context, widget.purpose == 'reset' ? 'Password changed — welcome back!' : 'Welcome to Lavish!');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resend() async {
    try {
      if (widget.purpose == 'reset') {
        await session.forgot(widget.phone);
      } else {
        await session.resendOtp(widget.phone, 'register');
      }
      _tick();
      if (mounted) toast(context, 'New code sent');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reset = widget.purpose == 'reset';
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: C.mint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.mint.withValues(alpha: .5), spreadRadius: 12)]),
            child: const Icon(Icons.sms_outlined, size: 38, color: C.dark),
          ),
        ),
        const SizedBox(height: 26),
        Text(reset ? 'Reset your password' : 'Verify your phone', textAlign: TextAlign.center, style: serif(30)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Enter the 6-digit code we sent by SMS to\n'),
            TextSpan(text: widget.phone, style: const TextStyle(color: C.ink, fontWeight: FontWeight.w600)),
          ]),
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        _OtpBoxes(controller: code, onDone: reset ? null : submit),
        if (reset) ...[const SizedBox(height: 20), PasswordField(label: 'New password', controller: password, hint: 'At least 8 characters'), PasswordField(label: 'Confirm new password', controller: confirmPw, hint: 'Type it again')],
        const SizedBox(height: 22),
        Center(
          child: wait > 0
              ? Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Didn’t get it? Resend code in '),
                  TextSpan(text: '0:${wait.toString().padLeft(2, '0')}', style: const TextStyle(color: C.ink, fontWeight: FontWeight.w600)),
                ]), style: const TextStyle(color: C.muted, fontSize: 12.5))
              : LinkText('Resend code', onTap: resend, size: 13),
        ),
      ]),
      bottomNavigationBar: FootBar(child: LvButton(reset ? 'Save new password' : 'Verify & continue', onTap: submit, busy: busy)),
    );
  }
}

/// Six boxes backed by one hidden text field (works with SMS autofill and paste).
class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({required this.controller, this.onDone});
  final TextEditingController controller;
  final VoidCallback? onDone;
  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final focus = FocusNode();
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => focus.requestFocus(),
        child: Stack(children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
              onChanged: (v) {
                setState(() {});
                if (v.length == 6) widget.onDone?.call();
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 6; i++)
              Container(
                width: 48,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 4.5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: i == widget.controller.text.length && focus.hasFocus ? C.dark : C.line, width: 1.5),
                ),
                child: Text(i < widget.controller.text.length ? widget.controller.text[i] : '', style: serif(24)),
              ),
          ]),
        ]),
      );
}

// ---------------------------------------------------------------- forgot / set password

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final phone = PhoneController();
  bool busy = false;

  Future<void> submit() async {
    setState(() => busy = true);
    final p = phone.full;
    try {
      await session.forgot(p);
      if (mounted) context.push('/otp', extra: {'phone': p, 'purpose': 'reset'});
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'call_academy') {
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text('Student account', style: serif(22)),
            content: Text('Student passwords are reset by the academy. Call ${session.config['academy_phone'] ?? 'the academy'}.'),
            actions: [TextButton(onPressed: () => _call(session.config['academy_phone']?.toString()), child: const Text('Call the academy')), TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
          ),
        );
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: lvAppBar(context, 'Forgot password', subtitle: 'We’ll text you a code to reset it'),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
          PhoneField(label: 'Phone number', controller: phone, onSubmitted: (_) => submit()),
        ]),
        bottomNavigationBar: FootBar(child: LvButton('Send code', onTap: submit, busy: busy)),
      );
}

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});
  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final current = TextEditingController();
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  bool busy = false;

  Future<void> submit() async {
    if (p1.text.length < 8) return toast(context, 'Use at least 8 characters', error: true);
    if (p1.text != p2.text) return toast(context, 'The two passwords don’t match', error: true);
    setState(() => busy = true);
    try {
      await session.changePassword(current.text, p1.text);
      if (mounted) toast(context, 'Password saved — welcome to the academy!');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(actions: [TextButton(onPressed: session.logout, child: const Text('Sign out', style: TextStyle(color: C.muted)))]),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Center(child: Container(width: 80, height: 80, decoration: const BoxDecoration(color: C.mint, shape: BoxShape.circle), child: const Icon(Icons.key_rounded, size: 38, color: C.dark))),
          const SizedBox(height: 16),
          Text('Choose your password', textAlign: TextAlign.center, style: serif(30)),
          const SizedBox(height: 8),
          const Muted('You logged in with a temporary password from the academy. Set your own to keep your account safe.', align: TextAlign.center, size: 14),
          const SizedBox(height: 24),
          PasswordField(label: 'Temporary password', controller: current),
          PasswordField(label: 'New password', controller: p1, hint: 'At least 8 characters'),
          PasswordField(label: 'Confirm new password', controller: p2, onSubmitted: (_) => submit()),
        ]),
        bottomNavigationBar: FootBar(child: LvButton('Save & continue', onTap: submit, busy: busy)),
      );
}
