import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/budget_provider.dart';
import '../../../core/providers/category_provider.dart';

class BudgetRingChart extends ConsumerWidget {
  const BudgetRingChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utilisation = ref.watch(budgetUtilisationProvider);
    final budgets = ref.watch(budgetsProvider).asData?.value ?? [];

    if (budgets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'No budgets set up yet.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.push('/settings/budget'),
                child: const Text('Set up a budget'),
              ),
            ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budgets',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                TextButton(
                  onPressed: () => context.push('/settings/budget'),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...budgets.map((budget) {
              final key = budget.categoryId ?? 'overall';
              final pct = (utilisation[key] ?? 0.0).clamp(0.0, double.infinity);
              final spent = budget.limitAmount * pct;
              return _BudgetProgressRow(
                budget: budget,
                utilisation: pct,
                spent: spent,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BudgetProgressRow extends ConsumerWidget {
  final BudgetModel budget;
  final double utilisation;
  final double spent;

  const _BudgetProgressRow({
    required this.budget,
    required this.utilisation,
    required this.spent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = budget.categoryId != null
        ? ref.watch(categoryByIdProvider(budget.categoryId!))
        : null;
    final isOver = utilisation >= 1.0;
    final isWarning = utilisation >= budget.alertAt && !isOver;

    final barColor = isOver
        ? Theme.of(context).colorScheme.error
        : isWarning
            ? Colors.amber.shade600
            : Theme.of(context).colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: budget.categoryId != null
          ? () => context.go('/transactions', extra: budget.categoryId)
          : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            children: [
              if (category != null)
                Text(category.icon,
                    style: const TextStyle(fontSize: 14)),
              if (category != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  budget.name,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${CurrencyFormatter.format(spent, 'ZAR')} / ${CurrencyFormatter.format(budget.limitAmount, 'ZAR')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOver
                          ? Theme.of(context).colorScheme.error
                          : Colors.grey.shade600,
                      fontWeight:
                          isOver ? FontWeight.bold : FontWeight.normal,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: utilisation.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
