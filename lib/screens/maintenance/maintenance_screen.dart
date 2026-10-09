import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell.dart';
import 'task_widgets.dart';

class _Data {
  _Data(this.profile, this.vehicles, this.tasks, this.logs);
  final Profile profile;
  final List<Vehicle> vehicles;
  final List<MaintenanceTask> tasks;
  final List<MaintenanceLog> logs;
}

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key, this.vehicleId});
  final String? vehicleId;

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  late String? _vehicle = widget.vehicleId;

  Future<_Data> _load() async {
    final r = await Future.wait([Repo.profile(), Repo.vehicles(), Repo.tasks(), Repo.logs()]);
    return _Data(r[0] as Profile, r[1] as List<Vehicle>, r[2] as List<MaintenanceTask>, r[3] as List<MaintenanceLog>);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance'), actions: const [PhoneActions()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/maintenance/new${_vehicle != null ? '?vehicle=$_vehicle' : ''}'),
        icon: const Icon(Icons.add),
        label: const Text('New reminder'),
      ),
      body: Loader<_Data>(
        load: _load,
        builder: (context, d, reload) {
          if (d.vehicles.isEmpty) {
            return PageBody(children: [
              Card(
                child: EmptyState(
                  icon: Icons.build_rounded,
                  title: 'Add a vehicle first',
                  body: 'Maintenance reminders are attached to a vehicle.',
                  action: FilledButton(onPressed: () => context.push('/vehicles/new'), child: const Text('Add vehicle')),
                ),
              ),
            ]);
          }
          final unit = d.profile.distanceUnit, cur = d.profile.currency;
          final tasks = sortTasks(d.tasks.where((t) => _vehicle == null || t.vehicleId == _vehicle).toList());
          final logs = d.logs.where((l) => _vehicle == null || l.vehicleId == _vehicle).toList();
          final spend = logs.fold<double>(0, (s, l) => s + (l.cost ?? 0));
          final multi = d.vehicles.length > 1;
          return PageBody(onRefresh: reload, children: [
            const Text("Set it once. We'll remind you before anything is due.", style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            if (multi)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(label: const Text('All vehicles'), selected: _vehicle == null, onSelected: (_) => setState(() => _vehicle = null)),
                  for (final v in d.vehicles)
                    ChoiceChip(label: Text(v.name), selected: _vehicle == v.id, onSelected: (_) => setState(() => _vehicle = v.id)),
                ]),
              ),
            SectionCard(
              title: 'Reminders',
              subtitle: 'Sorted by what needs attention first',
              child: tasks.isEmpty
                  ? EmptyState(
                      icon: Icons.build_rounded,
                      title: 'No reminders yet',
                      body: 'Create one for oil changes, tire rotations, brakes or anything else.',
                      action: FilledButton(onPressed: () => context.push('/maintenance/new'), child: const Text('Create a reminder')),
                    )
                  : Column(children: [
                      for (var i = 0; i < tasks.length; i++) ...[
                        if (i > 0) const Divider(),
                        TaskTile(task: tasks[i], unit: unit, currency: cur, showVehicle: multi),
                      ],
                    ]),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Service history',
              subtitle: 'Total recorded spend: ${fmtMoney(spend, cur)}',
              action: TextButton.icon(
                onPressed: () => showLogSheet(context, d.vehicles, _vehicle, unit, cur),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
              child: logs.isEmpty
                  ? const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No service history yet',
                      body: 'Marking a reminder as done adds it here automatically.')
                  : Column(children: [
                      for (final l in logs) LogTile(log: l, unit: unit, currency: cur, showVehicle: multi),
                    ]),
            ),
          ]);
        },
      ),
    );
  }
}

Future<void> showLogSheet(BuildContext context, List<Vehicle> vehicles, String? vehicleId, String unit, String currency) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => _LogSheet(vehicles: vehicles, vehicleId: vehicleId ?? vehicles.first.id, unit: unit, currency: currency),
  );
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.vehicles, required this.vehicleId, required this.unit, required this.currency});
  final List<Vehicle> vehicles;
  final String vehicleId, unit, currency;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  late String _vehicle = widget.vehicleId;
  DateTime _date = today();
  final _title = TextEditingController();
  final _mileage = TextEditingController();
  final _cost = TextEditingController();
  final _shop = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return toast(context, 'What was done?');
    setState(() => _busy = true);
    try {
      await Repo.addLog({
        'vehicle_id': _vehicle,
        'title': _title.text.trim(),
        'performed_at': isoDate(_date),
        'mileage': int.tryParse(_mileage.text.trim()),
        'cost': double.tryParse(_cost.text.trim()),
        'shop': _shop.text.trim().isEmpty ? null : _shop.text.trim(),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      }, vehicle: widget.vehicles.firstWhere((v) => v.id == _vehicle));
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Service record added.');
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add a service record', style: display(22)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _vehicle,
            decoration: const InputDecoration(labelText: 'Vehicle'),
            items: [for (final v in widget.vehicles) DropdownMenuItem(value: v.id, child: Text(v.name))],
            onChanged: (v) => setState(() => _vehicle = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'What was done', hintText: 'Replaced front brake pads')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: DateField(label: 'Date', value: _date, allowClear: false, onChanged: (d) => setState(() => _date = d ?? today()))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _mileage, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Odometer (${widget.unit})'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Cost (${widget.currency})'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _shop, decoration: const InputDecoration(labelText: 'Shop / mechanic'))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 18),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Add record')),
        ]),
      ),
    );
  }
}
