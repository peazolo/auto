import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';
import '../../ui/logo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

String get authRedirect {
  if (!kIsWeb) return AppConfig.mobileRedirectUrl;
  return AppConfig.webRedirectUrl.isNotEmpty ? AppConfig.webRedirectUrl : Uri.base.origin;
}

String authError(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Incorrect email or password.';
    if (m.contains('email not confirmed')) return 'Please confirm your email first. Check your inbox for the link.';
    if (m.contains('already registered')) return 'An account with this email already exists. Try signing in.';
    if (m.contains('rate limit')) return 'Too many attempts. Please wait a few minutes and try again.';
    return e.message;
  }
  return friendlyError(e);
}

/// Split layout: brand panel on wide screens, single column on phones.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 400), child: child),
      ),
    );
    return Scaffold(
      body: SafeArea(
        child: wide ? Row(children: [const Expanded(child: _BrandPanel()), Expanded(child: form)]) : form,
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.espresso,
      padding: const EdgeInsets.all(48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Logo(light: true),
        const Spacer(),
        Text("Your car's whole life,", style: display(40, color: AppColors.butter50)),
        Text('in one calm place.', style: display(40, color: AppColors.butter300)),
        const SizedBox(height: 28),
        for (final t in const [
          'Service reminders by date or mileage',
          'Document vault with expiry alerts',
          'AI diagnosis from photos, video and questions',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              const Icon(Icons.check_circle, color: AppColors.butter300, size: 18),
              const SizedBox(width: 10),
              Text(t, style: TextStyle(color: AppColors.butter100.withValues(alpha: 0.85))),
            ]),
          ),
        const Spacer(),
      ]),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.espresso,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Logo(light: true, size: 44),
                const SizedBox(height: 48),
                Text('Keep your car healthy.', style: display(42, color: AppColors.butter50)),
                Text('Without the guesswork.', style: display(42, color: AppColors.butter300)),
                const SizedBox(height: 18),
                Text(
                  'AUTOX remembers every service, warns you before documents expire, and diagnoses problems from a photo, a video or a simple question.',
                  style: TextStyle(color: AppColors.butter100.withValues(alpha: 0.8), fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 32),
                const _Feature(Icons.build_rounded, 'Maintenance on autopilot', 'Reminders by date, mileage or both.'),
                const _Feature(Icons.description_rounded, 'Document vault', 'License, insurance, registration and more, with expiry alerts.'),
                const _Feature(Icons.auto_awesome, 'AI mechanic', 'Snap it, film it or ask it. Get causes, urgency and costs.'),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.butter300, foregroundColor: AppColors.espresso),
                    onPressed: () => context.go('/signup'),
                    child: const Text('Create free account'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.butter50, side: BorderSide(color: AppColors.butter100.withValues(alpha: 0.3))),
                    onPressed: () => context.go('/login'),
                    child: const Text('I have an account'),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.butter300, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.espresso, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AppColors.butter50, fontWeight: FontWeight.w700)),
            Text(body, style: TextStyle(color: AppColors.butter100.withValues(alpha: 0.7), fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader(this.title, this.subtitle);
  final String title, subtitle;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!wide) ...[
        GestureDetector(onTap: () => context.go('/welcome'), child: const Logo()),
        const SizedBox(height: 36),
      ],
      Text(title, style: display(30)),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 28),
    ]);
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.text, {this.ok = false});
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = ok ? AppColors.good : AppColors.danger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: c, fontSize: 13.5)),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _FormHeader('Welcome back', 'Sign in to keep your car in top shape.'),
          if (_error != null) _ErrorBox(_error!),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => context.go('/forgot-password'), child: const Text('Forgot password?')),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Signing in…' : 'Sign in')),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('New to AUTOX?', style: TextStyle(color: AppColors.muted)),
            TextButton(onPressed: () => context.go('/signup'), child: const Text('Create an account')),
          ]),
        ]),
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _checkEmail = false;

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Enter your name.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return setState(() => _error = 'Enter a valid email.');
    if (_password.text.length < 8) return setState(() => _error = 'Password must be at least 8 characters.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: _password.text,
        data: {'name': name},
        emailRedirectTo: authRedirect,
      );
      if (res.session == null) setState(() => _checkEmail = true);
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkEmail) {
      return AuthLayout(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _FormHeader('Check your email', 'We sent you a link to confirm your account.'),
          Text('Open the email we sent to ${_email.text.trim()} and tap the link. Then come back and sign in.',
              style: const TextStyle(height: 1.5)),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => context.go('/login'), child: const Text('Go to sign in')),
        ]),
      );
    }
    return AuthLayout(
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const _FormHeader('Create your account', 'Free to start. Takes under a minute.'),
          if (_error != null) _ErrorBox(_error!),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Creating account…' : 'Create account')),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('Already have an account?', style: TextStyle(color: AppColors.muted)),
            TextButton(onPressed: () => context.go('/login'), child: const Text('Sign in')),
          ]),
        ]),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _ok = false;

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_email.text.trim(), redirectTo: authRedirect);
      setState(() {
        _ok = true;
        _msg = "If an account exists for that email, we've sent a reset link. Check your inbox.";
      });
    } catch (e) {
      setState(() {
        _ok = false;
        _msg = authError(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _FormHeader('Forgot your password?', "Enter your email and we'll send you a reset link."),
        if (_msg != null) _ErrorBox(_msg!, ok: _ok),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Sending…' : 'Send reset link')),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
      ]),
    );
  }
}

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_p1.text.length < 8) return setState(() => _error = 'Password must be at least 8 characters.');
    if (_p1.text != _p2.text) return setState(() => _error = "Passwords don't match.");
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _p1.text));
      widget.onDone();
      if (mounted) {
        toast(context, 'Password updated.');
        context.go('/');
      }
    } catch (e) {
      setState(() => _error = authError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _FormHeader('Choose a new password', "You'll stay signed in after this."),
        if (_error != null) _ErrorBox(_error!),
        TextField(controller: _p1, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
        const SizedBox(height: 14),
        TextField(
          controller: _p2,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm password'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Saving…' : 'Save password')),
      ]),
    );
  }
}
