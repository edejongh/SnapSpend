import 'package:flutter/material.dart';
import 'package:snapspend_core/snapspend_core.dart';

/// Calendar heatmap showing spending intensity per day.
/// Days with no spending are uncoloured; heavier days are darker.
class SpendingCalendar extends StatelessWidget {
  final Map<String, double> dailySpend;
  final DateTime month; // any day in the target month

  const SpendingCalendar({
    super.key,
    required this.dailySpend,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final year = month.year;
    final m = month.month;
    final daysInMonth = DateTimeRange(
      start: DateTime(year, m, 1),
      end: DateTime(year, m + 1, 1),
    ).duration.inDays;

    final firstWeekday = DateTime(year, m, 1).weekday; // 1=Mon
    final maxSpend = dailySpend.values.isEmpty
        ? 1.0
        : dailySpend.values.reduce((a, b) => a > b ? a : b);

    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day-of-week header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((d) => SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 1,
          ),
          itemCount: (firstWeekday - 1) + daysInMonth,
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) return const SizedBox.shrink();
            final day = index - (firstWeekday - 2); // 1-based
            final key =
                '$year-${m.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
            final spend = dailySpend[key] ?? 0.0;
            final intensity =
                maxSpend > 0 ? (spend / maxSpend).clamp(0.0, 1.0) : 0.0;

            final isToday = DateTime.now().year == year &&
                DateTime.now().month == m &&
                DateTime.now().day == day;

            return Tooltip(
              message: spend > 0
                  ? 'Day $day: ${CurrencyFormatter.format(spend, 'ZAR')}'
                  : 'Day $day: no spending',
              child: Container(
                decoration: BoxDecoration(
                  color: spend > 0
                      ? primary.withValues(alpha: 0.15 + intensity * 0.75)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                  border: isToday
                      ? Border.all(
                          color: primary,
                          width: 1.5,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                      color: intensity > 0.6
                          ? Colors.white
                          : Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.color,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Light',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 4),
            ...List.generate(5, (i) {
              final t = (i + 1) / 5.0;
              return Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15 + t * 0.75),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
            const SizedBox(width: 4),
            Text(
              'Heavy',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ],
    );
  }
}
