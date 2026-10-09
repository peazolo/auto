import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'documents_list.dart';

class DocumentDetailScreen extends StatelessWidget {
  const DocumentDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _open(BuildContext context, CarDocument d, {bool download = false}) async {
    try {
      final url = await Repo.fileUrl(d.filePath!, download: download);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  Future<void> _delete(BuildContext context, CarDocument d) async {
    if (!await confirm(context, 'Delete this document?', '"${d.title}" and its file will be removed permanently.')) return;
    try {
      await Repo.deleteDocument(d);
      if (context.mounted) {
        toast(context, 'Document deleted.');
        context.go('/documents');
      }
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Loader<CarDocument?>(
      load: () => Repo.document(id),
      builder: (context, d, reload) {
        if (d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Document not found',
              action: FilledButton(onPressed: () => context.go('/documents'), child: const Text('All documents')),
            ),
          );
        }
        Widget row(String k, String? v) => v == null || v.isEmpty
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120, child: Text(k, style: const TextStyle(color: AppColors.muted))),
                  Expanded(child: SelectableText(v, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              );
        final days = d.expiresAt == null ? null : daysUntil(d.expiresAt!);
        return Scaffold(
          appBar: AppBar(
            title: Text(d.title),
            actions: [
              IconButton(tooltip: 'Edit', onPressed: () => context.push('/documents/${d.id}/edit'), icon: const Icon(Icons.edit_outlined)),
              IconButton(tooltip: 'Delete', onPressed: () => _delete(context, d), icon: const Icon(Icons.delete_outline)),
            ],
          ),
          body: PageBody(maxWidth: 820, onRefresh: reload, children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(backgroundColor: AppColors.butter100, foregroundColor: AppColors.brown600, child: Icon(docIcon(d))),
                    const SizedBox(width: 12),
                    Expanded(child: Text(d.typeLabel, style: const TextStyle(color: AppColors.muted))),
                    docStatusPill(d.status),
                  ]),
                  if (days != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      days < 0 ? 'Expired ${-days} day${days == -1 ? '' : 's'} ago' : (days == 0 ? 'Expires today' : 'Expires in $days day${days == 1 ? '' : 's'}'),
                      style: display(24, color: days < 0 ? AppColors.danger : AppColors.espresso),
                    ),
                    Text('Reminder ${d.remindDaysBefore} days before expiry', style: const TextStyle(color: AppColors.muted)),
                  ],
                  const Divider(height: 28),
                  row('Vehicle', d.vehicle?.name ?? 'Not linked'),
                  row('Number', d.number),
                  row('Issued by', d.issuer),
                  row('Issued on', d.issuedAt == null ? null : fmtDate(d.issuedAt)),
                  row('Expires on', d.expiresAt == null ? 'No expiry' : fmtDate(d.expiresAt)),
                  row('Notes', d.notes),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            if (d.filePath == null)
              Card(
                child: EmptyState(
                  icon: Icons.upload_file_rounded,
                  title: 'No file attached',
                  action: OutlinedButton(onPressed: () => context.push('/documents/${d.id}/edit'), child: const Text('Attach a file')),
                ),
              )
            else
              SectionCard(
                title: d.fileName ?? 'File',
                subtitle: d.fileSize == null ? null : '${(d.fileSize! / 1024).toStringAsFixed(0)} KB',
                action: Wrap(children: [
                  IconButton(tooltip: 'Open', onPressed: () => _open(context, d), icon: const Icon(Icons.open_in_new_rounded)),
                  IconButton(tooltip: 'Download', onPressed: () => _open(context, d, download: true), icon: const Icon(Icons.download_rounded)),
                ]),
                child: d.isImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(onTap: () => _open(context, d), child: StorageImage(d.filePath!, fit: BoxFit.contain)),
                      )
                    : InkWell(
                        onTap: () => _open(context, d),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(color: AppColors.butter50, borderRadius: BorderRadius.circular(12)),
                          child: Column(children: [
                            Icon(d.isPdf ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, size: 48, color: AppColors.brown600),
                            const SizedBox(height: 8),
                            const Text('Tap to open'),
                          ]),
                        ),
                      ),
              ),
          ]),
        );
      },
    );
  }
}
