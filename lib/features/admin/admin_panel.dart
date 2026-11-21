import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import 'admin_sub_teams.dart';
import 'admin_users.dart';
import 'join_requests_section.dart';

/// Administrator control panel. Only Super Admins can open it, and every
/// action behind it is checked again on the server.
class AdminPanel extends ConsumerWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    if (!(perms?.openAdminPanel ?? false)) {
      return const SubPage(
        title: 'ADMIN CONTROL',
        children: [
          EmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Administrators only',
            message: 'Your account does not have access to this area.',
          ),
        ],
      );
    }
    final users = ref.watch(usersProvider).value ?? const <AppUser>[];
    final teams = ref.watch(subTeamsProvider).value ?? const <SubTeam>[];
    final disabled = users.where((u) => u.disabled).length;

    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return SubPage(
      title: 'ADMIN CONTROL',
      children: [
        const JoinRequestsSection(),
        SectionCard(
          title: 'Accounts and structure',
          children: [
            SettingRow(
              icon: Icons.manage_accounts_outlined,
              title: 'User accounts',
              subtitle:
                  '${users.length} accounts'
                  '${disabled == 0 ? '' : ' · $disabled disabled'}'
                  ' · create, roles, passwords, disable',
              onTap: () => open(const AdminUsersScreen()),
            ),
            SettingRow(
              icon: Icons.hub_outlined,
              title: 'Sub-teams',
              subtitle: '${teams.length} configured · add, rename, reorder',
              onTap: () => open(const AdminSubTeamsScreen()),
            ),
            SettingRow(
              icon: Icons.receipt_long_outlined,
              title: 'Application activity',
              subtitle: 'Who changed what, and when',
              onTap: () => open(const AdminActivityScreen()),
            ),
          ],
        ),
        SectionCard(
          title: 'Content you manage from the dashboards',
          children: [
            for (final row in const [
              (
                Icons.precision_manufacturing_outlined,
                'Tasks',
                'Edit or delete from the ··· button on any task card',
              ),
              (
                Icons.history_rounded,
                'Task history',
                'Open a record, then Edit or Delete',
              ),
              (
                Icons.campaign_outlined,
                'Shared notes',
                'Pin, edit or delete any note from its ··· button',
              ),
              (
                Icons.groups_2_outlined,
                'Team leads, senior and junior members',
                'Expand a profile for Edit and Delete, or use + to add',
              ),
            ])
              SettingRow(icon: row.$1, title: row.$2, subtitle: row.$3),
          ],
        ),
      ],
    );
  }
}

class AdminActivityScreen extends ConsumerWidget {
  const AdminActivityScreen({super.key});

  IconData _icon(String type) {
    if (type.startsWith('task')) return Icons.precision_manufacturing_outlined;
    if (type.startsWith('note')) return Icons.campaign_outlined;
    if (type.startsWith('member')) return Icons.groups_2_outlined;
    if (type.startsWith('user')) return Icons.manage_accounts_outlined;
    return Icons.bolt_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activityProvider);
    final items = state.value ?? const <ActivityLog>[];
    return SubPage(
      title: 'ACTIVITY',
      children: [
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 62, count: 6)
        else if (state.value == null && state.hasError)
          ErrorState(
            message: friendlyError(state.error!),
            onRetry: () => ref.invalidate(activityProvider),
          )
        else if (items.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No activity yet',
            message: 'Changes made in the app are listed here.',
          )
        else
          FrostCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: [
                for (final log in items)
                  SettingRow(
                    icon: _icon(log.type),
                    title: log.message,
                    subtitle: [
                      if (log.actorName.isNotEmpty) log.actorName,
                      formatFriendly(log.createdAt),
                    ].join(' · '),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
