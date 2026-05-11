import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/subject_tag.dart';
import '../providers/tags_provider.dart';

class TagPickerSheet extends ConsumerStatefulWidget {
  final SubjectTag? selected;
  final ValueChanged<SubjectTag> onSelected;

  const TagPickerSheet({super.key, this.selected, required this.onSelected});

  @override
  ConsumerState<TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<TagPickerSheet> {
  bool _showCustomInput = false;
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '📚');
  static const _uuid = Uuid();

  static const _quickColors = [
    Color(0xFF6C63FF), Color(0xFF3ECFCF), Color(0xFFFF6584),
    Color(0xFFFFA500), Color(0xFF4CAF50), Color(0xFF9C27B0),
    Color(0xFF2196F3), Color(0xFFFF5722),
  ];
  Color _selectedColor = const Color(0xFF6C63FF);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  void _createAndSelect() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final tag = SubjectTag(
      id: _uuid.v4(),
      name: name,
      colorValue: _selectedColor.toARGB32(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '📚' : _emojiCtrl.text.trim(),
    );
    ref.read(tagsProvider.notifier).add(tag);
    widget.onSelected(tag);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Select Subject',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Existing tags
            tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (tags) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: tags.map((tag) {
                  final isSelected = widget.selected?.id == tag.id;
                  final tagColor = tag.color;
                  return GestureDetector(
                    onTap: () {
                      widget.onSelected(tag);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? tagColor : tagColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? tagColor : tagColor.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tag.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            tag.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : tagColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Custom subject toggle
            if (!_showCustomInput)
              GestureDetector(
                onTap: () => setState(() => _showCustomInput = true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Create custom subject',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _CustomSubjectForm(
                nameCtrl: _nameCtrl,
                emojiCtrl: _emojiCtrl,
                selectedColor: _selectedColor,
                colors: _quickColors,
                onColorSelected: (c) => setState(() => _selectedColor = c),
                onCancel: () => setState(() => _showCustomInput = false),
                onCreate: _createAndSelect,
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomSubjectForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController emojiCtrl;
  final Color selectedColor;
  final List<Color> colors;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onCancel;
  final VoidCallback onCreate;

  const _CustomSubjectForm({
    required this.nameCtrl,
    required this.emojiCtrl,
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
    required this.onCancel,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: TextField(
                controller: emojiCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22),
                decoration: const InputDecoration(
                  labelText: 'Icon',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                maxLength: 2,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    const SizedBox.shrink(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Subject name'),
                onSubmitted: (_) => onCreate(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: colors.map((c) {
            final isSelected = selectedColor.toARGB32() == c.toARGB32();
            return GestureDetector(
              onTap: () => onColorSelected(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                  boxShadow: isSelected ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 6)] : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onCreate,
                style: FilledButton.styleFrom(backgroundColor: selectedColor),
                child: const Text('Create & Select', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
