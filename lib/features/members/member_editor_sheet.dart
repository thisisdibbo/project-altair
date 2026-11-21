import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/core.dart';
import '../../data/data.dart';

/// Add / edit a directory profile (team lead, senior or junior member).
Future<void> showMemberEditor(
  BuildContext context, {
  required MemberGroup group,
  Member? existing,
  String? selfId,
}) => showAltairSheet<void>(
  context,
  builder: (_) =>
      _MemberEditor(group: group, existing: existing, selfId: selfId),
);

class _MemberEditor extends ConsumerStatefulWidget {
  const _MemberEditor({
    required this.group,
    required this.existing,
    required this.selfId,
  });

  final MemberGroup group;
  final Member? existing;

  /// Set when a member adds their own card: it takes their account ID.
  final String? selfId;

  @override
  ConsumerState<_MemberEditor> createState() => _MemberEditorState();
}

class _MemberEditorState extends ConsumerState<_MemberEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.fullName);
  late final _position = TextEditingController(
    text: widget.existing?.position,
  );
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _whatsapp = TextEditingController(
    text: widget.existing?.whatsapp,
  );
  late final _messenger = TextEditingController(
    text: widget.existing?.messengerLink,
  );
  late final String _id =
      widget.existing?.id ??
      widget.selfId ??
      ref.read(teamRepositoryProvider).newMemberId(widget.group);

  late String _subTeamId = widget.existing?.subTeamId ?? '';
  late String _tier = widget.existing?.tier ?? '';
  late String _wing = widget.existing?.wing ?? '';
  late String _reportsTo = widget.existing?.reportsTo ?? '';
  late final _order = TextEditingController(
    text: (widget.existing?.order ?? 0) > 0 ? '${widget.existing!.order}' : '',
  );

  bool get _isLeadsPage => widget.group == MemberGroup.teamLeads;

  /// Senior and junior members are listed by sub-team, so they need one.
  bool get _needsTeam => widget.group.groupedBySubTeam;

  /// On the Team Leads page everyone but the central Team Lead is in a wing.
  bool get _needsWing => _isLeadsPage && _tier != 'lead';

  /// Leads in a wing, advisors and moderators set their place in the list.
  bool get _hasOrder => _needsWing || widget.group.plainList;
  late String _subTeamName = widget.existing?.subTeamName ?? '';
  late bool _sameAsPhone =
      widget.existing == null ||
      widget.existing!.whatsapp == widget.existing!.phone;
  Uint8List? _picked;
  bool _busy = false;
  bool _showErrors = false;

  bool get _hasPhoto =>
      _picked != null || (widget.existing?.photoUrl.isNotEmpty ?? false);

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _messenger.dispose();
    _order.dispose();
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

  /// Choose whose card this one sits under, within the same wing. The
  /// person themselves and anyone already under them are left out, so the
  /// chart can never loop.
  Future<void> _pickReportsTo(List<Member> leads) async {
    final below = <String>{_id};
    for (var grew = true; grew;) {
      grew = false;
      for (final m in leads) {
        if (!below.contains(m.id) && below.contains(m.reportsTo)) {
          below.add(m.id);
          grew = true;
        }
      }
    }
    final choices = [
      for (final m in leads)
        if (m.wing == _wing && m.tier != 'lead' && !below.contains(m.id)) m,
    ]..sort((a, b) => a.fullName.compareTo(b.fullName));
    final picked = await showOptionsSheet<String>(
      context,
      title: 'Sits under',
      selected: _reportsTo,
      options: [
        const Option('', 'No one (top of the wing)'),
        for (final m in choices)
          Option(
            m.id,
            m.fullName,
            subtitle: m.position.isEmpty ? null : m.position,
          ),
      ],
    );
    if (picked != null) setState(() => _reportsTo = picked);
  }

  String? _orderCheck(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return null;
    final n = int.tryParse(text);
    if (n == null || n < 1 || n > 999) return 'Enter a number from 1 to 999';
    return null;
  }

  String? _phoneCheck(String? v, String what) {
    final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Enter the $what with country code';
    return null;
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid ||
        !_hasPhoto ||
        (_needsTeam && _subTeamId.isEmpty) ||
        (_needsWing && _wing.isEmpty)) {
      return;
    }
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;

    setState(() => _busy = true);
    try {
      final photos = ref.read(photoRepositoryProvider);
      final oldPhoto = widget.existing?.photoUrl ?? '';
      var photoUrl = oldPhoto;
      if (_picked != null) photoUrl = await photos.save(_picked!, me.id);
      final phone = _phone.text.trim();
      final synced = await ref
          .read(teamRepositoryProvider)
          .saveMember(
            widget.group,
            _id,
            {
              'fullName': _name.text.trim(),
              'position': _position.text.trim(),
              'subTeamId': _subTeamId,
              'subTeamName': _subTeamName,
              'phone': phone,
              'whatsapp': _sameAsPhone ? phone : _whatsapp.text.trim(),
              'messengerLink': _messenger.text.trim(),
              'photoUrl': photoUrl,
              if (_isLeadsPage) ...{
                'tier': _tier,
                'wing': _needsWing ? _wing : '',
                'reportsTo': _needsWing ? _reportsTo : '',
              },
              'order': _hasOrder ? int.tryParse(_order.text.trim()) ?? 0 : 0,
            },
            isNew: widget.existing == null,
            byUid: me.id,
          );
      if (photoUrl != oldPhoto) photos.delete(oldPhoto);
      if (!mounted) return;
      showToast(
        context,
        synced
            ? (widget.existing == null ? 'Profile added' : 'Profile updated')
            : 'Saved on this phone. It will sync when you are online.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final existing = widget.existing;
    final noTeams = (ref.watch(subTeamsProvider).value ?? const []).isEmpty;
    final leads = _isLeadsPage
        ? ref.watch(membersProvider(MemberGroup.teamLeads)).value ??
              const <Member>[]
        : const <Member>[];
    final sitsUnder = [
      for (final m in leads)
        if (m.id == _reportsTo) m.fullName,
    ].firstOrNull;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            existing == null
                ? 'Add ${widget.group.singular}'
                : 'Edit profile',
            subtitle: 'Shown in the ${widget.group.title} directory.',
          ),
          Row(
            children: [
              Avatar(
                name: _name.text,
                url: existing?.photoUrl,
                image: _picked,
                size: 88,
                ring: true,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FieldLabel('Profile picture'),
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
                    if (_showErrors && !_hasPhoto)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 6),
                        child: Text(
                          'Add a profile picture',
                          style: T.small(context).copyWith(color: p.ember),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_isLeadsPage) ...[
            const SizedBox(height: 18),
            const FieldLabel('Role'),
            Segmented<String>(
              options: const [
                ('lead', 'Team Lead'),
                ('', 'Lead'),
                ('executive', 'Executive'),
              ],
              selected: _tier,
              onChanged: (v) => setState(() => _tier = v),
            ),
            if (_needsWing) ...[
              const SizedBox(height: 14),
              const FieldLabel('Wing'),
              Segmented<String>(
                options: const [
                  ('management', 'Management'),
                  ('technical', 'Technical'),
                  ('scientific', 'Scientific'),
                ],
                selected: _wing,
                onChanged: (v) => setState(() {
                  if (v != _wing) _reportsTo = '';
                  _wing = v;
                }),
              ),
              if (_showErrors && _wing.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 6),
                  child: Text(
                    'Choose a wing',
                    style: T.small(context).copyWith(color: p.ember),
                  ),
                ),
            ],
          ],
          const SizedBox(height: 18),
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
          AltairTextField(
            controller: _position,
            label: 'Position (optional)',
            hint: 'e.g. ${widget.group.singular}',
            icon: Icons.workspace_premium_outlined,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          if (_needsWing) ...[
            const SizedBox(height: 16),
            PickerField(
              label: 'Sits under (optional)',
              icon: Icons.account_tree_outlined,
              value: sitsUnder,
              placeholder: _wing.isEmpty
                  ? 'Choose a wing first'
                  : 'No one (top of the wing)',
              onTap: _wing.isEmpty ? null : () => _pickReportsTo(leads),
            ),
          ],
          if (_hasOrder) ...[
            const SizedBox(height: 16),
            AltairTextField(
              controller: _order,
              label: 'Order in the list (optional)',
              hint: '1 = first',
              icon: Icons.format_list_numbered_rounded,
              keyboardType: TextInputType.number,
              maxLength: 3,
              textInputAction: TextInputAction.next,
              validator: _orderCheck,
            ),
          ],
          if (!widget.group.plainList) ...[
            const SizedBox(height: 16),
            PickerField(
              label: _needsTeam ? 'Sub-team' : 'Sub-team (optional)',
              icon: Icons.hub_outlined,
              value: _subTeamName,
              placeholder: noTeams
                  ? 'No sub-teams yet - ask an administrator'
                  : 'Choose a sub-team',
              errorText: _showErrors && _needsTeam && _subTeamId.isEmpty
                  ? 'Choose a sub-team'
                  : null,
              onTap: _pickSubTeam,
            ),
          ],
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
          SheetActions(
            confirmLabel: existing == null ? 'Add profile' : 'Save',
            busy: _busy,
            onConfirm: _save,
          ),
        ],
      ),
    );
  }
}
