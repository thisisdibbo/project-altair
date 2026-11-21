import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/core.dart';

/// Short names of the dashboards, in swipe order.
const dashboardNames = <String>[
  'Tasks',
  'History',
  'Notes',
  'Moderators',
  'Advisors',
  'Leads',
  'Seniors',
  'Juniors',
];

/// Which dashboard is in view. [visit] goes up on every arrival, so a
/// dashboard can replay its title reveal each time it comes into view.
@immutable
class DashboardNav {
  const DashboardNav(this.index, this.visit);

  final int index;
  final int visit;
}

class DashboardNavNotifier extends Notifier<DashboardNav> {
  @override
  DashboardNav build() => const DashboardNav(0, 0);

  void show(int index) => state = DashboardNav(index, state.visit + 1);
}

final dashboardNavProvider =
    NotifierProvider<DashboardNavNotifier, DashboardNav>(
      DashboardNavNotifier.new,
    );

/// Space taken by the floating top bar and the navigation, so each
/// dashboard can scroll underneath them, plus the "portal" jump.
class ShellInsets extends InheritedWidget {
  const ShellInsets({
    super.key,
    required this.top,
    required this.bottom,
    required this.travel,
    required super.child,
  });

  final double top;
  final double bottom;

  /// Jumps to a dashboard through the portal, which opens at [origin]
  /// (a point on the screen).
  final void Function(int index, Offset origin) travel;

  static ShellInsets of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellInsets>()!;

  @override
  bool updateShouldNotify(ShellInsets old) =>
      old.top != top || old.bottom != bottom;
}

/// Screen position of the middle of a widget.
Offset centerOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return Offset.zero;
  return box.localToGlobal(box.size.center(Offset.zero));
}

/// Common frame of the dashboards: index tag, "next" portal chip, giant
/// title, a strip of key numbers, pull-to-refresh, centred content on
/// tablets and an optional floating PLUS button.
class DashboardScaffold extends ConsumerWidget {
  const DashboardScaffold({
    super.key,
    required this.index,
    required this.title,
    required this.facts,
    required this.slivers,
    required this.onRefresh,
    this.fab,
  });

  /// Position among the dashboards (0 = Tasks).
  final int index;

  /// Shown in giant capitals. Use a line break between two words.
  final String title;

  /// Key numbers as (value, label). Empty while loading.
  final List<(String, String)> facts;
  final List<Widget> slivers;
  final Future<void> Function() onRefresh;
  final Widget? fab;

  static String _tag(int i) => '[${(i + 1).toString().padLeft(2, '0')}]';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final insets = ShellInsets.of(context);
    final nav = ref.watch(dashboardNavProvider);
    final trigger = nav.index == index ? nav.visit : -1;
    final next = (index + 1) % dashboardNames.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = math.max(16.0, (constraints.maxWidth - 760) / 2);
        final width = constraints.maxWidth - 2 * pad - 8;
        final titleSize = (width * 0.2).clamp(46.0, 104.0).toDouble();
        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: onRefresh,
              color: p.onAccent,
              backgroundColor: p.accent,
              edgeOffset: insets.top,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      pad + 4,
                      insets.top + 18,
                      pad + 4,
                      16,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _tag(index),
                                style: T.mono(
                                  context,
                                  size: 13,
                                  color: p.accentText,
                                ),
                              ),
                              const Spacer(),
                              _NextChip(
                                label:
                                    '${_tag(next)} '
                                    '${dashboardNames[next].toUpperCase()}',
                                onTap: (origin) => insets.travel(next, origin),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Reveal(
                            trigger: trigger,
                            blur: 12,
                            offset: Offset(0, titleSize * 0.28),
                            duration: const Duration(milliseconds: 1050),
                            curve: Motion.expo,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.topLeft,
                              child: Text(
                                title,
                                semanticsLabel: title.replaceAll('\n', ' '),
                                style: T.giant(context, titleSize),
                              ),
                            ),
                          ),
                          if (facts.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _FactStrip(facts: facts, trigger: trigger),
                          ],
                        ],
                      ),
                    ),
                  ),
                  for (final sliver in slivers)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: pad),
                      sliver: sliver,
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: insets.bottom + 104),
                  ),
                ],
              ),
            ),
            if (fab != null)
              Positioned(
                right: pad + 2,
                bottom: insets.bottom + 16,
                child: fab!,
              ),
          ],
        );
      },
    );
  }
}

/// "NEXT [02] HISTORY" - opens the portal to the following dashboard.
class _NextChip extends StatelessWidget {
  const _NextChip({required this.label, required this.onTap});

  final String label;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.94,
      haptic: false,
      semanticLabel: 'Next dashboard, $label',
      onTap: () => onTap(centerOf(context)),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 9, 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: p.text.withValues(alpha: 0.06),
          border: Border.all(color: p.text.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('NEXT', style: T.label(context).copyWith(fontSize: 9.5)),
            const SizedBox(width: 8),
            Text(label, style: T.mono(context, size: 11.5)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 14, color: p.accentText),
          ],
        ),
      ),
    );
  }
}

/// Key numbers under the title, divided by hairlines, rising in one by one.
class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.facts, required this.trigger});

  final List<(String, String)> facts;
  final int trigger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: p.line)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < facts.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, thickness: 1, color: p.line),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(i == 0 ? 0 : 14, 10, 8, 10),
                  child: Reveal(
                    trigger: trigger,
                    delay: Duration(milliseconds: 160 + 90 * i),
                    offset: const Offset(0, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            facts[i].$1,
                            maxLines: 1,
                            style: T.mono(context, size: 19),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          facts[i].$2.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.label(context).copyWith(fontSize: 9.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fades and lifts a list item into place, slightly later for each index.
class Appear extends StatelessWidget {
  const Appear({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (Motion.off(context)) return child;
    final delay = 55 * math.min<int>(index, 8);
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Motion.soft),
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0).toDouble(),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - v)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A row of filter pills that scrolls sideways instead of overflowing.
class PillRow extends StatelessWidget {
  const PillRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          children[i],
        ],
      ],
    ),
  );
}

class IdName {
  const IdName(this.id, this.name);

  final String id;
  final String name;
}

/// Opens a filter list with an "all" entry on top.
/// Returns null when dismissed and an empty id when "all" was chosen.
Future<IdName?> pickFilter(
  BuildContext context, {
  required String title,
  required String allLabel,
  required List<IdName> items,
  String? selectedId,
}) async {
  final id = await showOptionsSheet<String>(
    context,
    title: title,
    selected: selectedId ?? '',
    options: [
      Option('', allLabel),
      for (final item in items) Option(item.id, item.name),
    ],
  );
  if (id == null) return null;
  if (id.isEmpty) return const IdName('', '');
  return items.firstWhere(
    (item) => item.id == id,
    orElse: () => const IdName('', ''),
  );
}
