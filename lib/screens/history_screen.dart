import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/study_session.dart';
import '../providers/sessions_provider.dart';
import '../providers/tags_provider.dart';
final _filterTagProvider = StateProvider<String?>((ref) => null);

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterTag = ref.watch(_filterTagProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (filterTag != null)
            TextButton(
              onPressed: () => ref.read(_filterTagProvider.notifier).state = null,
              child: const Text('Clear filter'),
            ),
        ],
      ),
      body: Column(
        children: [
          _TagFilterBar(selectedTagId: filterTag),
          Expanded(
            child: sessionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (sessions) {
                final filtered = filterTag == null
                    ? sessions
                    : sessions.where((s) => s.tagId == filterTag).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            size: 64,
                            color: colorScheme.onSurface.withOpacity(0.2)),
                        const SizedBox(height: 16),
                        Text('No sessions yet',
                            style: TextStyle(
                                color: colorScheme.onSurface.withOpacity(0.4),
                                fontSize: 16)),
                      ],
                    ),
                  );
                }

                // Group by date
                final grouped = <String, List<StudySession>>{};
                final dateFormat = DateFormat('EEEE, MMM d');
                final now = DateTime.now();
                for (final s in filtered) {
                  final d = s.startTime;
                  final isToday =
                      d.year == now.year && d.month == now.month && d.day == now.day;
                  final isYesterday = d.year == now.year &&
                      d.month == now.month &&
                      d.day == now.day - 1;
                  final key = isToday
                      ? 'Today'
                      : isYesterday
                          ? 'Yesterday'
                          : dateFormat.format(d);
                  grouped.putIfAbsent(key, () => []).add(s);
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: grouped.length,
                  itemBuilder: (context, index) {
                    final dateKey = grouped.keys.elementAt(index);
                    final daySessions = grouped[dateKey]!;
                    final dayTotal = daySessions.fold(
                        0, (sum, s) => sum + s.durationSeconds);
                    final h = dayTotal ~/ 3600;
                    final m = (dayTotal % 3600) ~/ 60;
                    final totalStr = h > 0 ? '${h}h ${m}m' : '${m}m';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Row(
                            children: [
                              Text(dateKey,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.6))),
                              const Spacer(),
                              Text(totalStr,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: colorScheme.primary)),
                            ],
                          ),
                        ),
                        ...daySessions.map((s) => _SessionCard(
                              session: s,
                              onDelete: () => ref
                                  .read(sessionsProvider.notifier)
                                  .delete(s.id),
                            )),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilterBar extends ConsumerWidget {
  final String? selectedTagId;

  const _TagFilterBar({this.selectedTagId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagsProvider);

    return tagsAsync.maybeWhen(
      data: (tags) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: tags.map((tag) {
            final isSelected = selectedTagId == tag.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${tag.emoji} ${tag.name}'),
                selected: isSelected,
                onSelected: (_) {
                  ref.read(_filterTagProvider.notifier).state =
                      isSelected ? null : tag.id;
                },
                selectedColor: tag.color.withOpacity(0.2),
                checkmarkColor: tag.color,
                labelStyle: TextStyle(
                  color: isSelected ? tag.color : null,
                  fontWeight: FontWeight.w500,
                ),
                side: BorderSide(
                  color: isSelected ? tag.color : Colors.transparent,
                ),
              ),
            );
          }).toList(),
        ),
      ),
      orElse: () => const SizedBox(height: 52),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final StudySession session;
  final VoidCallback onDelete;

  const _SessionCard({required this.session, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = Color(session.tagColor);
    final timeFormat = DateFormat('h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(session.tagEmoji,
                  style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.tagName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    '${timeFormat.format(session.startTime)} → ${timeFormat.format(session.endTime)}',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.5)),
                  ),
                  if (session.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(session.notes,
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(session.formattedDuration,
                      style: TextStyle(
                          color: tagColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _confirmDelete(context),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurface.withOpacity(0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
