import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const currencies = ['USD', 'EUR', 'GBP', 'NGN', 'GHS', 'KES', 'ZAR', 'CAD', 'AUD', 'INR', 'AED', 'JPY'];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Loader<Profile>(
        load: Repo.profile,
        builder: (context, p, _) => PageBody(maxWidth: 720, children: [
          _ProfileCard(profile: p),
          const SizedBox(height: 16),
          const _PasswordCard(),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Account',
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Signed in as ${sb.auth.currentUser?.email ?? ''}', style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => sb.auth.signOut(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _deleteAccount(context),
                child: const Text('Delete my account'),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('AUTOX 0.1.0', style: TextStyle(fontSize: 12, color: AppColors.muted))),
        ]),
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('All your vehicles, reminders, documents, files and AI conversations will be permanently deleted.'),
          const SizedBox(height: 14),
          TextField(controller: c, decoration: const InputDecoration(labelText: 'Type DELETE to confirm')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, c.text.trim().toUpperCase() == 'DELETE'),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final res = await sb.functions.invoke('delete-account', method: HttpMethod.post);
      final data = res.data is String ? jsonDecode(res.data) : res.data;
      if (data is Map && data['ok'] == true) {
        await sb.auth.signOut();
      } else {
        throw Exception(data is Map ? data['error'] : 'Could not delete the account.');
      }
    } on FunctionException catch (e) {
      final d = e.details;
      if (context.mounted) toast(context, d is Map && d['error'] != null ? '${d['error']}' : 'Could not delete the account.');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({required this.profile});
  final Profile profile;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final p = widget.profile;
  late final _name = TextEditingController(text: p.name);
  late final _phone = TextEditingController(text: p.phone ?? '');
  late String _unit = p.distanceUnit;
  late String _currency = p.currency;
  late bool _email = p.emailReminders;
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return toast(context, 'Enter your name.');
    setState(() => _busy = true);
    try {
      await Repo.updateProfile({
        'name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'distance_unit': _unit,
        'currency': _currency,
        'email_reminders': _email,
      });
      if (mounted) toast(context, 'Profile saved.');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return SectionCard(
      title: 'Profile',
      subtitle: 'How the app addresses you and shows numbers',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ResponsiveGrid(children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
        ]),
        gap,
        ResponsiveGrid(children: [
          DropdownButtonFormField<String>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Distance unit'),
            items: const [
              DropdownMenuItem(value: 'km', child: Text('Kilometres (km)')),
              DropdownMenuItem(value: 'mi', child: Text('Miles (mi)')),
            ],
            onChanged: (v) => setState(() => _unit = v!),
          ),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: [for (final c in {...currencies, _currency}) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => _currency = v!),
          ),
        ]),
        gap,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _email,
          onChanged: (v) => setState(() => _email = v),
          title: const Text('Email reminders'),
          subtitle: const Text('A daily digest when service is due or a document is expiring. In-app alerts are always on.'),
        ),
        gap,
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save profile')),
        ),
      ]),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  const _PasswordCard();

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (_pw.text.length < 8) return toast(context, 'Use at least 8 characters.');
    if (_pw.text != _pw2.text) return toast(context, "The passwords don't match.");
    setState(() => _busy = true);
    try {
      await sb.auth.updateUser(UserAttributes(password: _pw.text));
      _pw.clear();
      _pw2.clear();
      if (mounted) toast(context, 'Password changed.');
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Change password',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ResponsiveGrid(children: [
          TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'New password')),
          TextField(controller: _pw2, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
        ]),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Update password')),
        ),
      ]),
    );
  }
}
