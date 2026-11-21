import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/sub_page.dart';
import '../tasks/task_widgets.dart';

/// "Tk 1,250" or "Tk 1,250.50".
String formatTaka(double amount) {
  final totalCents = (amount * 100).round();
  final cents = totalCents % 100;
  final digits = (totalCents ~/ 100).toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return cents == 0
      ? 'Tk $out'
      : 'Tk $out.${cents.toString().padLeft(2, '0')}';
}

/// What members paid for from their own pocket: why, how much, the bKash
/// number to pay back to, and a photo of the receipt. A member sees their
/// own entries; team leads see everyone's.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Expense expense,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this expense?',
      message: '"${expense.reason}" will be removed from the log.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(extrasRepositoryProvider)
          .deleteExpense(expense.id, label: expense.reason);
      ref.read(photoRepositoryProvider).delete(expense.receiptUrl);
      if (context.mounted) showToast(context, 'Expense deleted');
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final lead = perms?.role.isLead ?? false;
    final myId = perms?.user.id;
    final state = ref.watch(expensesProvider);
    final all = state.value ?? const <Expense>[];
    final total = all.fold<double>(0, (sum, e) => sum + e.amount);

    return SubPage(
      title: 'EXPENSES',
      action: RoundIconButton(
        icon: Icons.add_rounded,
        tooltip: 'Add expense',
        onTap: () => showExpenseEditor(context),
      ),
      children: [
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 120, count: 3)
        else if (state.value == null && state.hasError)
          ErrorState(
            message: friendlyError(state.error!),
            onRetry: () => ref.invalidate(expensesProvider),
          )
        else if (all.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses yet',
            message:
                'Bought something for the team? Tap + at the top and add '
                'the reason, the amount, your bKash number and the receipt.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              '${lead ? 'ALL MEMBERS' : 'YOUR ENTRIES'} · ${all.length} · '
              '${formatTaka(total).toUpperCase()}',
              style: T.label(context),
            ),
          ),
          for (final e in all)
            Padding(
              key: ValueKey(e.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExpenseCard(
                expense: e,
                onDelete: lead || e.createdById == myId
                    ? () => _delete(context, ref, e)
                    : null,
              ),
            ),
        ],
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.onDelete});

  final Expense expense;
  final VoidCallback? onDelete;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: expense.bkash));
    if (context.mounted) showToast(context, 'bKash number copied');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FrostCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatTaka(expense.amount),
                  style: T.title(
                    context,
                  ).copyWith(color: p.accentText, fontSize: 19),
                ),
              ),
              if (onDelete != null)
                RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  size: 34,
                  tooltip: 'Delete',
                  color: p.ember,
                  onTap: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(expense.reason, style: T.body(context)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 7,
            children: [
              MetaLine(Icons.person_outline_rounded, expense.createdByName),
              MetaLine(
                Icons.schedule_rounded,
                formatFriendly(expense.createdAt),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: p.line),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'bKash ${expense.bkash}',
                  icon: Icons.content_copy_rounded,
                  compact: true,
                  onPressed: () => _copy(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GhostButton(
                  label: 'Receipt',
                  icon: Icons.receipt_long_outlined,
                  compact: true,
                  accent: true,
                  onPressed: () => showReceipt(context, expense),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the receipt photo of an expense.
Future<void> showReceipt(BuildContext context, Expense expense) =>
    showAltairSheet<void>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(
            'Receipt',
            subtitle:
                '${formatTaka(expense.amount)} · ${expense.createdByName}',
          ),
          FutureBuilder<Uint8List?>(
            future: Photos.load(expense.receiptUrl),
            builder: (context, snap) {
              final bytes = snap.data;
              if (snap.connectionState != ConnectionState.done) {
                return const Skeleton(height: 260, radius: 16);
              }
              if (bytes == null) {
                return const EmptyState(
                  icon: Icons.image_not_supported_outlined,
                  title: 'Receipt not available',
                  message: 'It could not be loaded. Check the connection.',
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

/// The Add expense form.
Future<void> showExpenseEditor(BuildContext context) =>
    showAltairSheet<void>(context, builder: (_) => const _ExpenseEditor());

class _ExpenseEditor extends ConsumerStatefulWidget {
  const _ExpenseEditor();

  @override
  ConsumerState<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends ConsumerState<_ExpenseEditor> {
  /// Receipts need to stay readable, so they are kept larger than avatars.
  static const _receiptSide = 1024.0;

  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  final _bkash = TextEditingController();
  Uint8List? _receipt;
  bool _busy = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    _bkash.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final bytes = await PhotoRepository.pick(source, side: _receiptSide);
      if (bytes != null && mounted) setState(() => _receipt = bytes);
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

  Future<void> _save() async {
    setState(() => _showErrors = true);
    final valid = _formKey.currentState?.validate() ?? false;
    final receipt = _receipt;
    if (!valid || receipt == null) return;
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;

    setState(() => _busy = true);
    try {
      final receiptUrl = await ref
          .read(photoRepositoryProvider)
          .save(receipt, me.id);
      final synced = await ref
          .read(extrasRepositoryProvider)
          .addExpense(
            reason: _reason.text.trim(),
            amount: double.parse(_amount.text.trim()),
            bkash: _bkash.text.trim(),
            receiptUrl: receiptUrl,
            me: me,
          );
      if (!mounted) return;
      showToast(
        context,
        synced
            ? 'Expense added'
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
    final receipt = _receipt;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetTitle(
            'Add expense',
            subtitle: 'Seen by you and the team leads.',
          ),
          AltairTextField(
            controller: _reason,
            label: 'Reason to buy',
            hint: 'e.g. Two BTS7960 motor drivers for the drive base',
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Say what it was bought for'
                : null,
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _amount,
            label: 'Amount (Tk)',
            hint: 'e.g. 1250',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            maxLength: 10,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            textInputAction: TextInputAction.next,
            validator: (v) {
              final n = double.tryParse((v ?? '').trim());
              return n == null || n <= 0 ? 'Enter the amount paid' : null;
            },
          ),
          const SizedBox(height: 16),
          AltairTextField(
            controller: _bkash,
            label: 'bKash number',
            hint: '01XXXXXXXXX',
            keyboardType: TextInputType.phone,
            maxLength: 14,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v ?? '').trim().length < 11
                ? 'Enter the 11-digit bKash number'
                : null,
          ),
          const SizedBox(height: 16),
          const FieldLabel('Photo of the receipt'),
          if (receipt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  receipt,
                  height: 180,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: 'Camera',
                  icon: Icons.photo_camera_outlined,
                  compact: true,
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(
                  label: 'Gallery',
                  icon: Icons.photo_library_outlined,
                  compact: true,
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (_showErrors && receipt == null)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 6),
              child: Text(
                'Add a photo of the receipt',
                style: T.small(context).copyWith(color: p.ember),
              ),
            ),
          SheetActions(confirmLabel: 'Add expense', busy: _busy, onConfirm: _save),
        ],
      ),
    );
  }
}
