import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/budget_provider.dart';

class BudgetAlertBanner extends ConsumerWidget {
  const BudgetAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(budgetAlertsProvider);
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final (budget, pct) in alerts)
          _AlertTile(budget: budget, utilisation: pct),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final BudgetModel budget;
  final double utilisation;

  const _AlertTile({required this.budget, required this.utilisation});

  @override
  Widget build(BuildContext context) {
    final isOver = utilisation >= 1.0;
    final zarUsed =
        CurrencyFormatter.format(budget.limitAmount * utilisation, 'ZAR');
    final zarLimit = CurrencyFormatter.format(budget.limitAmount, 'ZAR');
    final pctText = '${(utilisation * 100).toStringAsFixed(0)}%';

    return GestureDetector(
      onTap: () => budget.categoryId != null
          ? context.go('/transactions', extra: budget.categoryId)
          : context.go('/transactions?range=this_month'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isOver ? Colors.red.shade50 : Colors.amber.shade50,
          border: Border.all(
            color: isOver ? Colors.red.shade300 : Colors.amber.shade300,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isOver ? Icons.cancel_outlined : Icons.warning_amber,
              color: isOver ? Colors.red.shade700 : Colors.amber.shade700,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOver
                    ? '${budget.name}: over budget ($pctText — $zarUsed / $zarLimit)'
                    : '${budget.name}: $pctText used ($zarUsed / $zarLimit)',
                style: TextStyle(
                  color:
                      isOver ? Colors.red.shade900 : Colors.amber.shade900,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: isOver ? Colors.red.shade400 : Colors.amber.shade600,
            ),
          ],
        ),
      ),
    );
  }
}
