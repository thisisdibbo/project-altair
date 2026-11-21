import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/core.dart';
import 'calendar_screen.dart';
import 'expenses_screen.dart';
import 'inventory_screen.dart';
import 'polls_screen.dart';

/// Where a tool is while the fan opens: its centre, measured from the
/// screen's left and bottom edges, how far it has grown (0 to 1, a little
/// over 1 while it overshoots), and how big its icon is.
typedef _Spot = ({double x, double y, double grow, double size});

/// The orange quick button on the left, above the navigation dial.
/// Tapping it fans the team tools out in a curve; tapping a tool opens it.
class QuickTools extends StatefulWidget {
  const QuickTools({super.key, required this.dialTop});

  /// Height of the navigation dial's top edge above the bottom of the
  /// screen, at [x] from the left edge. The button sits just above it.
  final double Function(double x) dialTop;

  static const left = 16.0;
  static const size = 54.0;

  /// Horizontal middle of the button.
  static const centreX = left + size / 2;

  @override
  State<QuickTools> createState() => _QuickToolsState();
}

class _QuickToolsState extends State<QuickTools>
    with SingleTickerProviderStateMixin {
  static const _tools = <(IconData, String)>[
    (Icons.inventory_2_outlined, 'Inventory'),
    (Icons.event_outlined, 'Calendar'),
    (Icons.receipt_long_outlined, 'Expenses'),
    (Icons.how_to_vote_outlined, 'Polls'),
  ];

  /// The curve the tools fan out on: their distance from the button, and
  /// each one's angle, from straight up to low on the right.
  static const _reach = 220.0;
  static const _angles = [90.0, 66.0, 40.0, 14.0];

  late final _fan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  bool _open = false;

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _fan.duration = Motion.off(context)
        ? Duration.zero
        : const Duration(milliseconds: 320);
    if (_open) {
      _fan.forward();
    } else {
      _fan.reverse();
    }
  }

  void _openTool(int i) {
    _toggle();
    final page = switch (i) {
      0 => const InventoryScreen(),
      1 => const CalendarScreen(),
      2 => const ExpensesScreen(),
      _ => const PollsScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// True when the dial is not under the button (landscape and wide
  /// screens): the button then sits low, beside the dial.
  bool get _beside {
    final raised = widget.dialTop(QuickTools.left + QuickTools.size);
    return raised - widget.dialTop(0) < 1;
  }

  /// Where each tool ends up, measured from the middle of the button, and
  /// how big the tool icons are.
  ///
  /// Above the dial (a phone held upright) the tools fan out in a curve to
  /// the upper right, with names under the icons. Beside the dial there is
  /// little height, so they rise in a gently curved column with names on
  /// the right, starting high enough to clear the dial's slope and moving
  /// closer together on short screens.
  (List<Offset>, double) _shape(double height, double centreY) {
    if (!_beside) {
      return (
        [
          for (final a in _angles)
            Offset(
              _reach * math.cos(a * math.pi / 180),
              _reach * math.sin(a * math.pi / 180),
            ),
        ],
        48.0,
      );
    }
    final ceiling = height - MediaQuery.paddingOf(context).top - 76;
    final first = math.max(
      centreY + 58,
      widget.dialTop(QuickTools.centreX + 140) + 30,
    );
    final gap = ((ceiling - 24 - first) / 3).clamp(46.0, 58.0).toDouble();
    return (
      [
        // Inventory on top and Polls nearest the button, as in the fan.
        for (var k = 0; k < _tools.length; k++)
          Offset(
            k == 0 || k == 3 ? 8 : 20,
            first - centreY + gap * (_tools.length - 1 - k),
          ),
      ],
      math.min(48.0, gap - 6),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => _layer(context, box.maxHeight),
  );

  Widget _layer(BuildContext context, double height) {
    final p = context.palette;
    final bottom = widget.dialTop(QuickTools.left + QuickTools.size) + 10;
    final centreY = bottom + QuickTools.size / 2;
    final (ends, size) = _shape(height, centreY);
    final beside = _beside;
    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _open) _toggle();
      },
      child: AnimatedBuilder(
        animation: _fan,
        builder: (context, _) {
          final t = _fan.value;
          final spots = [
            for (var i = 0; i < _tools.length; i++)
              _spot(i, t, centreY, ends[i], size),
          ];
          return Stack(
            children: [
              if (t > 0)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggle,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.45 * t),
                    ),
                  ),
                ),
              if (t > 0) ...[
                for (var i = 0; i < _tools.length; i++)
                  _icon(context, i, spots[i]),
                // Every label is drawn above every icon, so a label can
                // never slip behind the next tool.
                for (var i = 0; i < _tools.length; i++)
                  _label(context, i, spots[i], beside),
              ],
              Positioned(
                left: QuickTools.left,
                bottom: bottom,
                child: PressScale(
                  onTap: _toggle,
                  semanticLabel: _open ? 'Close team tools' : 'Team tools',
                  child: Container(
                    width: QuickTools.size,
                    height: QuickTools.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.accent,
                      boxShadow: [
                        BoxShadow(
                          color: p.accent.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle: t * math.pi / 2,
                      child: Icon(
                        t < 0.5 ? Icons.apps_rounded : Icons.close_rounded,
                        color: p.onAccent,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tools leave the button one after another and overshoot their place a
  /// little before settling.
  _Spot _spot(int i, double t, double centreY, Offset end, double size) {
    final step = ((t - i * 0.1) / 0.6).clamp(0.0, 1.0).toDouble();
    final grow = Curves.easeOutBack.transform(step);
    return (
      x: QuickTools.centreX + end.dx * grow,
      y: centreY + end.dy * grow,
      grow: grow,
      size: size,
    );
  }

  Widget _icon(BuildContext context, int i, _Spot at) {
    final p = context.palette;
    final (icon, label) = _tools[i];
    return Positioned(
      left: at.x - at.size / 2,
      bottom: at.y - at.size / 2,
      width: at.size,
      height: at.size,
      child: Opacity(
        opacity: at.grow.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(
          scale: 0.4 + 0.6 * at.grow,
          child: PressScale(
            onTap: () => _openTool(i),
            semanticLabel: label,
            child: GlassSurface(
              radius: at.size / 2,
              child: Center(child: Icon(icon, color: p.accent, size: 22)),
            ),
          ),
        ),
      ),
    );
  }

  /// The tool's name, under its icon (or to its right when the tools rise
  /// in a column), on a small dark backing so it stays readable over
  /// anything behind it.
  Widget _label(BuildContext context, int i, _Spot at, bool beside) {
    final name = Opacity(
      opacity: at.grow.clamp(0.0, 1.0).toDouble(),
      child: PressScale(onTap: () => _openTool(i), child: _name(context, i)),
    );
    if (beside) {
      return Positioned(
        left: at.x + at.size / 2 + 6,
        bottom: at.y,
        child: FractionalTranslation(
          translation: const Offset(0, 0.5),
          child: name,
        ),
      );
    }
    return Positioned(
      left: at.x - 60,
      width: 120,
      bottom: at.y - at.size / 2 - 4,
      child: FractionalTranslation(
        translation: const Offset(0, 1),
        child: Align(heightFactor: 1, child: name),
      ),
    );
  }

  Widget _name(BuildContext context, int i) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.bgDeep.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _tools[i].$2,
        maxLines: 1,
        style: T.small(
          context,
        ).copyWith(color: p.text, fontWeight: FontWeight.w700),
      ),
    );
  }
}
