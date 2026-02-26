import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';

class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlySpend = ref.watch(monthlySpendProvider);
    final lastMonthSpend = ref.watch(lastMonthSpendProvider);
    final spendByCategory = ref.watch(spendByCategoryProvider);
    final now = DateTime.now();
    final monthLabel = DateFormatter.formatMonthYear(now);

    // Top category this month
    final topEntry = spendByCategory.entries.isEmpty
        ? null
        : spendByCategory.entries.reduce(
            (a, b) => a.value >= b.value ? a : b);
    final topCategory = topEntry != null
        ? ref.watch(categoryByIdProvider(topEntry.key))
        : null;

    // Compute delta vs last month
    final hasDelta = lastMonthSpend > 0;
    final delta = monthlySpend - lastMonthSpend;
    final deltaPct = hasDelta ? (delta / lastMonthSpend * 100).abs() : 0.0;
    final isUp = delta > 0;
    final isDown = delta < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(monthlySpend, 'ZAR'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            if (hasDelta)
              Row(
                children: [
                  Icon(
                    isUp
                        ? Icons.arrow_upward
                        : isDown
                            ? Icons.arrow_downward
                            : Icons.remove,
                    size: 14,
                    color: isUp
                        ? Colors.red.shade600
                        : isDown
                            ? Colors.green.shade600
                            : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${deltaPct.toStringAsFixed(0)}% vs last month',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isUp
                              ? Colors.red.shade600
                              : isDown
                                  ? Colors.green.shade600
                                  : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              )
            else
              Text(
                'Total spend this month',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (topEntry != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    topCategory?.icon ?? '📋',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Top: ${topCategory?.name ?? topEntry.key}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(topEntry.value, 'ZAR'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
