import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/theme/app_colors.dart';

class CategoryPieChart extends ConsumerWidget {
  const CategoryPieChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendByCategory = ref.watch(spendByCategoryProvider);

    if (spendByCategory.isEmpty) {
      return const Center(child: Text('No data for this period'));
    }

    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.warning,
      AppColors.error,
      Colors.purple,
      Colors.teal,
    ];

    final total = spendByCategory.values.fold(0.0, (a, b) => a + b);
    final sections = spendByCategory.entries.indexed.map((e) {
      final (i, entry) = e;
      final pct = total > 0 ? (entry.value / total) * 100 : 0.0;
      return PieChartSectionData(
        value: entry.value,
        color: colors[i % colors.length],
        title: '${pct.toStringAsFixed(1)}%',
        titleStyle:
            const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        radius: 80,
      );
    }).toList();

    return PieChart(PieChartData(sections: sections, sectionsSpace: 2));
  }
}
