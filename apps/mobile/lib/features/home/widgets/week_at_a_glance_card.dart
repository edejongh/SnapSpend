import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../transactions/widgets/transaction_detail_sheet.dart';

class WeekAtAGlanceCard extends ConsumerWidget {
  const WeekAtAGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(weeklyDailySpendProvider);
    final allTxns = ref.watch(transactionsProvider).asData?.value ?? [];
    final prevWeekTotal = ref.watch(previousWeekSpendProvider);
    final maxSpend = data.map((e) => e.$2).fold(0.0, max);
    final weekTotal = data.fold(0.0, (sum, e) => sum + e.$2);
    final daysWithSpend = data.where((e) => e.$2 > 0).length;
    final weekAvg = daysWithSpend > 0 ? weekTotal / daysWithSpend : 0.0;

    final hasDelta = prevWeekTotal > 0 && weekTotal > 0;
    final delta = weekTotal - prevWeekTotal;
    final deltaPct = hasDelta ? (delta / prevWeekTotal * 100).abs().round() : 0;
    final isUp = delta > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last 7 Days',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (weekTotal > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasDelta) ...[
                        Icon(
                          isUp ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 11,
                          color: isUp
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                        ),
                        Text(
                          '$deltaPct% ',
                          style: TextStyle(
                            fontSize: 11,
                            color: isUp
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      Text(
                        CurrencyFormatter.format(weekTotal, 'ZAR'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: Stack(
                children: [
                  // Average reference line
                  if (weekAvg > 0 && maxSpend > 0)
                    Positioned(
                      bottom: 16 + (52 * (weekAvg / maxSpend)).clamp(4.0, 52.0),
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        painter: _DashedLinePainter(
                            color: Colors.grey.shade400),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: data.map((entry) {
                      final (day, amount) = entry;
                      final isToday = _isToday(day);
                      final isMax = amount > 0 && amount == maxSpend;
                      final showLabel = isToday || isMax;
                      final fraction =
                          maxSpend > 0 ? (amount / maxSpend) : 0.0;
                      final barHeight = (fraction * 52).clamp(4.0, 52.0);

                      return Expanded(
                        child: GestureDetector(
                          onTap: amount > 0
                              ? () => showDayTransactionsSheet(context, day, allTxns)
                              : null,
                          child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (showLabel && amount > 0) ...[
                                Text(
                                  CurrencyFormatter.format(amount, 'ZAR'),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isToday
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                              ] else
                                const SizedBox(height: 13),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOut,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : isMax
                                          ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                          : Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _dayLabel(day),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey.shade500,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  String _dayLabel(DateTime day) {
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return names[day.weekday - 1];
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const dashWidth = 4.0;
    const gapWidth = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
