import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../shared/theme/app_colors.dart';

class SpendingBarChart extends StatefulWidget {
  final Map<String, double> dataByMonth;

  const SpendingBarChart({super.key, required this.dataByMonth});

  @override
  State<SpendingBarChart> createState() => _SpendingBarChartState();
}

class _SpendingBarChartState extends State<SpendingBarChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.dataByMonth.entries.toList();
    const primary = AppColors.primary;
    final highlight = primary.withValues(alpha: 0.85);

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(
          touchCallback: (FlTouchEvent event, barTouchResponse) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  barTouchResponse == null ||
                  barTouchResponse.spot == null) {
                _touchedIndex = -1;
                return;
              }
              _touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
            });
          },
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= entries.length) return null;
              return BarTooltipItem(
                CurrencyFormatter.format(rod.toY, 'ZAR'),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        barGroups: entries.indexed
            .map(
              (e) => BarChartGroupData(
                x: e.$1,
                barRods: [
                  BarChartRodData(
                    toY: e.$2.value,
                    color: e.$1 == _touchedIndex ? highlight : primary,
                    width: 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
                showingTooltipIndicators:
                    e.$1 == _touchedIndex ? [0] : [],
              ),
            )
            .toList(),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                final label = value >= 1000
                    ? 'R${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}k'
                    : 'R${value.toStringAsFixed(0)}';
                return Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox();
                return Text(
                  entries[i].key,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == _touchedIndex
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: i == _touchedIndex
                        ? AppColors.primary
                        : Colors.grey.shade600,
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
