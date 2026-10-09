import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../data/repo.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

IconData _icon(String kind) => switch (kind) {
      'task-due' || 'task-overdue' => Icons.build_rounded,
      'doc-expiring' || 'doc-expired' => Icons.description_rounded,
      'welcome' => Icons.waving_hand_rounded,
      _ => Icons.notifications_rounded,
    };

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) toast(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: Loader<List<AppNotification>>(
        load: Repo.notifications,
        builder: (context, items, reload) {
          final unread = items.where((n) => n.readAt == null).length;
          final read = items.length - unread;
          return PageBody(maxWidth: 760, onRefresh: reload, children: [
            Row(children: [
              Expanded(
                child: Text(unread == 0 ? "You're all caught up." : '$unread unread',
                    style: const TextStyle(color: AppColors.muted)),
              ),
              if (unread > 0) TextButton(onPressed: () => _run(context, Repo.markAllRead), child: const Text('Mark all read')),
              if (read > 0)
                TextButton(
                  onPressed: () async {
                    if (await confirm(context, 'Clear read alerts?', 'Read alerts will be removed.', action: 'Clear')) {
                      if (context.mounted) await _run(context, Repo.clearRead);
                    }
                  },
                  child: const Text('Clear read'),
                ),
            ]),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Card(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No alerts',
                  body: "We'll let you know here (and by email) when service is due or a document is about to expire.",
                ),
              )
            else
              Card(
                child: Column(children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _AlertTile(n: items[i]),
                  ],
                ]),
              ),
          ]);
        },
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.n});
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final unread = n.readAt == null;
    return Container(
      color: unread ? AppColors.butter50 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: unread ? AppColors.butter200 : AppColors.butter100,
          foregroundColor: AppColors.brown700,
          child: Icon(_icon(n.kind), size: 20),
        ),
        title: Text(n.title, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 2),
          Text(n.body),
          const SizedBox(height: 4),
          Text(timeAgo(n.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        trailing: unread
            ? IconButton(
                tooltip: 'Mark read',
                onPressed: () => Repo.markRead(n.id),
                icon: const Icon(Icons.done_rounded, size: 20),
              )
            : null,
        onTap: () async {
          if (unread) {
            try {
              await Repo.markRead(n.id);
            } catch (_) {}
          }
          if (n.link != null && n.link!.startsWith('/') && context.mounted) context.go(n.link!);
        },
      ),
    );
  }
}
