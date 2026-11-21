import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/dashboard_scaffold.dart';

/// Step 1 for someone new: choose a login ID and password. The login it
/// makes stays locked until a Super Admin approves the request.
Future<void> showCreateLogin(BuildContext context) =>
    showAltairSheet<void>(context, builder: (_) => const _CreateLogin());

class _CreateLogin extends ConsumerStatefulWidget {
  const _CreateLogin();

  @override
  ConsumerState<_CreateLogin> createState() => _CreateLoginState();
}

class _CreateLoginState extends ConsumerState<_CreateLogin> {
  final _formKey = GlobalKey<FormState>();
  final _userId = TextEditingController();
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _userId.dispose();
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .register(_userId.text, _password.text);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SheetTitle(
          'Request an account',
          subtitle:
              'Step 1 of 2: choose the User ID and password you will sign in '
              'with. Next you fill in your profile, then an administrator '
              'checks it and lets you in.',
        ),
        AltairTextField(
          controller: _userId,
          label: 'User ID',
          hint: 'e.g. mahin.rahman',
          icon: Icons.badge_outlined,
          maxLength: 32,
          textInputAction: TextInputAction.next,
          validator: (v) => AuthRepository.validUserId(v ?? '')
              ? null
              : 'Use 3-32 letters, digits, dot, dash or underscore',
        ),
        const SizedBox(height: 14),
        AltairTextField(
          controller: _password,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: true,
          maxLength: 64,
          textInputAction: TextInputAction.next,
          validator: (v) => (v ?? '').length < 8
              ? 'Use at least 8 characters'
              : null,
        ),
        const SizedBox(height: 14),
        AltairTextField(
          controller: _again,
          label: 'Password again',
          icon: Icons.lock_outline_rounded,
          obscure: true,
          maxLength: 64,
          validator: (v) =>
              v != _password.text ? 'The two passwords are different' : null,
        ),
        SheetActions(confirmLabel: 'Next', busy: _busy, onConfirm: _create),
      ],
    ),
  );
}

/// What a signed-in person without an account sees: their profile form,
/// or the state of the request they already sent. When a Super Admin
/// approves it the account appears and the app opens by itself.
class JoinGate extends ConsumerWidget {
  const JoinGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(myJoinRequestProvider);
    return request.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      error: (e, _) => _JoinStatus(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your request',
        message: friendlyError(e),
      ),
      data: (r) {
        if (r == null) return const _JoinForm();
        return r.rejected
            ? const _JoinStatus(
                icon: Icons.person_off_outlined,
                title: 'Request not approved',
                message:
                    'An administrator did not approve this request. If you '
                    'think that is a mistake, talk to the team. You can '
                    'delete this login and send a new request.',
                rejected: true,
              )
            : _JoinStatus(
                icon: Icons.hourglass_top_rounded,
                title: 'Waiting for approval',
                message:
                    'Thanks, ${r.fullName.split(' ').first}. An administrator '
                    'will check your details. The app opens by itself as '
                    'soon as you are approved.',
              );
      },
    );
  }
}

class _JoinStatus extends ConsumerStatefulWidget {
  const _JoinStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.rejected = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool rejected;

  @override
  ConsumerState<_JoinStatus> createState() => _JoinStatusState();
}

class _JoinStatusState extends ConsumerState<_JoinStatus> {
  bool _busy = false;

  Future<void> _withdraw() async {
    final sure = await confirmDialog(
      context,
      title: widget.rejected ? 'Delete this login?' : 'Cancel your request?',
      message:
          'Your request and the User ID you chose are deleted. You can '
          'request an account again from the sign-in screen.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(joinRequestsProvider).withdraw();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: widget.icon,
              title: widget.title,
              message: widget.message,
            ),
            GhostButton(
              label: widget.rejected
                  ? 'Delete and start again'
                  : 'Cancel request',
              icon: Icons.delete_outline_rounded,
              expand: false,
              onPressed: _busy ? null : _withdraw,
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'Sign out',
              icon: Icons.logout_rounded,
              expand: false,
              onPressed: _busy
                  ? null
                  : () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Step 2: the same profile as on the member pages, plus a student ID so
/// the administrator can check who is asking.
class _JoinForm extends ConsumerStatefulWidget {
  const _JoinForm();

  @override
  ConsumerState<_JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends ConsumerState<_JoinForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _position = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _messenger = TextEditingController();
  MemberGroup _group = MemberGroup.juniorMembers;
  String _subTeamId = '';
  String _subTeamName = '';
  Uint8List? _picked;
  bool _sameAsPhone = true;
  bool _showErrors = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _studentId.dispose();
    _position.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _messenger.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final bytes = await PhotoRepository.pick(source);
      if (bytes != null && mounted) setState(() => _picked = bytes);
    } on AppFailure catch (e) {
      if (mounted) showToast(context, e.message, error: true);
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          source == ImageSource.camera
              ? 'The camera is not available. Check the app permissions.'
              : 'The photo gallery is not available. Check the app permissions.',
          error: true,
        );
      }
    }
  }

  Future<void> _pickGroup() async {
    final picked = await showOptionsSheet<MemberGroup>(
      context,
      title: 'I am a',
      selected: _group,
      options: [for (final g in joinGroups) Option(g, joinGroupName(g))],
    );
    if (picked != null) setState(() => _group = picked);
  }

  Future<void> _pickSubTeam() async {
    final teams = ref.read(subTeamsProvider).value ?? const <SubTeam>[];
    final picked = await showOptionsSheet<SubTeam>(
      context,
      title: 'Sub-team',
      options: [for (final t in teams) Option(t, t.name)],
    );
    if (picked == null) return;
    setState(() {
      _subTeamId = picked.id;
      _subTeamName = picked.name;
    });
  }

  String? _phoneCheck(String? v, String what) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Enter the $what with country code';
    return null;
  }

  Future<void> _send() async {
    setState(() => _showErrors = true);
    final valid = _formKey.currentState?.validate() ?? false;
    final photo = _picked;
    // Advisors and moderators are not in a sub-team.
    final noTeam = _group.plainList;
    if (!valid || photo == null || (!noTeam && _subTeamId.isEmpty)) return;
    setState(() => _busy = true);
    try {
      final phone = _phone.text.trim();
      await ref
          .read(joinRequestsProvider)
          .send(
            fullName: _name.text.trim(),
            studentId: _studentId.text.trim(),
            group: _group,
            position: _position.text.trim(),
            subTeamId: noTeam ? '' : _subTeamId,
            subTeamName: noTeam ? '' : _subTeamName,
            phone: phone,
            whatsapp: _sameAsPhone ? phone : _whatsapp.text.trim(),
            messengerLink: _messenger.text.trim(),
            photo: photo,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  Future<void> _cancel() async {
    final sure = await confirmDialog(
      context,
      title: 'Stop and delete this login?',
      message:
          'The User ID you just chose is deleted. You can request an account '
          'again from the sign-in screen.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!sure || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(joinRequestsProvider).withdraw();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final insets = ShellInsets.of(context);
    final teams = ref.watch(subTeamsProvider).value ?? const <SubTeam>[];
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, insets.top + 8, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: GlassSurface(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SheetTitle(
                    'Your profile',
                    subtitle:
                        'Step 2 of 2. This becomes your card on the team page '
                        'once an administrator approves you.',
                  ),
                  Row(
                    children: [
                      Avatar(
                        name: _name.text,
                        image: _picked,
                        size: 88,
                        ring: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const FieldLabel('Your picture'),
                            Row(
                              children: [
                                Expanded(
                                  child: GhostButton(
                                    label: 'Gallery',
                                    icon: Icons.photo_library_outlined,
                                    compact: true,
                                    onPressed: _busy
                                        ? null
                                        : () => _pick(ImageSource.gallery),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GhostButton(
                                    label: 'Camera',
                                    icon: Icons.photo_camera_outlined,
                                    compact: true,
                                    onPressed: _busy
                                        ? null
                                        : () => _pick(ImageSource.camera),
                                  ),
                                ),
                              ],
                            ),
                            if (_showErrors && _picked == null)
                              Padding(
                                padding: const EdgeInsets.only(left: 4, top: 6),
                                child: Text(
                                  'Add a clear photo of your face',
                                  style: T.small(
                                    context,
                                  ).copyWith(color: p.ember),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AltairTextField(
                    controller: _name,
                    label: 'Full name',
                    icon: Icons.person_outline_rounded,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                  PickerField(
                    label: 'I am a',
                    icon: Icons.groups_outlined,
                    value: joinGroupName(_group),
                    onTap: _busy ? null : _pickGroup,
                  ),
                  const SizedBox(height: 16),
                  AltairTextField(
                    controller: _studentId,
                    label: _group.plainList ? 'Staff ID' : 'Student ID',
                    hint: _group.plainList
                        ? 'As on your university staff ID card'
                        : 'As on your university ID card',
                    icon: Icons.school_outlined,
                    maxLength: 20,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter your ID' : null,
                  ),
                  if (!_group.plainList) ...[
                    const SizedBox(height: 16),
                    PickerField(
                      label: 'Sub-team',
                      icon: Icons.hub_outlined,
                      value: _subTeamName.isEmpty ? null : _subTeamName,
                      placeholder: teams.isEmpty
                          ? 'Loading sub-teams...'
                          : 'Choose your sub-team',
                      errorText: _showErrors && _subTeamId.isEmpty
                          ? 'Choose your sub-team'
                          : null,
                      onTap: teams.isEmpty ? null : _pickSubTeam,
                    ),
                  ],
                  const SizedBox(height: 16),
                  AltairTextField(
                    controller: _position,
                    label: 'Position (optional)',
                    hint: 'e.g. Electrical Lead',
                    icon: Icons.workspace_premium_outlined,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AltairTextField(
                    controller: _phone,
                    label: 'Phone number',
                    hint: '+8801XXXXXXXXX',
                    icon: Icons.call_outlined,
                    keyboardType: TextInputType.phone,
                    maxLength: 20,
                    textInputAction: TextInputAction.next,
                    validator: (v) => _phoneCheck(v, 'phone number'),
                  ),
                  const SizedBox(height: 6),
                  SettingRow(
                    icon: Icons.chat_outlined,
                    title: 'WhatsApp uses the same number',
                    trailing: AltairSwitch(
                      value: _sameAsPhone,
                      onChanged: (v) => setState(() => _sameAsPhone = v),
                    ),
                  ),
                  if (!_sameAsPhone) ...[
                    const SizedBox(height: 6),
                    AltairTextField(
                      controller: _whatsapp,
                      label: 'WhatsApp number',
                      hint: '+8801XXXXXXXXX',
                      icon: Icons.chat_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                      textInputAction: TextInputAction.next,
                      validator: (v) => _phoneCheck(v, 'WhatsApp number'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AltairTextField(
                    controller: _messenger,
                    label: 'Messenger profile link',
                    hint: 'm.me/username',
                    icon: Icons.forum_outlined,
                    keyboardType: TextInputType.url,
                    maxLength: 200,
                    validator: (v) => Contact.messengerUri(v ?? '') == null
                        ? 'Enter the Messenger link or username'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  PrimaryButton(
                    label: 'Send for approval',
                    icon: Icons.send_rounded,
                    busy: _busy,
                    onPressed: _send,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: GhostButton(
                      label: 'Cancel and delete this login',
                      icon: Icons.close_rounded,
                      expand: false,
                      compact: true,
                      onPressed: _busy ? null : _cancel,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
