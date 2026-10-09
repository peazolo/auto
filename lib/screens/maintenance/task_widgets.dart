import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';

List<MaintenanceTask> sortTasks(List<MaintenanceTask> tasks) {
  return [...tasks]..sort((a, b) {
      final sa = a.status(a.vehicle!.mileage).index, sb = b.status(b.vehicle!.mileage).index;
      if (sa != sb) return sa - sb;
      return (a.nextDueAt ?? DateTime(9999)).compareTo(b.nextDueAt ?? DateTime(9999));
    });
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.unit, required this.currency, this.showVehicle = true});
  final MaintenanceTask task;
  final String unit, currency;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final v = t.vehicle!;
    final remaining = t.nextDueMileage == null ? null : t.nextDueMileage! - v.mileage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.espresso, fontSize: 15)),
              taskStatusPill(t.status(v.mileage)),
            ]),
            const SizedBox(height: 2),
            Text(
              [t.category, if (showVehicle) v.name, if (t.lastDoneAt != null) 'last done ${fmtDate(t.lastDoneAt)}'].join(' · '),
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 16, runSpacing: 4, children: [
              if (t.nextDueAt != null)
                _Meta(Icons.event_rounded, '${fmtDate(t.nextDueAt)}  (${relativeDays(t.nextDueAt!)})'),
              if (remaining != null)
                _Meta(Icons.speed_rounded,
                    'at ${fmtNum(t.nextDueMileage)} $unit  (${remaining >= 0 ? '${fmtNum(remaining)} $unit to go' : '${fmtNum(-remaining)} $unit over'})'),
            ]),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.butter300,
                foregroundColor: AppColors.espresso,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => showCompleteSheet(context, t, unit, currency),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Mark done'),
            ),
          ]),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.muted),
          color: AppColors.paper,
          onSelected: (v) async {
            if (v == 'edit') context.push('/maintenance/${t.id}/edit');
            if (v == 'delete' &&
                await confirm(context, 'Delete reminder?', 'Delete “${t.name}”? Service history is kept.')) {
              await Repo.deleteTask(t.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      ]),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: AppColors.caramel),
      const SizedBox(width: 5),
      Flexible(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]);
  }
}

Future<void> showCompleteSheet(BuildContext context, MaintenanceTask t, String unit, String currency) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    builder: (_) => _CompleteSheet(task: t, unit: unit, currency: currency),
  );
}

class _CompleteSheet extends StatefulWidget {
  const _CompleteSheet({required this.task, required this.unit, required this.currency});
  final MaintenanceTask task;
  final String unit, currency;

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  DateTime _date = today();
  late final _mileage = TextEditingController(text: '${widget.task.vehicle!.mileage}');
  final _cost = TextEditingController();
  final _shop = TextEditingController();
  final _notes = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Repo.completeTask(
        widget.task.id,
        performedAt: _date,
        mileage: int.tryParse(_mileage.text.trim()),
        cost: double.tryParse(_cost.text.trim()),
        shop: _shop.text.trim(),
        notes: _notes.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Logged. Next reminder scheduled.');
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
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Log “${widget.task.name}”', style: display(22)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: DateField(label: 'Date done', value: _date, onChanged: (d) => setState(() => _date = d ?? today()), allowClear: false)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(controller: _mileage, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Odometer (${widget.unit})')),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(controller: _cost, keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Cost (${widget.currency})')),
          ),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _shop, decoration: const InputDecoration(labelText: 'Shop / mechanic'))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        const SizedBox(height: 18),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Logging…' : 'Log service')),
      ]),
    );
  }
}

class LogTile extends StatelessWidget {
  const LogTile({super.key, required this.log, required this.unit, required this.currency, this.showVehicle = true});
  final MaintenanceLog log;
  final String unit, currency;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final l = log;
    final meta = [
      if (showVehicle && l.vehicle != null) l.vehicle!.name,
      if (l.mileage != null) '${fmtNum(l.mileage)} $unit',
      ?l.shop,
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
      leading: SizedBox(
        width: 54,
        child: Text(fmtDate(l.performedAt).toUpperCase(),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.caramel)),
      ),
      title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([meta, ?l.notes].where((s) => s.isNotEmpty).join('\n'), style: const TextStyle(fontSize: 12)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (l.cost != null) Text(fmtMoney(l.cost, currency), style: const TextStyle(fontWeight: FontWeight.w700)),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
          onPressed: () async {
            if (await confirm(context, 'Delete record?', 'Delete this service record?')) await Repo.deleteLog(l.id);
          },
        ),
      ]),
    );
  }
}

/// Tappable date input with optional clear.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.allowClear = true, this.hint});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? today(),
          firstDate: DateTime(1990),
          lastDate: DateTime(2100),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          suffixIcon: value != null && allowClear
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => onChanged(null))
              : const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? '—' : fmtDate(value)),
      ),
    );
  }
}
