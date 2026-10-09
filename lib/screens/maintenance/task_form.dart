import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'task_widgets.dart';

class TaskFormScreen extends StatelessWidget {
  const TaskFormScreen({super.key, this.id, this.vehicleId});
  final String? id;
  final String? vehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(id == null ? 'New reminder' : 'Edit reminder')),
      body: Loader<(Profile, List<Vehicle>, MaintenanceTask?)>(
        load: () async => (
          await Repo.profile(),
          await Repo.vehicles(),
          id == null ? null : await Repo.task(id!),
        ),
        builder: (context, d, _) {
          if (d.$2.isEmpty) {
            return EmptyState(
              icon: Icons.directions_car_rounded,
              title: 'Add a vehicle first',
              action: FilledButton(onPressed: () => context.pushReplacement('/vehicles/new'), child: const Text('Add vehicle')),
            );
          }
          return _TaskForm(profile: d.$1, vehicles: d.$2, task: d.$3, vehicleId: vehicleId);
        },
      ),
    );
  }
}

class _TaskForm extends StatefulWidget {
  const _TaskForm({required this.profile, required this.vehicles, this.task, this.vehicleId});
  final Profile profile;
  final List<Vehicle> vehicles;
  final MaintenanceTask? task;
  final String? vehicleId;

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  late final t = widget.task;
  late String _vehicle = t?.vehicleId ??
      (widget.vehicles.any((v) => v.id == widget.vehicleId) ? widget.vehicleId! : widget.vehicles.first.id);
  late String _category = t?.category ?? 'General';
  late final _name = TextEditingController(text: t?.name ?? '');
  late final _months = TextEditingController(text: t?.intervalDays == null ? '' : '${(t!.intervalDays! / 30.44).round()}');
  late final _distance = TextEditingController(text: t?.intervalMileage?.toString() ?? '');
  late DateTime? _lastDone = t?.lastDoneAt;
  late final _lastMileage = TextEditingController(text: t?.lastDoneMileage?.toString() ?? '');
  late DateTime? _fixedDue = (t != null && t!.intervalDays == null) ? t!.nextDueAt : null;
  late final _remindDays = TextEditingController(text: '${t?.remindDaysBefore ?? 7}');
  late final _remindDist =
      TextEditingController(text: '${t?.remindMileageBefore ?? (widget.profile.distanceUnit == 'mi' ? 300 : 500)}');
  late final _notes = TextEditingController(text: t?.notes ?? '');
  String? _selectedPreset;
  bool _busy = false;

  String get unit => widget.profile.distanceUnit;

  void _applyPreset(Preset p) {
    setState(() {
      _selectedPreset = p.name;
      _name.text = p.name;
      _category = p.category;
      _months.text = p.months?.toString() ?? '';
      final km = p.km;
      _distance.text = km == null ? '' : '${unit == 'mi' ? ((km * 0.621371) / 500).round() * 500 : km}';
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, 'Name the service, e.g. Oil change.');
    final months = int.tryParse(_months.text.trim());
    final distance = int.tryParse(_distance.text.trim());
    if ((months == null || months <= 0) && (distance == null || distance <= 0) && _fixedDue == null) {
      return toast(context, 'Set a time interval, a distance interval, or a fixed due date.');
    }
    final vehicle = widget.vehicles.firstWhere((v) => v.id == _vehicle);
    final lastMileage = int.tryParse(_lastMileage.text.trim());

    // Keep interval days stable if the month count didn't change on edit.
    int? intervalDays;
    if (months != null && months > 0) {
      intervalDays = (t?.intervalDays != null && (t!.intervalDays! / 30.44).round() == months)
          ? t!.intervalDays
          : (months * 30.44).round();
    }
    final intervalMileage = (distance != null && distance > 0) ? distance : null;

    DateTime? nextDueAt = _fixedDue;
    if (nextDueAt == null && intervalDays != null) {
      final keep = t != null && _lastDone == null && t!.intervalDays == intervalDays && t!.nextDueAt != null;
      nextDueAt = keep ? t!.nextDueAt : (_lastDone ?? today()).add(Duration(days: intervalDays));
    }
    int? nextDueMileage;
    if (intervalMileage != null) {
      final keep = t != null && lastMileage == null && t!.intervalMileage == intervalMileage && t!.nextDueMileage != null;
      nextDueMileage = keep ? t!.nextDueMileage : (lastMileage ?? vehicle.mileage) + intervalMileage;
    }

    setState(() => _busy = true);
    try {
      await Repo.saveTask(t?.id, {
        'vehicle_id': _vehicle,
        'name': name,
        'category': _category,
        'interval_days': intervalDays,
        'interval_mileage': intervalMileage,
        'last_done_at': isoDate(_lastDone),
        'last_done_mileage': lastMileage,
        'next_due_at': isoDate(nextDueAt),
        'next_due_mileage': nextDueMileage,
        'remind_days_before': (int.tryParse(_remindDays.text.trim()) ?? 7).clamp(0, 365),
        'remind_mileage_before': (int.tryParse(_remindDist.text.trim()) ?? 500).clamp(0, 100000),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'last_notified_at': null,
      });
      if (mounted) {
        toast(context, t == null ? 'Reminder created.' : 'Reminder saved.');
        context.pop();
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return PageBody(maxWidth: 720, children: [
      if (t == null) ...[
        const Text('Quick start', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in maintenancePresets)
            ChoiceChip(label: Text(p.name), selected: _selectedPreset == p.name, onSelected: (_) => _applyPreset(p)),
        ]),
        const SizedBox(height: 20),
      ],
      ResponsiveGrid(children: [
        DropdownButtonFormField<String>(
          initialValue: _vehicle,
          decoration: const InputDecoration(labelText: 'Vehicle'),
          items: [for (final v in widget.vehicles) DropdownMenuItem(value: v.id, child: Text(v.name))],
          onChanged: (v) => setState(() => _vehicle = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: maintenanceCategories.contains(_category) ? _category : 'General',
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in maintenanceCategories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v!),
        ),
      ]),
      gap,
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'What needs maintaining?', hintText: 'Engine oil & filter change')),
      gap,
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.butter50,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Repeat every…', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.espresso)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(controller: _months, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Months', helperText: 'Blank = distance only')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(controller: _distance, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Distance ($unit)', helperText: 'Blank = time only')),
            ),
          ]),
          const SizedBox(height: 8),
          const Text('Whichever comes first triggers the reminder.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      gap,
      ResponsiveGrid(columns: 3, breakpoint: 640, children: [
        DateField(label: 'Last done on', hint: 'Blank if unknown', value: _lastDone, onChanged: (d) => setState(() => _lastDone = d)),
        TextField(controller: _lastMileage, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Last done at ($unit)', helperText: ' ')),
        DateField(label: 'Or a fixed due date', hint: 'Overrides the interval', value: _fixedDue, onChanged: (d) => setState(() => _fixedDue = d)),
      ]),
      gap,
      ResponsiveGrid(children: [
        TextField(controller: _remindDays, keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Remind me (days before)')),
        TextField(controller: _remindDist, keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Remind me ($unit before)')),
      ]),
      gap,
      TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes', hintText: 'Oil grade, part numbers, preferred shop…')),
      const SizedBox(height: 22),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : (t == null ? 'Create reminder' : 'Save reminder'))),
    ]);
  }
}
