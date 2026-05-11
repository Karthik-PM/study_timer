import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../providers/sessions_provider.dart';
import '../widgets/stat_card.dart';

enum AnalyticsPeriod { week, month, allTime }

final _periodProvider = StateProvider((ref) => AnalyticsPeriod.week);

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(_periodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PeriodSelector(period: period),
            _SummaryCards(period: period),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Daily Study Time',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _DailyBarChart(period: period),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Text('By Subject',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
            _SubjectPieChart(period: period),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends ConsumerWidget {
  final AnalyticsPeriod period;
  const _PeriodSelector({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SegmentedButton<AnalyticsPeriod>(
        segments: const [
          ButtonSegment(value: AnalyticsPeriod.week, label: Text('Week')),
          ButtonSegment(value: AnalyticsPeriod.month, label: Text('Month')),
          ButtonSegment(value: AnalyticsPeriod.allTime, label: Text('All Time')),
        ],
        selected: {period},
        onSelectionChanged: (s) =>
            ref.read(_periodProvider.notifier).state = s.first,
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

(DateTime, DateTime) _range(AnalyticsPeriod period) {
  final now = DateTime.now();
  final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
  DateTime from;
  switch (period) {
    case AnalyticsPeriod.week:
      from = now.subtract(const Duration(days: 6));
    case AnalyticsPeriod.month:
      from = now.subtract(const Duration(days: 29));
    case AnalyticsPeriod.allTime:
      from = DateTime(2000);
  }
  return (DateTime(from.year, from.month, from.day), to);
}

class _SummaryCards extends ConsumerWidget {
  final AnalyticsPeriod period;
  const _SummaryCards({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return sessionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (allSessions) {
        final (from, to) = _range(period);
        final sessions = allSessions
            .where((s) =>
                s.startTime.isAfter(from) && s.startTime.isBefore(to))
            .toList();

        final totalSec = sessions.fold(0, (sum, s) => sum + s.durationSeconds);
        final hours = (totalSec / 3600).toStringAsFixed(1);
        final count = sessions.length;

        final avgSec = count == 0
            ? 0
            : (totalSec / count).round();
        final avgMin = avgSec ~/ 60;

        // Best day
        final dayTotals = <String, int>{};
        for (final s in sessions) {
          final key =
              '${s.startTime.year}-${s.startTime.month}-${s.startTime.day}';
          dayTotals[key] = (dayTotals[key] ?? 0) + s.durationSeconds;
        }
        final bestDaySec = dayTotals.values.isEmpty
            ? 0
            : dayTotals.values.reduce((a, b) => a > b ? a : b);
        final bestH = bestDaySec ~/ 3600;
        final bestM = (bestDaySec % 3600) ~/ 60;
        final bestStr = bestH > 0 ? '${bestH}h ${bestM}m' : '${bestM}m';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: 1.5,
            children: [
              StatCard(
                label: 'Total Hours',
                value: hours,
                subtitle: '$count sessions',
                color: colorScheme.primary,
                icon: Icons.timer_outlined,
              ),
              StatCard(
                label: 'Sessions',
                value: '$count',
                subtitle: period == AnalyticsPeriod.week ? 'this week' : period == AnalyticsPeriod.month ? 'this month' : 'all time',
                color: Colors.teal,
                icon: Icons.check_circle_outline_rounded,
              ),
              StatCard(
                label: 'Avg Session',
                value: '${avgMin}m',
                color: Colors.purple,
                icon: Icons.bar_chart_rounded,
              ),
              StatCard(
                label: 'Best Day',
                value: bestStr.isEmpty ? '—' : bestStr,
                color: Colors.orange,
                icon: Icons.emoji_events_outlined,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyBarChart extends ConsumerWidget {
  final AnalyticsPeriod period;
  const _DailyBarChart({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<Map<String, int>>(
      future: () {
        final (from, to) = _range(period);
        return DatabaseService.getDailySeconds(from, to);
      }(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 200, child: Center(child: CircularProgressIndicator()));
        }

        final data = snap.data!;
        if (data.isEmpty) {
          return SizedBox(
            height: 200,
            child: Center(
              child: Text('No data yet',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4))),
            ),
          );
        }

        final days = period == AnalyticsPeriod.week ? 7 : 30;
        final now = DateTime.now();
        final bars = <BarChartGroupData>[];
        final labels = <int, String>{};

        final dayFmt = DateFormat(days <= 7 ? 'EEE' : 'M/d');
        for (var i = days - 1; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final key =
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          final sec = data[key] ?? 0;
          final barIndex = days - 1 - i;
          bars.add(BarChartGroupData(
            x: barIndex,
            barRods: [
              BarChartRodData(
                toY: sec / 3600,
                color: colorScheme.primary,
                width: days <= 7 ? 24 : 10,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: (data.values.isEmpty
                          ? 1
                          : data.values.reduce((a, b) => a > b ? a : b)) /
                      3600 *
                      1.2,
                  color: colorScheme.primary.withOpacity(0.06),
                ),
              ),
            ],
          ));
          if (days <= 7 || i % 5 == 0) {
            labels[barIndex] = dayFmt.format(d);
          }
        }

        final maxY = data.values.isEmpty
            ? 1.0
            : data.values.reduce((a, b) => a > b ? a : b) / 3600 * 1.3;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: BarChart(
              BarChartData(
                maxY: maxY < 0.5 ? 1 : maxY,
                barGroups: bars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.onSurface.withOpacity(0.07),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (val, meta) {
                        final label = labels[val.toInt()];
                        if (label == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: colorScheme.onSurface.withOpacity(0.5))),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.toStringAsFixed(val < 1 ? 1 : 0)}h',
                        style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface.withOpacity(0.4)),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final h = rod.toY;
                      final label = h >= 1
                          ? '${h.toStringAsFixed(1)}h'
                          : '${(h * 60).toStringAsFixed(0)}m';
                      return BarTooltipItem(label,
                          const TextStyle(fontWeight: FontWeight.w700));
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SubjectPieChart extends ConsumerWidget {
  final AnalyticsPeriod period;
  const _SubjectPieChart({required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final sessionsAsync = ref.watch(sessionsProvider);

    return sessionsAsync.when(
      loading: () => const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox.shrink(),
      data: (allSessions) {
        final (from, to) = _range(period);
        final sessions = allSessions
            .where((s) =>
                s.startTime.isAfter(from) && s.startTime.isBefore(to))
            .toList();

        final tagTotals = <String, int>{};
        final tagColors = <String, Color>{};
        final tagEmojis = <String, String>{};
        for (final s in sessions) {
          tagTotals[s.tagName] = (tagTotals[s.tagName] ?? 0) + s.durationSeconds;
          tagColors[s.tagName] = Color(s.tagColor);
          tagEmojis[s.tagName] = s.tagEmoji;
        }

        if (tagTotals.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('No data yet',
                  style: TextStyle(color: colorScheme.onSurface.withOpacity(0.4))),
            ),
          );
        }

        final total = tagTotals.values.fold(0, (a, b) => a + b);
        final sections = tagTotals.entries.map((e) {
          final pct = e.value / total;
          return PieChartSectionData(
            value: e.value.toDouble(),
            color: tagColors[e.key]!,
            radius: 70,
            title: pct > 0.08 ? '${(pct * 100).toStringAsFixed(0)}%' : '',
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 40,
                      sectionsSpace: 3,
                      pieTouchData: PieTouchData(enabled: true),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: tagTotals.entries.map((e) {
                    final h = e.value ~/ 3600;
                    final m = (e.value % 3600) ~/ 60;
                    final timeStr = h > 0 ? '${h}h ${m}m' : '${m}m';
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tagEmojis[e.key]!,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: tagColors[e.key],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 4),
                        Text(timeStr,
                            style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withOpacity(0.5))),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
