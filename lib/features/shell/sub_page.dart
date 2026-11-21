import 'package:flutter/material.dart';

import '../../core/core.dart';

/// Frame for screens opened on top of the dashboards
/// (profile, settings, administrator panel).
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    return Scaffold(
      body: AmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, safe.top + 10, 16, 6),
                  child: Row(
                    children: [
                      RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.display(
                            context,
                          ).copyWith(fontSize: 20, letterSpacing: 2.2),
                        ),
                      ),
                      if (action != null) action!,
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 12, 16, safe.bottom + 28),
                    children: children,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled frosted block of settings rows.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FrostCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              title.toUpperCase(),
              style: T.label(
                context,
              ).copyWith(color: context.palette.accentText),
            ),
          ),
          ...children,
        ],
      ),
    ),
  );
}
