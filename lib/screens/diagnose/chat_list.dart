import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/format.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../shell.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Mechanic'), actions: const [PhoneActions()]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/diagnose/new'),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('New diagnosis'),
      ),
      body: Loader<List<DiagnosisChat>>(
        load: Repo.chats,
        builder: (context, chats, reload) => PageBody(onRefresh: reload, children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.espresso, AppColors.brown700], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome, color: AppColors.butter300, size: 30),
              const SizedBox(height: 10),
              Text("What's wrong with your car?", style: display(26, color: AppColors.butter50)),
              const SizedBox(height: 6),
              const Text(
                'Snap a photo of a warning light, leak or worn part, record a short video of a strange noise, or just describe it. '
                "You'll get likely causes, how urgent it is, and what to do next.",
                style: TextStyle(color: AppColors.butter200, height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.butter300, foregroundColor: AppColors.espresso),
                onPressed: () => context.push('/diagnose/new'),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Start a diagnosis'),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Past conversations',
            child: chats.isEmpty
                ? const EmptyState(icon: Icons.forum_outlined, title: 'No conversations yet')
                : Column(children: [
                    for (final c in chats)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.butter100,
                          foregroundColor: AppColors.brown600,
                          child: Icon(Icons.chat_bubble_outline_rounded, size: 20),
                        ),
                        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text([if (c.vehicle != null) c.vehicle!.name, timeAgo(c.updatedAt)].join(' · ')),
                        onTap: () => context.push('/diagnose/${c.id}'),
                        trailing: IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            if (!await confirm(context, 'Delete this conversation?', 'Its messages and photos will be removed.')) return;
                            try {
                              await Repo.deleteChat(c.id);
                            } catch (e) {
                              if (context.mounted) toast(context, friendlyError(e));
                            }
                          },
                        ),
                      ),
                  ]),
          ),
          const SizedBox(height: 12),
          const Text(
            'AI guidance can be wrong. For brakes, steering, airbags, fuel smells or overheating, stop driving and have a qualified mechanic check the car.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}
