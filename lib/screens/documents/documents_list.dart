import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell.dart';

IconData docIcon(CarDocument d) => switch (d.type) {
      'drivers_license' => Icons.badge_outlined,
      'insurance' => Icons.shield_outlined,
      'registration' => Icons.assignment_outlined,
      'roadworthiness' || 'inspection' => Icons.fact_check_outlined,
      'emissions' => Icons.eco_outlined,
      'warranty' => Icons.verified_outlined,
      'receipt' => Icons.receipt_long_outlined,
      _ => Icons.description_outlined,
    };

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key, this.vehicleId});
  final String? vehicleId;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late String? _vehicle = widget.vehicleId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents'), actions: const [PhoneActions()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/documents/new${_vehicle != null ? '?vehicle=$_vehicle' : ''}'),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Add document'),
      ),
      body: Loader<(List<Vehicle>, List<CarDocument>)>(
        load: () async => (await Repo.vehicles(), await Repo.documents()),
        builder: (context, d, reload) {
          final (vehicles, all) = d;
          final docs = all.where((x) => _vehicle == null || x.vehicleId == _vehicle).toList();
          final expired = docs.where((x) => x.status == DocStatus.expired).length;
          final expiring = docs.where((x) => x.status == DocStatus.expiring).length;
          return PageBody(onRefresh: reload, children: [
            const Text('Keep licences, insurance and papers in one place. We remind you before they expire.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 14),
            if (vehicles.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(label: const Text('All'), selected: _vehicle == null, onSelected: (_) => setState(() => _vehicle = null)),
                  for (final v in vehicles)
                    ChoiceChip(label: Text(v.name), selected: _vehicle == v.id, onSelected: (_) => setState(() => _vehicle = v.id)),
                ]),
              ),
            if (expired + expiring > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: expired > 0 ? const Color(0xFFFBE7E2) : AppColors.butter100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: expired > 0 ? AppColors.danger : AppColors.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text([
                      if (expired > 0) '$expired expired',
                      if (expiring > 0) '$expiring expiring soon',
                    ].join(' · ')),
                  ),
                ]),
              ),
            if (docs.isEmpty)
              Card(
                child: EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No documents yet',
                  body: "Upload a photo or PDF of your driver's licence, insurance or registration and set an expiry reminder.",
                  action: FilledButton(onPressed: () => context.push('/documents/new'), child: const Text('Add a document')),
                ),
              )
            else
              Card(
                child: Column(children: [
                  for (var i = 0; i < docs.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _DocTile(doc: docs[i], showVehicle: vehicles.length > 1),
                  ],
                ]),
              ),
            const SizedBox(height: 80),
          ]);
        },
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc, required this.showVehicle});
  final CarDocument doc;
  final bool showVehicle;

  @override
  Widget build(BuildContext context) {
    final sub = [
      doc.typeLabel,
      if (showVehicle && doc.vehicle != null) doc.vehicle!.name,
      if (doc.expiresAt != null) 'Expires ${fmtDate(doc.expiresAt)} (${relativeDays(doc.expiresAt!)})' else 'No expiry',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: AppColors.butter100,
        foregroundColor: AppColors.brown600,
        child: Icon(docIcon(doc)),
      ),
      title: Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub),
      trailing: docStatusPill(doc.status),
      onTap: () => context.go('/documents/${doc.id}'),
    );
  }
}
