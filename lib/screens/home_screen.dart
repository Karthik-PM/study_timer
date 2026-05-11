import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/study_session.dart';
import '../providers/timer_provider.dart';
import '../providers/sessions_provider.dart';
import '../widgets/tag_picker_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timer = ref.watch(timerProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = timer.selectedTag?.color ?? colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Timer'),
        actions: [
          _StreakBadge(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _TimerCard(timer: timer, tagColor: tagColor),
            const SizedBox(height: 20),
            _ControlButtons(timer: timer, tagColor: tagColor),
            const SizedBox(height: 32),
            _TodaySummary(),
            const SizedBox(height: 24),
            _RecentSessions(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _TimerCard extends ConsumerWidget {
  final TimerState timer;
  final Color tagColor;

  const _TimerCard({required this.timer, required this.tagColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: timer.status == TimerStatus.idle
          ? () => _showTagPicker(context, ref, timer)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              tagColor.withOpacity(0.15),
              tagColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: tagColor.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            if (timer.selectedTag != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(timer.selectedTag!.emoji,
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    timer.selectedTag!.name,
                    style: TextStyle(
                      color: tagColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (timer.status == TimerStatus.idle) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showTagPicker(context, ref, timer),
                      child: Icon(Icons.edit_outlined, color: tagColor, size: 16),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ] else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Tap to select a subject',
                  style: TextStyle(
                    color: colorScheme.onSurface.withOpacity(0.4),
                    fontSize: 14,
                  ),
                ),
              ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) => Opacity(opacity: value, child: child),
              child: Text(
                timer.formattedTime,
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w800,
                  color: timer.status == TimerStatus.running ? tagColor : colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -2,
                ),
              ),
            ),
            if (timer.status == TimerStatus.running) ...[
              const SizedBox(height: 8),
              _PulsingDot(color: tagColor),
            ],
          ],
        ),
      ),
    );
  }

  void _showTagPicker(BuildContext context, WidgetRef ref, TimerState timer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TagPickerSheet(
        selected: timer.selectedTag,
        onSelected: (tag) => ref.read(timerProvider.notifier).selectTag(tag),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: _anim.value,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text('Recording',
              style: TextStyle(
                color: widget.color.withOpacity(_anim.value),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }
}

class _ControlButtons extends ConsumerWidget {
  final TimerState timer;
  final Color tagColor;

  const _ControlButtons({required this.timer, required this.tagColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(timerProvider.notifier);

    if (timer.status == TimerStatus.idle) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: timer.selectedTag == null
              ? null
              : () => notifier.start(),
          icon: const Icon(Icons.play_arrow_rounded, size: 24),
          label: const Text('Start Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: FilledButton.styleFrom(
            backgroundColor: tagColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: tagColor.withOpacity(0.3),
          ),
        ),
      );
    }

    return Row(
      children: [
        if (timer.status == TimerStatus.running)
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: notifier.pause,
                icon: const Icon(Icons.pause_rounded),
                label: const Text('Pause', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: tagColor, width: 1.5),
                  foregroundColor: tagColor,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: notifier.resume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume', style: TextStyle(fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: tagColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
        const SizedBox(width: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _confirmStop(context, ref),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('Stop', style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              foregroundColor: Colors.redAccent,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmStop(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop session?'),
        content: Text(
            'Save this ${timer.formattedTime} session as "${timer.selectedTag?.name}"?'),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(timerProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            child: const Text('Discard', style: TextStyle(color: Colors.redAccent)),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final session = await ref.read(timerProvider.notifier).stop();
              if (session != null && context.mounted) {
                _showSessionSaved(context, session);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSessionSaved(BuildContext context, StudySession session) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(session.tagEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('${session.tagName} — ${session.formattedDuration} saved!'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _TodaySummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sessions) {
        final now = DateTime.now();
        final todaySessions = sessions.where((s) {
          final d = s.startTime;
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();

        if (todaySessions.isEmpty) return const SizedBox.shrink();

        final totalSec = todaySessions.fold(0, (sum, s) => sum + s.durationSeconds);
        final hours = totalSec ~/ 3600;
        final minutes = (totalSec % 3600) ~/ 60;
        final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.today_rounded, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timeStr,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary)),
                      Text('${todaySessions.length} session${todaySessions.length != 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.5))),
                    ],
                  ),
                  const Spacer(),
                  ...todaySessions
                      .map((s) => s.tagName)
                      .toSet()
                      .take(4)
                      .map((name) {
                    final s = todaySessions.firstWhere((ss) => ss.tagName == name);
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Tooltip(
                        message: s.tagName,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(s.tagColor).withOpacity(0.2),
                          child: Text(s.tagEmoji, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentSessions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sessions) {
        final recent = sessions.take(5).toList();
        if (recent.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Sessions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...recent.map((s) => _SessionTile(session: s)),
          ],
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  final dynamic session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagColor = Color(session.tagColor as int);
    final now = DateTime.now();
    final d = session.startTime as DateTime;
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    final dateStr = isToday
        ? 'Today ${_fmt(d)}'
        : '${d.month}/${d.day} ${_fmt(d)}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: tagColor.withOpacity(0.15),
          child: Text(session.tagEmoji as String,
              style: const TextStyle(fontSize: 18)),
        ),
        title: Text(session.tagName as String,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(dateStr,
            style: TextStyle(
                fontSize: 12, color: colorScheme.onSurface.withOpacity(0.5))),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            session.formattedDuration as String,
            style: TextStyle(
                color: tagColor, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final h = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _StreakBadge extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    return sessionsAsync.maybeWhen(
      data: (sessions) {
        int streak = 0;
        final now = DateTime.now();
        for (var i = 0; i < 365; i++) {
          final day = now.subtract(Duration(days: i));
          final hasSession = sessions.any((s) {
            final d = s.startTime;
            return d.year == day.year && d.month == day.month && d.day == day.day;
          });
          if (hasSession) {
            streak++;
          } else if (i > 0) {
            break;
          }
        }
        if (streak == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$streak',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
