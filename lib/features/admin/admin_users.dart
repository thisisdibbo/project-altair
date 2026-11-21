import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import '../tasks/task_widgets.dart';

const _roleOptions = [
  Option(Role.junior, 'Junior Member'),
  Option(Role.senior, 'Senior Member'),
  Option(Role.advisor, 'Advisor', subtitle: 'Listed on the Advisors page'),
  Option(
    Role.moderator,
    'Moderator',
    subtitle: 'Listed on the Moderators page',
  ),
  Option(Role.teamLead, 'Team Lead', subtitle: 'Can manage tasks and members'),
  Option(Role.superAdmin, 'Super Admin', subtitle: 'Full control'),
];

/// A 10-character password that is easy to read out and type:
/// letters and digits, without the look-alikes 0/O and 1/l/I.
String generatePassword() {
  const lookAlikes = '0O1lI';
  final chars = <String>[
    for (var code = 48; code <= 122; code++)
      if (code <= 57 || (code >= 65 && code <= 90) || code >= 97)
        if (!lookAlikes.contains(String.fromCharCode(code)))
          String.fromCharCode(code),
  ];
  final random = Random.secure();
  return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final q = _query.trim().toLowerCase();
    final users = (state.value ?? const <AppUser>[])
        .where(
          (u) =>
              q.isEmpty ||
              u.fullName.toLowerCase().contains(q) ||
              u.userId.toLowerCase().contains(q) ||
              u.subTeamName.toLowerCase().contains(q),
        )
        .toList();
    return SubPage(
      title: 'USER ACCOUNTS',
      children: [
        PrimaryButton(
          label: 'Create account',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: () => showAltairSheet<void>(
            context,
            builder: (_) => const _UserEditor(existing: null),
          ),
        ),
        const SizedBox(height: 14),
        SearchField(
          controller: _search,
          hint: 'Search by name, ID or sub-team',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 14),
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 72, count: 5)
        else if (state.value == null && state.hasError)
          ErrorState(
            message: friendlyError(state.error!),
            onRetry: () => ref.invalidate(usersProvider),
          )
        else if (users.isEmpty)
          const EmptyState(
            icon: Icons.manage_accounts_outlined,
            title: 'No accounts found',
            message: 'Create an account to give a member access.',
          )
        else
          for (final u in users)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressScale(
                scale: 0.985,
                onTap: () => showAltairSheet<void>(
                  context,
                  builder: (_) => _UserEditor(existing: u),
                ),
                child: FrostCard(
                  padding: const EdgeInsets.all(12),
                  child: Opacity(
                    opacity: u.disabled ? 0.55 : 1,
                    child: Row(
                      children: [
                        Avatar(name: u.fullName, url: u.photoUrl, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: T.strong(context),
                              ),
                              Text(
                                u.userId,
                                style: T.mono(
                                  context,
                                  size: 12,
                                  color: context.palette.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tag(
                          u.disabled ? 'Disabled' : u.role.label,
                          accent: !u.disabled && u.role.isLead,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _UserEditor extends ConsumerStatefulWidget {
  const _UserEditor({required this.existing});

  final AppUser? existing;

  @override
  ConsumerState<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends ConsumerState<_UserEditor> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _password = TextEditingController(text: generatePassword());
  late final _name = TextEditingController(text: widget.existing?.fullName);
  late final _position = TextEditingController(
    text: widget.existing?.position,
  );
  late Role _role = widget.existing?.role ?? Role.junior;
  late String _subTeamId = widget.existing?.subTeamId ?? '';
  late String _subTeamName = widget.existing?.subTeamName ?? '';
  bool _busy = false;

  AppUser? get existing => widget.existing;

  @override
  void dispose() {
    _userId.dispose();
    _password.dispose();
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showToast(context, done);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final admin = ref.read(adminRepositoryProvider);
    final current = existing;
    if (current == null) {
      await _guard(
        () => admin.createUser(
          userId: _userId.text.trim(),
          password: _password.text,
          fullName: _name.text.trim(),
          role: _role,
          position: _position.text.trim(),
          subTeamId: _subTeamId,
          subTeamName: _subTeamName,
        ),
        'Account created. Give the member their ID and password.',
      );
    } else {
      await _guard(
        () => admin.updateUser(
          uid: current.id,
          fullName: _name.text.trim(),
          role: _role,
          position: _position.text.trim(),
          subTeamId: _subTeamId,
          subTeamName: _subTeamName,
        ),
        'Account updated',
      );
    }
  }

  Future<void> _pickRole() async {
    final picked = await showOptionsSheet<Role>(
      context,
      title: 'Role',
      options: _roleOptions,
      selected: _role,
    );
    if (picked != null) setState(() => _role = picked);
  }

  Future<void> _pickSubTeam() async {
    final teams = ref.read(subTeamsProvider).value ?? const <SubTeam>[];
    final picked = await showOptionsSheet<String>(
      context,
      title: 'Sub-team',
      selected: _subTeamId,
      options: [
        const Option('', 'No sub-team'),
        for (final t in teams) Option(t.id, t.name),
      ],
    );
    if (picked == null) return;
    setState(() {
      _subTeamId = picked;
      _subTeamName = picked.isEmpty
          ? ''
          : teams.firstWhere((t) => t.id == picked).name;
    });
  }

  void _resetPassword(AppUser user) {
    showAltairSheet<void>(context, builder: (_) => _ResetHelpSheet(user: user));
  }

  Future<void> _toggleDisabled(AppUser user) async {
    final disable = !user.disabled;
    final ok = await confirmDialog(
      context,
      title: disable ? 'Disable this account?' : 'Enable this account?',
      message: disable
          ? '${user.fullName} will be signed out and blocked from the app '
                'until the account is enabled again.'
          : '${user.fullName} will be able to sign in again.',
      confirmLabel: disable ? 'Disable' : 'Enable',
      danger: disable,
    );
    if (!ok || !mounted) return;
    await _guard(
      () => ref
          .read(adminRepositoryProvider)
          .setDisabled(user.id, disable, label: user.fullName),
      disable ? 'Account disabled' : 'Account enabled',
    );
  }

  Future<void> _delete(AppUser user) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this account?',
      message:
          '${user.fullName} loses access at once and their profile card is '
          'removed. The User ID "${user.userId}" is deleted within a few '
          'minutes, so it can be used again. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _guard(
      () => ref.read(adminRepositoryProvider).deleteUser(user),
      'Account deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = existing;
    final isSelf = current != null && current.id == ref.watch(uidProvider);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            current == null ? 'Create account' : 'Edit account',
            subtitle: current == null
                ? 'The member signs in with this ID and password.'
                : 'User ID  ${current.userId}',
          ),
          if (current == null) ...[
            AltairTextField(
              controller: _userId,
              label: 'User ID',
              hint: 'e.g. ALT-021',
              icon: Icons.badge_outlined,
              maxLength: 32,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9._-]')),
              ],
              validator: (v) => AuthRepository.validUserId(v ?? '')
                  ? null
                  : 'Use 3-32 letters, digits, dot, dash or underscore',
            ),
            const SizedBox(height: 16),
            AltairTextField(
              controller: _password,
              label: 'Password',
              icon: Icons.key_rounded,
              maxLength: 64,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.length < 8)
                  ? 'Use at least 8 characters'
                  : null,
              suffix: IconButton(
                tooltip: 'Generate a new password',
                onPressed: () =>
                    setState(() => _password.text = generatePassword()),
                icon: Icon(Icons.casino_outlined, size: 20, color: p.textFaint),
              ),
            ),
            const SizedBox(height: 16),
          ],
          AltairTextField(
            controller: _name,
            label: 'Full name',
            icon: Icons.person_outline_rounded,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().length < 2) ? 'Enter the full name' : null,
          ),
          const SizedBox(height: 16),
          PickerField(
            label: 'Role',
            icon: Icons.shield_outlined,
            value: _role.label,
            onTap: isSelf ? null : _pickRole,
          ),
          if (isSelf)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Text(
                'You cannot change your own role.',
                style: T.small(context),
              ),
            ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _position,
            label: 'Position (optional)',
            hint: 'e.g. Electrical Lead',
            icon: Icons.workspace_premium_outlined,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          PickerField(
            label: 'Sub-team (optional)',
            icon: Icons.hub_outlined,
            value: _subTeamName,
            placeholder: 'No sub-team',
            onTap: _pickSubTeam,
          ),
          if (current != null && !isSelf) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GhostButton(
                    label: 'Reset password',
                    icon: Icons.lock_reset_rounded,
                    compact: true,
                    onPressed: _busy ? null : () => _resetPassword(current),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                    label: current.disabled ? 'Enable' : 'Disable',
                    icon: current.disabled
                        ? Icons.check_circle_outline_rounded
                        : Icons.block_rounded,
                    compact: true,
                    danger: !current.disabled,
                    onPressed: _busy ? null : () => _toggleDisabled(current),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'Delete account',
              icon: Icons.delete_forever_outlined,
              compact: true,
              danger: true,
              onPressed: _busy ? null : () => _delete(current),
            ),
          ],
          SheetActions(
            confirmLabel: current == null ? 'Create' : 'Save',
            busy: _busy,
            onConfirm: _save,
          ),
        ],
      ),
    );
  }
}

/// Firebase's free plan gives a phone no way to change somebody else's
/// password, so a forgotten password is replaced from the team's PC.
class _ResetHelpSheet extends StatefulWidget {
  const _ResetHelpSheet({required this.user});

  final AppUser user;

  @override
  State<_ResetHelpSheet> createState() => _ResetHelpSheetState();
}

class _ResetHelpSheetState extends State<_ResetHelpSheet> {
  late final String _command =
      'node admin.js reset-password ${widget.user.userId} ${generatePassword()}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          'Reset password',
          subtitle: 'For ${widget.user.fullName}',
        ),
        Text(
          'A phone cannot change another member\'s password on Firebase\'s '
          'free plan. On the team PC, open the "tools" folder of the project '
          'in a terminal and run this command. The last word is the new '
          'password - change it if you like.',
          style: T.body(context),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.bgDeep,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: SelectableText(_command, style: T.mono(context, size: 12.5)),
        ),
        const SizedBox(height: 14),
        Text(
          'The old password stops working at once, and the app asks the '
          'member to choose a password of their own at the next sign-in.',
          style: T.small(context),
        ),
        const SizedBox(height: 18),
        PrimaryButton(
          label: 'Copy command',
          icon: Icons.copy_rounded,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _command));
            if (!context.mounted) return;
            showToast(context, 'Command copied');
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}
