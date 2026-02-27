import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/transaction_provider.dart';

class SpendingInsightsCard extends ConsumerWidget {
  const SpendingInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topMerchant = ref.watch(topMerchantThisMonthProvider);
    final largest = ref.watch(largestTransactionThisMonthProvider);
    final monthlySpend = ref.watch(monthlySpendProvider);
    final lastMonthSpend = ref.watch(lastMonthSpendProvider);
    final projectedMonthly = ref.watch(projectedMonthlySpendProvider);
    final avgDaily = ref.watch(avgDailySpendProvider);
    final todaySpend = ref.watch(todaySpendProvider);

    final insights = <_Insight>[];

    // Today vs daily average
    if (avgDaily > 0 && todaySpend > 0) {
      final diff = todaySpend - avgDaily;
      final pct = (diff / avgDaily * 100).abs().round();
      if (pct >= 20) {
        insights.add(_Insight(
          icon: diff > 0 ? Icons.trending_up : Icons.trending_down,
          color: diff > 0 ? Colors.orange.shade700 : Colors.green.shade700,
          text: diff > 0
              ? 'Today\'s spend is ${pct}% above your daily average'
              : 'Today\'s spend is ${pct}% below your daily average — nice!',
        ));
      }
    }

    // Month-over-month trend
    if (lastMonthSpend > 0 && monthlySpend > 0) {
      final delta = monthlySpend - lastMonthSpend;
      final pct = (delta / lastMonthSpend * 100).abs().round();
      if (pct >= 10) {
        insights.add(_Insight(
          icon: delta > 0 ? Icons.arrow_upward : Icons.arrow_downward,
          color:
              delta > 0 ? Colors.red.shade600 : Colors.green.shade600,
          text: delta > 0
              ? 'Spending is ${pct}% higher than last month so far'
              : 'Spending is ${pct}% lower than last month — great!',
        ));
      }
    }

    // Projection warning
    if (projectedMonthly > lastMonthSpend * 1.2 && lastMonthSpend > 0) {
      insights.add(_Insight(
        icon: Icons.warning_amber_outlined,
        color: Colors.amber.shade700,
        text:
            'On track to spend ${((projectedMonthly / lastMonthSpend - 1) * 100).round()}% more than last month',
      ));
    }

    // Top merchant
    if (topMerchant != null) {
      final (name, count) = topMerchant;
      insights.add(_Insight(
        icon: Icons.store_outlined,
        color: Theme.of(context).colorScheme.primary,
        text: 'You\'ve visited $name $count times this month',
      ));
    }

    // Largest transaction
    if (largest != null) {
      insights.add(_Insight(
        icon: Icons.receipt_long_outlined,
        color: Colors.grey.shade600,
        text:
            'Biggest expense: ${largest.vendor} — ${CurrencyFormatter.format(largest.amountZAR, 'ZAR')}',
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    // Show at most 2 insights to keep the card compact
    final shown = insights.take(2).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insights',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            for (final insight in shown) ...[
              _InsightRow(insight: insight),
              if (insight != shown.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  const _Insight({required this.icon, required this.color, required this.text});
}

class _InsightRow extends StatelessWidget {
  final _Insight insight;
  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(insight.icon, size: 16, color: insight.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            insight.text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade800,
                ),
          ),
        ),
      ],
    );
  }
}
