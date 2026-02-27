import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/goal_provider.dart';
import '../../../core/providers/transaction_provider.dart';

class MonthlySummaryCard extends ConsumerWidget {
  const MonthlySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlySpend = ref.watch(monthlySpendProvider);
    final lastMonthSpend = ref.watch(lastMonthSpendProvider);
    final projectedMonthly = ref.watch(projectedMonthlySpendProvider);
    final spendByCategory = ref.watch(spendByCategoryProvider);
    final monthlyGoal = ref.watch(monthlyGoalProvider);
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
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: () => _setGoal(context, ref, monthlyGoal),
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                GestureDetector(
                  onTap: () => _setGoal(context, ref, monthlyGoal),
                  child: Text(
                    monthlyGoal == null ? 'Set goal' : 'Edit goal',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
            if (projectedMonthly > monthlySpend) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.trending_flat,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'On track for ${CurrencyFormatter.format(projectedMonthly, 'ZAR')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            ],
            if (monthlyGoal != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _GoalProgress(spend: monthlySpend, goal: monthlyGoal),
            ],
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
      ),
    );
  }

  Future<void> _setGoal(
      BuildContext context, WidgetRef ref, double? current) async {
    final ctrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(0) : '');
    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly Spending Goal'),
        content: TextField(
          controller: ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Goal amount (ZAR)',
            prefixText: 'R ',
          ),
          autofocus: true,
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, -1.0),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final goal = result < 0 ? null : result;
    ref.read(monthlyGoalProvider.notifier).state = goal;
    await MonthlyGoalService.save(goal);
  }
}

class _GoalProgress extends StatelessWidget {
  final double spend;
  final double goal;
  const _GoalProgress({required this.spend, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = (spend / goal).clamp(0.0, 1.0);
    final isOver = spend > goal;
    final remaining = goal - spend;
    final color = isOver
        ? Theme.of(context).colorScheme.error
        : progress > 0.8
            ? Colors.orange.shade600
            : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isOver
                  ? 'Over goal by ${CurrencyFormatter.format(-remaining, 'ZAR')}'
                  : '${CurrencyFormatter.format(remaining, 'ZAR')} remaining',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              'of ${CurrencyFormatter.format(goal, 'ZAR')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }
}
