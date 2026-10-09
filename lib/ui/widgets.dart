import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repo.dart';
import 'theme.dart';

/// Loads data with [load], reloads whenever [dataVersion] changes, and shows
/// loading / error states consistently.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
    dataVersion.addListener(_reload);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator(color: AppColors.caramel)));
    }
    if (_error != null && _data == null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load this",
        body: 'Check your connection and try again.',
        action: FilledButton(onPressed: () {
          setState(() => _loading = true);
          _reload();
        }, child: const Text('Retry')),
      );
    }
    return widget.builder(context, _data as T, _reload);
  }
}

/// Centered content column with a max width, used by every page.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1000, this.onRefresh, this.padding});
  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(color: AppColors.caramel, onRefresh: onRefresh!, child: list);
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.subtitle, this.action, required this.child, this.padding});
  final String? title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.espresso)),
                    if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                ?action,
              ]),
            ),
            const Divider(),
          ],
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: AppColors.butter100, borderRadius: BorderRadius.circular(16)),
          child: Icon(icon, color: AppColors.brown600),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.espresso)),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = AppColors.brown600, this.bg, this.icon});
  final String label;
  final Color color;
  final Color? bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg ?? color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

Widget taskStatusPill(DueStatus s) => switch (s) {
      DueStatus.overdue => const Pill('Overdue', color: AppColors.danger, icon: Icons.warning_amber_rounded),
      DueStatus.dueSoon => const Pill('Due soon', color: Color(0xFF8A5C0C), bg: Color(0x26C98A1B), icon: Icons.schedule),
      DueStatus.ok => const Pill('On track', color: AppColors.good, icon: Icons.check_circle_outline),
      DueStatus.unscheduled => const Pill('No schedule', icon: Icons.radio_button_unchecked),
    };

Widget docStatusPill(DocStatus s) => switch (s) {
      DocStatus.expired => const Pill('Expired', color: AppColors.danger, icon: Icons.warning_amber_rounded),
      DocStatus.expiring => const Pill('Expiring soon', color: Color(0xFF8A5C0C), bg: Color(0x26C98A1B), icon: Icons.schedule),
      DocStatus.valid => const Pill('Valid', color: AppColors.good, icon: Icons.check_circle_outline),
      DocStatus.noExpiry => const Pill('No expiry'),
    };

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle, this.action});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: display(30)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: const TextStyle(color: AppColors.muted)),
            ],
          ]),
        ),
        ?action,
      ]),
    );
  }
}

/// Signed-URL image for a private storage path.
class StorageImage extends StatefulWidget {
  const StorageImage(this.path, {super.key, this.fit = BoxFit.cover, this.width, this.height});
  final String path;
  final BoxFit fit;
  final double? width, height;

  @override
  State<StorageImage> createState() => _StorageImageState();
}

class _StorageImageState extends State<StorageImage> {
  late Future<String> _url = Repo.fileUrl(widget.path);

  @override
  void didUpdateWidget(StorageImage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _url = Repo.fileUrl(widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width, h = widget.height;
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (!snap.hasData) return Container(width: w, height: h, color: AppColors.butter100);
        return Image.network(snap.data!, fit: widget.fit, width: w, height: h,
            errorBuilder: (_, _, _) => Container(width: w, height: h, color: AppColors.butter100,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.muted)));
      },
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String body, {String action = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: AppColors.paper,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));

String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
    return 'No connection. Check your internet and try again.';
  }
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  return m?.group(1) ?? 'Something went wrong. Please try again.';
}

/// Small helper for form fields with a label above.
class LabeledField extends StatelessWidget {
  const LabeledField(this.label, this.child, {super.key, this.hint});
  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
      const SizedBox(height: 6),
      child,
      if (hint != null) ...[
        const SizedBox(height: 4),
        Text(hint!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ],
    ]);
  }
}

/// Lays children out in 1 column on phones and [columns] on wide screens.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({super.key, required this.children, this.columns = 2, this.gap = 14, this.breakpoint = 560, this.narrowColumns = 1});
  final List<Widget> children;
  final int columns;
  final int narrowColumns;
  final double gap;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= breakpoint ? columns : narrowColumns;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}
