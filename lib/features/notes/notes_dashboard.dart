import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../shell/dashboard_scaffold.dart';
import '../tasks/task_widgets.dart';
import 'note_done.dart';
import 'note_editor_sheet.dart';

/// TEAM NOTES - the shared noticeboard, live on every phone.
class NotesDashboard extends ConsumerStatefulWidget {
  const NotesDashboard({super.key});

  @override
  ConsumerState<NotesDashboard> createState() => _NotesDashboardState();
}

class _NotesDashboardState extends ConsumerState<NotesDashboard> {
  final _search = TextEditingController();
  String _query = '';
  String? _category;
  bool _pinnedFirst = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Note> _visible(List<Note> notes) {
    final q = _query.trim().toLowerCase();
    final list = notes.where((n) {
      if (_category != null && n.category != _category) return false;
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.authorName.toLowerCase().contains(q) ||
          n.category.toLowerCase().contains(q);
    }).toList();
    if (_pinnedFirst) {
      final pinned = list.where((n) => n.pinned);
      final rest = list.where((n) => !n.pinned);
      return [...pinned, ...rest];
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final notes = ref.watch(notesProvider);
    final all = notes.value ?? const <Note>[];
    final items = _visible(all);
    final categories =
        all.map((n) => n.category).where((c) => c.isNotEmpty).toSet().toList()
          ..sort();

    final Widget list;
    if (notes.value == null && notes.isLoading) {
      list = const SliverToBoxAdapter(child: SkeletonList(height: 150));
    } else if (notes.value == null && notes.hasError) {
      list = SliverToBoxAdapter(
        child: ErrorState(
          message: friendlyError(notes.error!),
          onRetry: () => ref.invalidate(notesProvider),
        ),
      );
    } else if (items.isEmpty) {
      list = SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.campaign_outlined,
          title: all.isEmpty ? 'The noticeboard is empty' : 'No matching notes',
          message: all.isEmpty
              ? 'Tap the orange + to publish the first note.'
              : 'Try a different search or category.',
        ),
      );
    } else {
      list = SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => Appear(
          key: ValueKey(items[i].id),
          index: i,
          child: NoteCard(note: items[i], perms: perms),
        ),
      );
    }

    final pinnedCount = all.where((n) => n.pinned).length;
    return DashboardScaffold(
      index: 2,
      title: 'TEAM\nNOTES',
      facts: notes.value == null
          ? const []
          : [
              ('${all.length}', 'Notes'),
              ('$pinnedCount', 'Pinned'),
              ('${all.where((n) => n.important).length}', 'Important'),
            ],
      onRefresh: () async => ref.invalidate(notesProvider),
      fab: (perms?.createNotes ?? false)
          ? AltairFab(
              tooltip: 'Create note',
              onTap: () => showNoteEditor(context),
            )
          : null,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                controller: _search,
                hint: 'Search notes',
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              PillRow(
                children: [
                  FilterPill(
                    label: _pinnedFirst ? 'Pinned first' : 'Newest first',
                    icon: _pinnedFirst
                        ? Icons.push_pin_outlined
                        : Icons.schedule_rounded,
                    selected: true,
                    onTap: () => setState(() => _pinnedFirst = !_pinnedFirst),
                  ),
                  FilterPill(
                    label: 'All',
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in categories)
                    FilterPill(
                      label: c,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        list,
      ],
    );
  }
}

class NoteCard extends ConsumerWidget {
  const NoteCard({super.key, required this.note, required this.perms});

  final Note note;
  final Permissions? perms;

  Future<void> _more(BuildContext context, WidgetRef ref) async {
    final canEdit = perms?.canEditNote(note) ?? false;
    final canPin = perms?.pinNotes ?? false;
    final action = await showOptionsSheet<String>(
      context,
      title: note.title,
      options: [
        if (canPin) Option('pin', note.pinned ? 'Unpin note' : 'Pin note'),
        if (canEdit) const Option('edit', 'Edit note'),
        if (canEdit) const Option('delete', 'Delete note'),
      ],
    );
    if (action == null || !context.mounted) return;
    final repo = ref.read(noteRepositoryProvider);
    try {
      switch (action) {
        case 'pin':
          await repo.setPinned(note.id, !note.pinned, label: note.title);
          if (context.mounted) {
            showToast(
              context,
              note.pinned ? 'Note unpinned' : 'Note pinned',
              icon: Icons.push_pin_outlined,
            );
          }
        case 'edit':
          await showNoteEditor(context, existing: note);
        case 'delete':
          final ok = await confirmDialog(
            context,
            title: 'Delete this note?',
            message: '"${note.title}" will be removed for everyone.',
            confirmLabel: 'Delete',
            danger: true,
          );
          if (!ok) return;
          await repo.delete(note.id, label: note.title);
          if (context.mounted) showToast(context, 'Note deleted');
      }
    } catch (e) {
      if (context.mounted) showToast(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final hasMenu =
        (perms?.canEditNote(note) ?? false) || (perms?.pinNotes ?? false);
    final long = note.content.length > 260;
    return FrostCard(
      highlight: note.important,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(name: note.authorName, url: note.authorPhotoUrl, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: T.strong(context).copyWith(fontSize: 13.5),
                    ),
                    Text(
                      '${formatFriendly(note.createdAt ?? DateTime.now())}'
                      '${note.edited ? ' · edited' : ''}',
                      style: T.small(context).copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (note.pinned)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 18,
                    color: p.accentText,
                  ),
                ),
              if (hasMenu) ...[
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: Icons.more_horiz_rounded,
                  size: 34,
                  tooltip: 'Note actions',
                  onTap: () => _more(context, ref),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(note.title, style: T.title(context)),
          if (note.content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note.content,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: T.body(context),
            ),
          ],
          if (long || note.category.isNotEmpty || note.important) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (note.important) ...[
                  const Tag(
                    'Important',
                    icon: Icons.priority_high_rounded,
                    accent: true,
                  ),
                  const SizedBox(width: 8),
                ],
                if (note.category.isNotEmpty) Tag(note.category),
                const Spacer(),
                if (long)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showNoteReader(context, note),
                    child: Text(
                      'READ MORE',
                      style: T.label(context).copyWith(color: p.accentText),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          NoteDoneRow(note: note),
        ],
      ),
    );
  }
}

Future<void> showNoteReader(BuildContext context, Note note) =>
    showAltairSheet<void>(
      context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SheetTitle(
            note.title,
            subtitle:
                '${note.authorName} · '
                '${formatDateTime(note.createdAt)}',
          ),
          SelectableText(note.content, style: T.body(context)),
        ],
      ),
    );
