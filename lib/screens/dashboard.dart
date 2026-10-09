import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'shell.dart';

class _DashData {
  _DashData(this.profile, this.vehicles, this.tasks, this.docs, this.spent);
  final Profile profile;
  final List<Vehicle> vehicles;
  final List<MaintenanceTask> tasks;
  final List<CarDocument> docs;
  final double spent;
}

Future<_DashData> _load() async {
  final r = await Future.wait([Repo.profile(), Repo.vehicles(), Repo.tasks(), Repo.documents(), Repo.logs(limit: 1000)]);
  final year = DateTime.now().year;
  final spent = (r[4] as List<MaintenanceLog>)
      .where((l) => l.performedAt.year == year)
      .fold<double>(0, (s, l) => s + (l.cost ?? 0));
  return _DashData(r[0] as Profile, r[1] as List<Vehicle>, r[2] as List<MaintenanceTask>, r[3] as List<CarDocument>, spent);
}

String _greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 8, actions: const []),
      body: Loader<_DashData>(
        load: _load,
        builder: (context, d, reload) {
          final unit = d.profile.distanceUnit;
          final attention = d.tasks
              .map((t) => (t, t.status(t.vehicle!.mileage)))
              .where((x) => x.$2 == DueStatus.overdue || x.$2 == DueStatus.dueSoon)
              .toList()
            ..sort((a, b) => a.$2.index != b.$2.index
                ? a.$2.index - b.$2.index
                : (a.$1.nextDueAt ?? DateTime(9999)).compareTo(b.$1.nextDueAt ?? DateTime(9999)));
          final docs = d.docs.where((x) => x.status == DocStatus.expired || x.status == DocStatus.expiring).toList();
          final overdue = attention.where((x) => x.$2 == DueStatus.overdue).length +
              docs.where((x) => x.status == DocStatus.expired).length;
          final upcoming = d.tasks
              .where((t) => t.nextDueAt != null && t.status(t.vehicle!.mileage) == DueStatus.ok)
              .toList()
            ..sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));

          final subtitle = d.vehicles.isEmpty
              ? "Let's get your first car set up."
              : overdue > 0
                  ? '$overdue item${overdue == 1 ? ' is' : 's are'} overdue. Let\'s sort ${overdue == 1 ? 'it' : 'them'} out.'
                  : attention.length + docs.length > 0
                      ? 'A few things are coming up soon.'
                      : "Everything's on track. Nice work.";

          return PageBody(
            onRefresh: reload,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${_greeting()},', style: const TextStyle(color: AppColors.caramel, fontWeight: FontWeight.w600)),
                    Text(d.profile.firstName, style: display(36)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
                const PhoneActions(),
              ]),
              const SizedBox(height: 22),
              if (d.vehicles.isEmpty)
                Card(
                  child: EmptyState(
                    icon: Icons.directions_car_rounded,
                    title: 'Add your first vehicle',
                    body: 'AUTOX tracks maintenance, documents and diagnoses per vehicle.',
                    action: FilledButton.icon(
                      onPressed: () => context.push('/vehicles/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add vehicle'),
                    ),
                  ),
                )
              else ...[
                ResponsiveGrid(columns: 4, narrowColumns: 2, breakpoint: 700, gap: 12, children: [
                  _Stat(Icons.directions_car_outlined, '${d.vehicles.length}', 'Vehicles', () => context.go('/vehicles')),
                  _Stat(Icons.warning_amber_rounded, '${attention.length + docs.length}', 'Need attention',
                      () => context.go('/maintenance'), color: overdue > 0 ? AppColors.danger : null),
                  _Stat(Icons.description_outlined, '${d.docs.length}', 'Documents', () => context.go('/documents')),
                  _Stat(Icons.account_balance_wallet_outlined, fmtMoney(d.spent, d.profile.currency),
                      'Spent in ${DateTime.now().year}', () => context.go('/maintenance')),
                ]),
                const SizedBox(height: 16),
                _AiCard(onTap: () => context.push('/diagnose/new')),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Needs attention',
                  subtitle: 'Overdue and upcoming maintenance and renewals',
                  child: attention.isEmpty && docs.isEmpty
                      ? const EmptyState(
                          icon: Icons.check_circle_outline,
                          title: 'All clear',
                          body: "Nothing is due right now. We'll alert you when something comes up.")
                      : Column(children: [
                          for (final (t, s) in attention.take(8))
                            ListTile(
                              leading: const Icon(Icons.build_rounded, color: AppColors.caramel),
                              title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text([
                                t.vehicle!.name,
                                if (t.nextDueAt != null) '${fmtDate(t.nextDueAt)} (${relativeDays(t.nextDueAt!)})',
                                if (t.nextDueMileage != null) 'at ${fmtNum(t.nextDueMileage)} $unit',
                              ].join(' · ')),
                              trailing: taskStatusPill(s),
                              onTap: () => context.go('/vehicles/${t.vehicleId}'),
                            ),
                          for (final doc in docs.take(6))
                            ListTile(
                              leading: const Icon(Icons.description_rounded, color: AppColors.caramel),
                              title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${doc.typeLabel} · ${doc.status == DocStatus.expired ? 'expired' : 'expires'} ${fmtDate(doc.expiresAt)} (${relativeDays(doc.expiresAt!)})'),
                              trailing: docStatusPill(doc.status),
                              onTap: () => context.go('/documents/${doc.id}'),
                            ),
                        ]),
                ),
                const SizedBox(height: 16),
                SectionCard(
                  title: 'Coming up later',
                  child: upcoming.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            const Expanded(child: Text('No scheduled reminders.', style: TextStyle(color: AppColors.muted))),
                            TextButton(onPressed: () => context.push('/maintenance/new'), child: const Text('Create one')),
                          ]),
                        )
                      : Column(children: [
                          for (final t in upcoming.take(5))
                            ListTile(
                              dense: true,
                              title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(t.vehicle!.name),
                              trailing: Text(relativeDays(t.nextDueAt!),
                                  style: const TextStyle(color: AppColors.caramel, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                        ]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, this.onTap, {this.color});
  final IconData icon;
  final String value, label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.caramel, size: 20),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color ?? AppColors.espresso)),
            ),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.espresso, borderRadius: BorderRadius.circular(18)),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.auto_awesome, color: AppColors.butter300),
        const SizedBox(height: 10),
        Text('Something feels off?', style: display(24, color: AppColors.butter50)),
        const SizedBox(height: 6),
        Text(
          "Send a photo, a short video or a question. The AI mechanic tells you what's likely wrong and how urgent it is.",
          style: TextStyle(color: AppColors.butter100.withValues(alpha: 0.75), height: 1.4),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.butter300, foregroundColor: AppColors.espresso),
          onPressed: onTap,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Start a diagnosis'),
        ),
      ]),
    );
  }
}
