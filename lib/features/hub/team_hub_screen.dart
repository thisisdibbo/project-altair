import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import 'calendar_screen.dart';
import 'expenses_screen.dart';
import 'hub_widgets.dart';
import 'inventory_screen.dart';
import 'polls_screen.dart';

/// The team's extra tools, opened from the grid button in the top bar.
class TeamHubScreen extends ConsumerWidget {
  const TeamHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextEventProvider);

    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return SubPage(
      title: 'TEAM HUB',
      children: [
        SectionCard(
          title: 'Tools',
          children: [
            SettingRow(
              icon: Icons.inventory_2_outlined,
              title: 'Inventory',
              subtitle: 'Parts and tools, where they are kept, who has them',
              onTap: () => open(const InventoryScreen()),
            ),
            SettingRow(
              icon: Icons.event_outlined,
              title: 'Calendar',
              subtitle: next == null
                  ? 'Meetings, test days and deadlines'
                  : 'Next: ${next.title} · '
                        '${countdownLabel(next.daysFrom(DateTime.now()))}',
              onTap: () => open(const CalendarScreen()),
            ),
            SettingRow(
              icon: Icons.receipt_long_outlined,
              title: 'Expenses',
              subtitle: 'What you bought for the team, to be paid back',
              onTap: () => open(const ExpensesScreen()),
            ),
            SettingRow(
              icon: Icons.how_to_vote_outlined,
              title: 'Polls',
              subtitle: 'Ask the team and vote',
              onTap: () => open(const PollsScreen()),
            ),
          ],
        ),
      ],
    );
  }
}
