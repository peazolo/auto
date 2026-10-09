import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../maintenance/maintenance_screen.dart';
import '../maintenance/task_widgets.dart';
import 'vehicles_list.dart';

class _Data {
  _Data(this.profile, this.vehicle, this.tasks, this.docs, this.logs);
  final Profile profile;
  final Vehicle? vehicle;
  final List<MaintenanceTask> tasks;
  final List<CarDocument> docs;
  final List<MaintenanceLog> logs;
}

class VehicleDetailScreen extends StatelessWidget {
  const VehicleDetailScreen({super.key, required this.id});
  final String id;

  Future<_Data> _load() async {
    final r = await Future.wait([
      Repo.profile(),
      Repo.vehicle(id),
      Repo.tasks(vehicleId: id),
      Repo.documents(vehicleId: id),
      Repo.logs(vehicleId: id, limit: 10),
    ]);
    return _Data(r[0] as Profile, r[1] as Vehicle?, r[2] as List<MaintenanceTask>, r[3] as List<CarDocument>,
        r[4] as List<MaintenanceLog>);
  }

  Future<void> _delete(BuildContext context, Vehicle v) async {
    final ok = await confirm(context, 'Delete ${v.name}?',
        'This removes the vehicle with all its reminders, service history and linked documents. This cannot be undone.');
    if (!ok || !context.mounted) return;
    try {
      await Repo.deleteVehicle(v);
      if (context.mounted) {
        toast(context, 'Vehicle deleted.');
        context.go('/vehicles');
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_Data>(
      load: _load,
      builder: (context, d, reload) {
        final v = d.vehicle;
        if (v == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Vehicle not found',
              action: FilledButton(onPressed: () => context.go('/vehicles'), child: const Text('Back to garage')),
            ),
          );
        }
        final unit = d.profile.distanceUnit, cur = d.profile.currency;
        final tasks = sortTasks(d.tasks);
        return Scaffold(
          appBar: AppBar(
            title: Text(v.name),
            actions: [
              IconButton(tooltip: 'Edit', onPressed: () => context.push('/vehicles/${v.id}/edit'), icon: const Icon(Icons.edit_outlined)),
              PopupMenuButton<String>(
                onSelected: (s) => s == 'delete' ? _delete(context, v) : null,
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Delete vehicle'))],
              ),
            ],
          ),
          body: PageBody(onRefresh: reload, children: [
            LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final photo = ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(aspectRatio: 16 / 10, child: VehiclePhoto(v)),
              );
              final info = _InfoCard(vehicle: v, unit: unit);
              return wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: photo),
                      const SizedBox(width: 16),
                      Expanded(child: info),
                    ])
                  : Column(children: [photo, const SizedBox(height: 14), info]);
            }),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                onPressed: () => context.push('/diagnose/new?vehicle=${v.id}'),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Diagnose a problem'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/maintenance/new?vehicle=${v.id}'),
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('Add reminder'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/documents/new?vehicle=${v.id}'),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('Add document'),
              ),
            ]),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Maintenance reminders',
              action: TextButton(onPressed: () => context.go('/maintenance?vehicle=${v.id}'), child: const Text('View all')),
              child: tasks.isEmpty
                  ? EmptyState(
                      icon: Icons.build_rounded,
                      title: 'No reminders for this car',
                      action: FilledButton(onPressed: () => context.push('/maintenance/new?vehicle=${v.id}'), child: const Text('Create a reminder')),
                    )
                  : Column(children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        if (i > 0) const Divider(),
                        TaskTile(task: tasks[i], unit: unit, currency: cur, showVehicle: false),
                      ],
                    ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Documents',
              action: TextButton(onPressed: () => context.go('/documents?vehicle=${v.id}'), child: const Text('View all')),
              child: d.docs.isEmpty
                  ? const EmptyState(icon: Icons.description_outlined, title: 'No documents yet', body: 'Insurance, registration, inspection and more.')
                  : Column(children: [
                      for (final doc in d.docs)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined, color: AppColors.brown600),
                          title: Text(doc.title),
                          subtitle: Text(doc.expiresAt == null ? doc.typeLabel : '${doc.typeLabel} · expires ${fmtDate(doc.expiresAt)}'),
                          trailing: docStatusPill(doc.status),
                          onTap: () => context.go('/documents/${doc.id}'),
                        ),
                    ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Recent service',
              action: TextButton.icon(
                onPressed: () => showLogSheet(context, [v], v.id, unit, cur),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
              child: d.logs.isEmpty
                  ? const EmptyState(icon: Icons.history_rounded, title: 'No service records yet')
                  : Column(children: [for (final l in d.logs) LogTile(log: l, unit: unit, currency: cur, showVehicle: false)]),
            ),
          ]),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.vehicle, required this.unit});
  final Vehicle vehicle;
  final String unit;

  Future<void> _updateOdometer(BuildContext context) async {
    final c = TextEditingController(text: '${vehicle.mileage}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update odometer'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: unit, labelText: 'Current reading'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim().replaceAll(',', ''))), child: const Text('Save')),
        ],
      ),
    );
    if (value == null || !context.mounted) return;
    if (value < 0) return toast(context, 'Odometer cannot be negative.');
    try {
      await Repo.updateMileage(vehicle.id, value);
      if (context.mounted) toast(context, 'Odometer updated.');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    Widget row(String k, String? val) => val == null || val.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 90, child: Text(k, style: const TextStyle(color: AppColors.muted))),
              Expanded(child: Text(val, style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.fullName, style: display(22)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.butter100, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.speed_rounded, color: AppColors.brown600),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${fmtNum(v.mileage)} $unit', style: display(20)),
                  Text('Updated ${timeAgo(v.mileageUpdatedAt)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
              TextButton(onPressed: () => _updateOdometer(context), child: const Text('Update')),
            ]),
          ),
          const SizedBox(height: 10),
          row('Trim', v.trim),
          row('Colour', v.color),
          row('Fuel', v.fuelType),
          row('Plate', v.plate),
          row('VIN', v.vin),
        ]),
      ),
    );
  }
}
