import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/budget_provider.dart';
import '../../../shared/theme/app_colors.dart';

class BudgetRingChart extends ConsumerWidget {
  const BudgetRingChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisation = ref.watch(budgetUtilisationProvider);
    final budgets = ref.watch(budgetsProvider).asData?.value ?? [];

    if (budgets.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('No budgets set up yet. Add one in Settings.'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Budget Overview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sections: _buildSections(utilisation),
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(Map<String, double> utilisation) {
    if (utilisation.isEmpty) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade200,
          radius: 20,
          showTitle: false,
        ),
      ];
    }
    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
    ];
    return utilisation.entries.indexed.map((entry) {
      final (i, e) = entry;
      final pct = (e.value * 100).clamp(0.0, 100.0);
      return PieChartSectionData(
        value: pct,
        color: colors[i % colors.length],
        radius: 20,
        title: '${pct.toStringAsFixed(0)}%',
        titleStyle:
            const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      );
    }).toList();
  }
}
