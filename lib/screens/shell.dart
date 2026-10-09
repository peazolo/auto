import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/repo.dart';
import '../ui/logo.dart';
import '../ui/theme.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon, selectedIcon;
}

const _dests = [
  _Dest('Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Dest('Garage', Icons.directions_car_outlined, Icons.directions_car_rounded),
  _Dest('Service', Icons.build_outlined, Icons.build_rounded),
  _Dest('Documents', Icons.description_outlined, Icons.description_rounded),
  _Dest('AI Mechanic', Icons.auto_awesome_outlined, Icons.auto_awesome),
  _Dest('Alerts', Icons.notifications_none_rounded, Icons.notifications_rounded),
  _Dest('Settings', Icons.settings_outlined, Icons.settings_rounded),
];

/// Unread alert count, refreshed after every data change.
final unreadAlerts = ValueNotifier<int>(0);
Future<void> refreshUnread() async {
  try {
    unreadAlerts.value = await Repo.unreadCount();
  } catch (_) {}
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    refreshUnread();
    dataVersion.addListener(refreshUnread);
  }

  @override
  void dispose() {
    dataVersion.removeListener(refreshUnread);
    super.dispose();
  }

  void _go(int i) => widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final index = widget.shell.currentIndex;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          _SideNav(index: index, onTap: _go),
          Expanded(child: widget.shell),
        ]),
      );
    }
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 5 ? index : 0,
        onDestinationSelected: _go,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in _dests.take(5))
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon, color: AppColors.espresso),
              label: d.label == 'AI Mechanic' ? 'AI' : (d.label == 'Documents' ? 'Docs' : d.label),
            ),
        ],
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.index, required this.onTap});
  final int index;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      color: AppColors.espresso,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.only(left: 4, bottom: 28), child: Logo(light: true)),
        for (var i = 0; i < _dests.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: i == index ? AppColors.butter300 : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(children: [
                    Icon(i == index ? _dests[i].selectedIcon : _dests[i].icon,
                        size: 20, color: i == index ? AppColors.espresso : AppColors.butter100.withValues(alpha: 0.75)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_dests[i].label,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: i == index ? AppColors.espresso : AppColors.butter100.withValues(alpha: 0.8))),
                    ),
                    if (i == 5)
                      ValueListenableBuilder(
                        valueListenable: unreadAlerts,
                        builder: (_, n, _) => n == 0
                            ? const SizedBox()
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: i == index ? AppColors.espresso : AppColors.butter300,
                                    borderRadius: BorderRadius.circular(99)),
                                child: Text('$n',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: i == index ? AppColors.butter300 : AppColors.espresso)),
                              ),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        const Spacer(),
        Text(sb.auth.currentUser?.email ?? '', overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.butter100.withValues(alpha: 0.55), fontSize: 12)),
      ]),
    );
  }
}

/// App bar actions shown on phone layouts: alerts bell + settings.
class PhoneActions extends StatelessWidget {
  const PhoneActions({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= 900) return const SizedBox();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ValueListenableBuilder(
        valueListenable: unreadAlerts,
        builder: (_, n, _) => IconButton(
          tooltip: 'Alerts',
          onPressed: () => context.go('/alerts'),
          icon: Badge(isLabelVisible: n > 0, label: Text('$n'), backgroundColor: AppColors.caramel,
              child: const Icon(Icons.notifications_none_rounded)),
        ),
      ),
      IconButton(tooltip: 'Settings', onPressed: () => context.go('/settings'), icon: const Icon(Icons.settings_outlined)),
      const SizedBox(width: 4),
    ]);
  }
}
