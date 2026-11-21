import 'package:flutter/material.dart';

import '../glass/glass.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'buttons.dart';
import 'inputs.dart';

/// Glass bottom panel used for every form and detail view.
Future<R?> showAltairSheet<R>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => _SheetFrame(child: builder(sheetContext)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: GlassSurface(
        shadow: false,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: p.textFaint.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: T.display(context).copyWith(fontSize: 19, letterSpacing: 2),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle!, style: T.small(context)),
          ),
      ],
    ),
  );
}

class SheetActions extends StatelessWidget {
  const SheetActions({
    super.key,
    required this.confirmLabel,
    required this.onConfirm,
    this.busy = false,
    this.cancelLabel = 'Cancel',
  });

  final String confirmLabel;
  final VoidCallback? onConfirm;
  final bool busy;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: Row(
      children: [
        Expanded(
          child: GhostButton(
            label: cancelLabel,
            onPressed: busy ? null : () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: PrimaryButton(
            label: confirmLabel,
            busy: busy,
            onPressed: onConfirm,
          ),
        ),
      ],
    ),
  );
}

class Option<V> {
  const Option(this.value, this.label, {this.subtitle});

  final V value;
  final String label;
  final String? subtitle;
}

Future<V?> showOptionsSheet<V>(
  BuildContext context, {
  required String title,
  required List<Option<V>> options,
  V? selected,
}) {
  return showAltairSheet<V>(
    context,
    builder: (_) =>
        _OptionsSheet<V>(title: title, options: options, selected: selected),
  );
}

class _OptionsSheet<V> extends StatefulWidget {
  const _OptionsSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<Option<V>> options;
  final V? selected;

  @override
  State<_OptionsSheet<V>> createState() => _OptionsSheetState<V>();
}

class _OptionsSheetState<V> extends State<_OptionsSheet<V>> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : widget.options
              .where(
                (o) =>
                    o.label.toLowerCase().contains(q) ||
                    (o.subtitle ?? '').toLowerCase().contains(q),
              )
              .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetTitle(widget.title),
        if (widget.options.length > 7) ...[
          SearchField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
        ],
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('Nothing to choose yet.', style: T.body(context)),
            ),
          ),
        for (final option in shown)
          PressScale(
            scale: 0.985,
            onTap: () => Navigator.of(context).pop(option.value),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: option.value == widget.selected
                    ? p.accent.withValues(alpha: 0.14)
                    : p.surfaceHigh.withValues(alpha: p.isDark ? 0.45 : 0.9),
                border: Border.all(
                  color: option.value == widget.selected
                      ? p.accent.withValues(alpha: 0.7)
                      : p.line,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label, style: T.strong(context)),
                        if (option.subtitle != null &&
                            option.subtitle!.isNotEmpty)
                          Text(option.subtitle!, style: T.small(context)),
                      ],
                    ),
                  ),
                  if (option.value == widget.selected)
                    Icon(Icons.check_rounded, size: 20, color: p.accentText),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
