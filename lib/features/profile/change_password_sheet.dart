import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';

/// Opens the change-password form. [firstTime] is used right after an
/// administrator created the account or replaced a forgotten password.
Future<void> showChangePassword(
  BuildContext context, {
  bool firstTime = false,
}) => showAltairSheet<void>(
  context,
  builder: (_) => _ChangePasswordSheet(firstTime: firstTime),
);

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet({required this.firstTime});

  final bool firstTime;

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hidden = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(_current.text, _next.text);
      ref.read(activityLoggerProvider)(
        'user.password',
        'Changed their own password',
      );
      if (!mounted) return;
      showToast(context, 'Password changed');
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            widget.firstTime ? 'Choose your own password' : 'Change password',
            subtitle: widget.firstTime
                ? 'Your current password was set by an administrator. '
                      'Replace it with one only you know.'
                : 'Use at least 8 characters.',
          ),
          AltairTextField(
            controller: _current,
            label: 'Current password',
            icon: Icons.lock_outline_rounded,
            obscure: _hidden,
            enabled: !_busy,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.password],
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
            suffix: IconButton(
              tooltip: _hidden ? 'Show passwords' : 'Hide passwords',
              onPressed: () => setState(() => _hidden = !_hidden),
              icon: Icon(
                _hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: p.textFaint,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _next,
            label: 'New password',
            icon: Icons.key_rounded,
            obscure: _hidden,
            enabled: !_busy,
            maxLength: 64,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            validator: (v) {
              if (v == null || v.length < 8) return 'Use at least 8 characters';
              if (v == _current.text) return 'Choose a different password';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _confirm,
            label: 'Repeat new password',
            icon: Icons.key_rounded,
            obscure: _hidden,
            enabled: !_busy,
            maxLength: 64,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: (v) =>
                v != _next.text ? 'The two passwords do not match' : null,
          ),
          SheetActions(
            confirmLabel: 'Change password',
            busy: _busy,
            onConfirm: _save,
          ),
        ],
      ),
    );
  }
}
