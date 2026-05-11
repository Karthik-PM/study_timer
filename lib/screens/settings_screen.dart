import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_tag.dart';
import '../providers/tags_provider.dart';
import '../providers/sessions_provider.dart';
import '../services/export_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionHeader('Subjects'),
          tagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (tags) => Column(
              children: [
                ...tags.map((tag) => _TagTile(tag: tag)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: OutlinedButton.icon(
                    onPressed: () => _showTagEditor(context, ref, null),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Subject'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Export'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.table_chart_rounded,
                    color: Colors.green, size: 22),
              ),
              title: const Text('Export to Excel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Download .xlsx with all sessions + summary'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _export(context, ref),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Data'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Colors.red, size: 22),
              ),
              title: const Text('Clear All Data',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: Colors.red)),
              subtitle: const Text('Delete all study sessions'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _confirmClear(context, ref),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('Study Timer v1.0',
                style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.3),
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showTagEditor(BuildContext context, WidgetRef ref, SubjectTag? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagEditorSheet(existing: existing),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final sessions = ref.read(sessionsProvider).value ?? [];
    if (sessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sessions to export yet.')),
      );
      return;
    }
    try {
      await ExportService.exportToExcel(sessions);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
            'This will permanently delete all your study sessions. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final sessions = ref.read(sessionsProvider).value ?? [];
              for (final s in sessions) {
                await ref.read(sessionsProvider.notifier).delete(s.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All sessions deleted.')),
                );
              }
            },
            child: const Text('Delete All',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        ),
      ),
    );
  }
}

class _TagTile extends ConsumerWidget {
  final SubjectTag tag;
  const _TagTile({required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tag.color.withOpacity(0.15),
          child: Text(tag.emoji, style: const TextStyle(fontSize: 18)),
        ),
        title: Text(tag.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: tag.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _showEdit(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => _confirmDelete(context, ref),
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  void _showEdit(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagEditorSheet(existing: tag),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${tag.name}"?'),
        content: const Text('Past sessions with this tag will be kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tagsProvider.notifier).delete(tag.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _TagEditorSheet extends ConsumerStatefulWidget {
  final SubjectTag? existing;
  const _TagEditorSheet({this.existing});

  @override
  ConsumerState<_TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends ConsumerState<_TagEditorSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _emojiCtrl;
  late Color _selectedColor;
  static const _uuid = Uuid();

  static const _presetColors = [
    Color(0xFF6C63FF), Color(0xFF3ECFCF), Color(0xFFFF6584),
    Color(0xFFFFA500), Color(0xFF4CAF50), Color(0xFF9C27B0),
    Color(0xFF2196F3), Color(0xFFFF5722), Color(0xFF607D8B),
    Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _emojiCtrl = TextEditingController(text: widget.existing?.emoji ?? '📚');
    _selectedColor = widget.existing?.color ?? _presetColors.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(isEdit ? 'Edit Subject' : 'New Subject',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _emojiCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    decoration: const InputDecoration(labelText: 'Emoji'),
                    maxLength: 2,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                        const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Subject name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Color',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withOpacity(0.6))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: _presetColors.map((c) {
                final isSelected = _selectedColor.toARGB32() == c.toARGB32();
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: isSelected
                          ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 8)]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(backgroundColor: _selectedColor),
                child: Text(isEdit ? 'Save Changes' : 'Add Subject',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final tag = SubjectTag(
      id: widget.existing?.id ?? _uuid.v4(),
      name: name,
      colorValue: _selectedColor.toARGB32(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '📚' : _emojiCtrl.text.trim(),
    );

    if (widget.existing != null) {
      ref.read(tagsProvider.notifier).update(tag);
    } else {
      ref.read(tagsProvider.notifier).add(tag);
    }

    Navigator.pop(context);
  }
}
