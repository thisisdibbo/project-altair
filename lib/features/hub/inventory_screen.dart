import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/dashboard_scaffold.dart';
import '../shell/sub_page.dart';
import '../tasks/task_widgets.dart';

/// Every part and tool the team owns: how many, where it is kept and,
/// when someone has taken it, who and since when.
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _onlyTaken = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _try(Future<Object?> Function() action, String done) async {
    try {
      await action();
      if (mounted) showToast(context, done);
    } catch (e) {
      if (mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  bool _matches(InventoryItem item) {
    if (_onlyTaken && !item.isOut) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return item.name.toLowerCase().contains(q) ||
        item.category.toLowerCase().contains(q) ||
        item.location.toLowerCase().contains(q) ||
        item.borrowedByName.toLowerCase().contains(q);
  }

  Future<void> _take(InventoryItem item) async {
    final me = ref.read(currentUserProvider).value;
    if (me == null) return;
    await _try(
      () => ref.read(hubRepositoryProvider).takeItem(item.id, me),
      'Marked as with you',
    );
  }

  Future<void> _delete(InventoryItem item) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete "${item.name}"?',
      message: 'It will be removed from the inventory for everyone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;
    await _try(
      () => ref
          .read(hubRepositoryProvider)
          .deleteItem(item.id, label: item.name),
      'Item deleted',
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final manage = perms?.manageInventory ?? false;
    final myId = perms?.user.id;
    final state = ref.watch(inventoryProvider);
    final all = state.value ?? const <InventoryItem>[];
    final shown = all.where(_matches).toList();
    final taken = all.where((i) => i.isOut).length;
    final repo = ref.read(hubRepositoryProvider);

    return SubPage(
      title: 'INVENTORY',
      action: RoundIconButton(
        icon: Icons.add_rounded,
        tooltip: 'Add item',
        onTap: () => showInventoryEditor(context),
      ),
      children: [
        SearchField(
          controller: _search,
          hint: 'Search parts, places, people',
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 12),
        PillRow(
          children: [
            FilterPill(
              label: 'All · ${all.length}',
              selected: !_onlyTaken,
              onTap: () => setState(() => _onlyTaken = false),
            ),
            FilterPill(
              label: 'Taken · $taken',
              selected: _onlyTaken,
              onTap: () => setState(() => _onlyTaken = true),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.value == null && state.isLoading)
          const SkeletonList(height: 96, count: 4)
        else if (state.value == null && state.hasError)
          ErrorState(
            message: friendlyError(state.error!),
            onRetry: () => ref.invalidate(inventoryProvider),
          )
        else if (all.isEmpty)
          EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No items yet',
            message: 'Tap + at the top to add the first part or tool.',
          )
        else if (shown.isEmpty)
          const EmptyState(
            icon: Icons.search_off_rounded,
            title: 'Nothing found',
            message: 'Try a different word, or switch back to All.',
          )
        else
          for (final item in shown)
            Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: _ItemCard(
                item: item,
                onTake: item.isOut ? null : () => _take(item),
                onReturn: item.isOut && (manage || item.borrowedById == myId)
                    ? () => _try(
                        () => repo.returnItem(item),
                        'Marked as returned',
                      )
                    : null,
                onEdit: manage
                    ? () => showInventoryEditor(context, existing: item)
                    : null,
                onDelete: manage ? () => _delete(item) : null,
              ),
            ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onTake,
    required this.onReturn,
    required this.onEdit,
    required this.onDelete,
  });

  final InventoryItem item;
  final VoidCallback? onTake;
  final VoidCallback? onReturn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FrostCard(
      highlight: item.isOut,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(item.name, style: T.title(context))),
              const SizedBox(width: 10),
              Tag('× ${item.quantity}'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 7,
            children: [
              MetaLine(
                Icons.place_outlined,
                item.location.isEmpty ? 'No place set' : item.location,
              ),
              if (item.category.isNotEmpty)
                MetaLine(Icons.category_outlined, item.category),
              MetaLine(
                item.isOut
                    ? Icons.person_outline_rounded
                    : Icons.check_circle_outline_rounded,
                item.isOut
                    ? 'With ${item.borrowedByName} · '
                          '${formatFriendly(item.borrowedAt)}'
                    : 'Available',
              ),
            ],
          ),
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(item.notes, style: T.small(context)),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: p.line),
          const SizedBox(height: 10),
          Row(
            children: [
              if (onTake != null)
                GhostButton(
                  label: 'Take',
                  icon: Icons.back_hand_outlined,
                  expand: false,
                  compact: true,
                  accent: true,
                  onPressed: onTake,
                )
              else if (onReturn != null)
                GhostButton(
                  label: 'Return',
                  icon: Icons.keyboard_return_rounded,
                  expand: false,
                  compact: true,
                  accent: true,
                  onPressed: onReturn,
                )
              else
                Text('Taken', style: T.small(context)),
              const Spacer(),
              if (onEdit != null)
                RoundIconButton(
                  icon: Icons.edit_outlined,
                  size: 36,
                  tooltip: 'Edit',
                  onTap: onEdit,
                ),
              if (onDelete != null) ...[
                const SizedBox(width: 6),
                RoundIconButton(
                  icon: Icons.delete_outline_rounded,
                  size: 36,
                  tooltip: 'Delete',
                  color: p.ember,
                  onTap: onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Add / edit an inventory item.
Future<void> showInventoryEditor(
  BuildContext context, {
  InventoryItem? existing,
}) => showAltairSheet<void>(
  context,
  builder: (_) => _InventoryEditor(existing: existing),
);

class _InventoryEditor extends ConsumerStatefulWidget {
  const _InventoryEditor({required this.existing});

  final InventoryItem? existing;

  @override
  ConsumerState<_InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends ConsumerState<_InventoryEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _category = TextEditingController(
    text: widget.existing?.category,
  );
  late final _quantity = TextEditingController(
    text: '${widget.existing?.quantity ?? 1}',
  );
  late final _location = TextEditingController(
    text: widget.existing?.location,
  );
  late final _notes = TextEditingController(text: widget.existing?.notes);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _quantity.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final draft = InventoryDraft(
      name: _name.text.trim(),
      category: _category.text.trim(),
      quantity: int.tryParse(_quantity.text.trim()) ?? 0,
      location: _location.text.trim(),
      notes: _notes.text.trim(),
    );
    final repo = ref.read(hubRepositoryProvider);
    final existing = widget.existing;
    try {
      final synced = existing == null
          ? await repo.addItem(draft)
          : await repo.updateItem(existing.id, draft);
      if (!mounted) return;
      showToast(
        context,
        synced
            ? (existing == null ? 'Item added' : 'Item updated')
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
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          widget.existing == null ? 'Add item' : 'Edit item',
          subtitle: 'Shown in the inventory for everyone.',
        ),
        AltairTextField(
          controller: _name,
          label: 'Name',
          hint: 'e.g. BTS7960 motor driver',
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Give the item a name' : null,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: AltairTextField(
                controller: _category,
                label: 'Category (optional)',
                hint: 'e.g. Electronics',
                maxLength: 40,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AltairTextField(
                controller: _quantity,
                label: 'Quantity',
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.next,
                validator: (v) => int.tryParse((v ?? '').trim()) == null
                    ? 'Enter a number'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AltairTextField(
          controller: _location,
          label: 'Where it is kept',
          hint: 'e.g. Lab shelf B, box 3',
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        AltairTextField(
          controller: _notes,
          label: 'Notes (optional)',
          maxLines: 3,
          minLines: 2,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
        ),
        SheetActions(
          confirmLabel: widget.existing == null ? 'Add item' : 'Save',
          busy: _busy,
          onConfirm: _save,
        ),
      ],
    ),
  );
}
