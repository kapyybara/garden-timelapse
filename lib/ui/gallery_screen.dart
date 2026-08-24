import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/daily_record.dart';
import '../state/providers.dart';
import 'app_theme.dart';
import 'day_detail_screen.dart';

/// Calendar-based gallery: month grid with per-day shot dots.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  late DateTime _month; // first of the displayed month
  final Map<String, DailyRecord> _days = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final start = DateFormat('yyyy-MM-dd').format(_month);
    final end =
        DateFormat('yyyy-MM-dd').format(_month.add(const Duration(days: 31)));
    final records = await ref.read(databaseProvider).getDaysInRange(start, end);
    if (!mounted) return;
    setState(() {
      _days.clear();
      for (final r in records) {
        _days[r.date] = r;
      }
      _loading = false;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      var y = _month.year;
      var m = _month.month + delta;
      if (m < 1) {
        m = 12;
        y -= 1;
      } else if (m > 12) {
        m = 1;
        y += 1;
      }
      _month = DateTime(y, m, 1);
      _load();
    });
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    // Reload when a record changes anywhere (capture, note, delete). The
    // shell keeps this tab alive, so the one-time initState load is stale.
    ref.listen(recordsVersionProvider, (_, __) => _load());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftMonth(-1),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_month),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _month.isBefore(DateTime.now())
                      ? () => _shiftMonth(1)
                      : null,
                ),
                const SizedBox(width: 4),
                FilledButton.tonal(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _month = DateTime(now.year, now.month, 1);
                    _load();
                  }),
                  child: const Text('Today'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentColor))
          : Column(
              children: [
                const _WeekdayHeader(),
                Expanded(child: _MonthGrid(state: this)),
              ],
            ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
            Expanded(
              child: Center(
                child: Text(
                  d,
                  style: const TextStyle(color: AppTheme.mutedColor, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.state});
  final _GalleryScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = state._month;
    final daysInMonth =
        DateTime(first.year, first.month + 1, 0).day;

    // Offset for the first weekday (Monday-start).
    final firstWeekday = first.weekday; // Mon=1 .. Sun=7
    final leading = firstWeekday - 1;

    final cells = <Widget>[];
    // Leading blanks
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(first.year, first.month, day);
      final key = state._key(date);
      final record = state._days[key];
      final isToday = key == state._key(DateTime.now());
      final has1 = record?.shot1 != null;
      final has2 = record?.shot2 != null;
      final missed = record == null || !record.hasAnyShot;

      cells.add(
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DayDetailScreen(date: key),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: missed
                  ? AppTheme.cardColor
                  : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: isToday
                  ? Border.all(color: AppTheme.accentColor, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    color: isToday ? AppTheme.accentColor : AppTheme.textColor,
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(has1, AppTheme.accentColor),
                    const SizedBox(width: 4),
                    _dot(has2, AppTheme.warnColor),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.05,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      padding: const EdgeInsets.all(10),
      itemCount: cells.length,
      itemBuilder: (context, i) => cells[i],
    );
  }

  Widget _dot(bool on, Color color) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: on ? color : AppTheme.mutedColor.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
    );
  }
}
