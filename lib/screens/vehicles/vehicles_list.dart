import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garage'), actions: const [PhoneActions()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/vehicles/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add vehicle'),
      ),
      body: Loader<(Profile, List<Vehicle>, List<MaintenanceTask>)>(
        load: () async => (await Repo.profile(), await Repo.vehicles(), await Repo.tasks()),
        builder: (context, d, reload) {
          final (profile, vehicles, tasks) = d;
          if (vehicles.isEmpty) {
            return PageBody(children: [
              Card(
                child: EmptyState(
                  icon: Icons.directions_car_rounded,
                  title: 'Your garage is empty',
                  body: 'Add your car to start tracking service, documents and repairs.',
                  action: FilledButton(onPressed: () => context.push('/vehicles/new'), child: const Text('Add your first vehicle')),
                ),
              ),
            ]);
          }
          return PageBody(onRefresh: reload, children: [
            ResponsiveGrid(columns: 3, breakpoint: 700, children: [
              for (final v in vehicles)
                _VehicleCard(
                  vehicle: v,
                  unit: profile.distanceUnit,
                  tasks: tasks.where((t) => t.vehicleId == v.id).toList(),
                ),
            ]),
            const SizedBox(height: 80),
          ]);
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.unit, required this.tasks});
  final Vehicle vehicle;
  final String unit;
  final List<MaintenanceTask> tasks;

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final overdue = tasks.where((t) => t.status(v.mileage) == DueStatus.overdue).length;
    final soon = tasks.where((t) => t.status(v.mileage) == DueStatus.dueSoon).length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/vehicles/${v.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 16 / 9, child: VehiclePhoto(v)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: display(20), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (v.nickname?.isNotEmpty ?? false)
                Text(v.fullName, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Pill('${fmtNum(v.mileage)} $unit', icon: Icons.speed_rounded),
                if (overdue > 0) Pill('$overdue overdue', color: AppColors.danger, bg: const Color(0xFFFBE7E2)),
                if (soon > 0) Pill('$soon due soon', color: AppColors.warn, bg: AppColors.butter100),
                if (overdue == 0 && soon == 0 && tasks.isNotEmpty) const Pill('All good', color: AppColors.good, bg: Color(0xFFE6F0E1)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The vehicle photo, or a warm placeholder.
class VehiclePhoto extends StatelessWidget {
  const VehiclePhoto(this.vehicle, {super.key});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context) {
    if (vehicle.photoPath != null) return StorageImage(vehicle.photoPath!);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.butter200, AppColors.caramel], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.directions_car_filled_rounded, size: 64, color: AppColors.brown700),
    );
  }
}
