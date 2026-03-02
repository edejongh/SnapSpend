import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/analytics_provider.dart';

class RevenueChart extends ConsumerWidget {
  const RevenueChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyData = ref.watch(monthlySignupsProvider);
    final maxCount =
        monthlyData.map((e) => e.$2).fold(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'New Users by Month',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sign-ups over the last 6 months',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: maxCount == 0
                  ? Center(
                      child: Text(
                        'No sign-up data yet',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        maxY: (maxCount * 1.3).ceilToDouble(),
                        barGroups: List.generate(
                          monthlyData.length,
                          (i) => BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: monthlyData[i].$2.toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 28,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: (maxCount * 1.3).ceilToDouble(),
                                  color: Colors.grey.shade100,
                                ),
                              ),
                            ],
                          ),
                        ),
                        gridData: const FlGridData(
                          show: true,
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= monthlyData.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    monthlyData[i].$1,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final label = monthlyData[group.x].$1;
                              final count = rod.toY.toInt();
                              return BarTooltipItem(
                                '$label\n$count user${count == 1 ? '' : 's'}',
                                const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
