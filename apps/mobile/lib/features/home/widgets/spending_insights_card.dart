import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/budget_provider.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';

class SpendingInsightsCard extends ConsumerWidget {
  const SpendingInsightsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgets = ref.watch(budgetsProvider).asData?.value ?? [];
    final isRecordMonth = ref.watch(isRecordMonthProvider);
    final topMerchant = ref.watch(topMerchantThisMonthProvider);
    final largest = ref.watch(largestTransactionThisMonthProvider);
    final monthlySpend = ref.watch(monthlySpendProvider);
    final lastMonthSpend = ref.watch(lastMonthSpendProvider);
    final projectedMonthly = ref.watch(projectedMonthlySpendProvider);
    final avgDaily = ref.watch(avgDailySpendProvider);
    final todaySpend = ref.watch(todaySpendProvider);
    final spendByCategory = ref.watch(spendByCategoryProvider);
    final avgMonthlyByCategory = ref.watch(avgMonthlyCategorySpendProvider);
    final categories = ref.watch(categoriesProvider);
    final skippedRecurring = ref.watch(skippedRecurringProvider);
    final peakDay = ref.watch(peakSpendDayProvider);
    final streak = ref.watch(spendingStreakProvider);
    final allTxns = ref.watch(transactionsProvider).asData?.value ?? [];

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

    // Record high month
    if (isRecordMonth) {
      insights.add(_Insight(
        icon: Icons.emoji_events_outlined,
        color: Colors.purple.shade600,
        text: 'This is your highest spending month on record — heads up!',
      ));
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

    // Category spike vs 3-month average
    {
      String? spikeCategory;
      double spikePct = 0;
      for (final entry in spendByCategory.entries) {
        final avg = avgMonthlyByCategory[entry.key];
        if (avg == null || avg < 50) continue; // ignore tiny categories
        final diff = entry.value - avg;
        if (diff < 100) continue; // needs meaningful absolute difference
        final pct = diff / avg * 100;
        if (pct >= 30 && pct > spikePct) {
          spikePct = pct;
          spikeCategory = entry.key;
        }
      }
      if (spikeCategory != null) {
        final catName = categories
                .cast<CategoryModel?>()
                .firstWhere((c) => c?.categoryId == spikeCategory,
                    orElse: () => null)
                ?.name ??
            spikeCategory!;
        insights.add(_Insight(
          icon: Icons.category_outlined,
          color: Colors.deepOrange.shade600,
          text:
              '$catName spending is ${spikePct.round()}% above your 3-month average',
        ));
      }
    }

    // Budget pace warning for category budgets heading for overspend
    {
      final now = DateTime.now();
      final daysElapsed = now.day;
      final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
      if (daysElapsed > 0) {
        for (final budget in budgets) {
          if (budget.categoryId == null) continue;
          if (budget.limitAmount <= 0) continue;
          final spend = spendByCategory[budget.categoryId] ?? 0.0;
          if (spend <= 0) continue;
          final util = spend / budget.limitAmount;
          if (util >= 1.0) continue; // already exceeded
          final dailyRate = spend / daysElapsed;
          final projected = dailyRate * daysInMonth;
          if (projected <= budget.limitAmount) continue;
          final remaining = budget.limitAmount - spend;
          final daysLeft = (remaining / dailyRate).floor();
          final catName = categories
                  .cast<CategoryModel?>()
                  .firstWhere((c) => c?.categoryId == budget.categoryId,
                      orElse: () => null)
                  ?.name ??
              budget.categoryId!;
          final catId = budget.categoryId!;
          insights.add(_Insight(
            icon: Icons.speed_outlined,
            color: Colors.orange.shade700,
            text: daysLeft < 1
                ? '$catName budget will run out today at this pace'
                : '$catName budget on pace to run out in $daysLeft day${daysLeft == 1 ? '' : 's'}',
            onTap: () => context.push('/transactions', extra: catId),
          ));
          break; // show at most one budget-pace insight
        }
      }
    }

    // Peak spend day of week
    if (peakDay != null) {
      insights.add(_Insight(
        icon: Icons.calendar_today_outlined,
        color: Colors.indigo.shade600,
        text: 'You tend to spend the most on $peakDay (last 90 days)',
      ));
    }

    // Skipped recurring expense — positive reinforcement
    if (skippedRecurring != null) {
      insights.add(_Insight(
        icon: Icons.savings_outlined,
        color: Colors.green.shade700,
        text:
            'No ${skippedRecurring.vendor} spend yet this month — usually '
            '${CurrencyFormatter.format(skippedRecurring.avgMonthlyAmount, 'ZAR')}/mo',
        onTap: () => context.go(
          '/transactions?search=${Uri.encodeComponent(skippedRecurring.vendor)}',
        ),
      ));
    }

    // Streak milestone — celebrate at 7/14/30/60/90 consecutive days
    const milestones = {7, 14, 30, 60, 90};
    if (milestones.contains(streak)) {
      insights.add(_Insight(
        icon: Icons.local_fire_department,
        color: Colors.deepOrange.shade600,
        text: '🔥 $streak-day tracking streak — impressive!',
      ));
    }

    // Weekend vs weekday spending pattern (last 30 days)
    {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      final recent = allTxns.where((t) => t.date.isAfter(cutoff)).toList();
      if (recent.length >= 8) {
        final weekendTxns = recent.where((t) => t.date.weekday >= 6);
        final weekdayTxns = recent.where((t) => t.date.weekday <= 5);
        final weekendDays = weekendTxns
            .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
            .toSet();
        final weekdayDays = weekdayTxns
            .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
            .toSet();
        if (weekendDays.isNotEmpty && weekdayDays.isNotEmpty) {
          final weekendAvg = weekendTxns.fold(0.0, (s, t) => s + t.amountZAR) /
              weekendDays.length;
          final weekdayAvg = weekdayTxns.fold(0.0, (s, t) => s + t.amountZAR) /
              weekdayDays.length;
          if (weekdayAvg > 0 && weekendAvg > weekdayAvg * 1.5) {
            final pct = ((weekendAvg / weekdayAvg - 1) * 100).round();
            insights.add(_Insight(
              icon: Icons.event_outlined,
              color: Colors.blue.shade700,
              text: 'Weekend spending is $pct% higher than weekdays (last 30 days)',
            ));
          }
        }
      }
    }

    // New vendor this month — first time ever seeing this merchant
    {
      final now = DateTime.now();
      final thisMonthTxns = allTxns
          .where((t) => t.date.year == now.year && t.date.month == now.month)
          .toList();
      if (thisMonthTxns.length >= 3) {
        final prevVendors = allTxns
            .where((t) =>
                !(t.date.year == now.year && t.date.month == now.month))
            .map((t) => t.vendor)
            .toSet();
        final newVendorTotals = <String, double>{};
        for (final t in thisMonthTxns) {
          if (!prevVendors.contains(t.vendor)) {
            newVendorTotals[t.vendor] =
                (newVendorTotals[t.vendor] ?? 0.0) + t.amountZAR;
          }
        }
        if (newVendorTotals.isNotEmpty) {
          final top = newVendorTotals.entries
              .reduce((a, b) => a.value >= b.value ? a : b);
          insights.add(_Insight(
            icon: Icons.new_releases_outlined,
            color: Colors.teal.shade600,
            text:
                'New this month: ${top.key} — ${CurrencyFormatter.format(top.value, 'ZAR')}',
            onTap: () => context.go(
              '/transactions?search=${Uri.encodeComponent(top.key)}',
            ),
          ));
        }
      }
    }

    // Tax-deductible spend summary (when >= R 500 this month)
    {
      final now = DateTime.now();
      final taxSpend = allTxns
          .where((t) =>
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.isTaxDeductible)
          .fold(0.0, (s, t) => s + t.amountZAR);
      if (taxSpend >= 500) {
        insights.add(_Insight(
          icon: Icons.receipt_long_outlined,
          color: Colors.teal.shade700,
          text:
              '${CurrencyFormatter.format(taxSpend, 'ZAR')} tax-deductible this month',
        ));
      }
    }

    // Nudge to set up a budget if none exist but there are transactions
    if (budgets.isEmpty && monthlySpend > 0) {
      insights.add(_Insight(
        icon: Icons.account_balance_wallet_outlined,
        color: Theme.of(context).colorScheme.primary,
        text: 'No budgets set up yet — add one to track your limits',
        onTap: () => context.push('/settings/budget'),
      ));
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    const maxShown = 2;
    final shown = insights.take(maxShown).toList();
    final remaining = insights.length - maxShown;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Insights',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (remaining > 0)
                  GestureDetector(
                    onTap: () => _showAllInsights(context, insights),
                    child: Text(
                      '$remaining more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
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

  void _showAllInsights(BuildContext context, List<_Insight> insights) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => _AllInsightsSheet(insights: insights),
    );
  }
}

class _AllInsightsSheet extends StatelessWidget {
  final List<_Insight> insights;
  const _AllInsightsSheet({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'All Insights',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < insights.length; i++) ...[
            _InsightRow(
              insight: insights[i].onTap == null
                  ? insights[i]
                  : _Insight(
                      icon: insights[i].icon,
                      color: insights[i].color,
                      text: insights[i].text,
                      onTap: () {
                        Navigator.pop(context);
                        insights[i].onTap!();
                      },
                    ),
            ),
            if (i < insights.length - 1) ...[
              const SizedBox(height: 4),
              const Divider(height: 16),
            ],
          ],
        ],
      ),
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback? onTap;
  const _Insight({required this.icon, required this.color, required this.text, this.onTap});
}

class _InsightRow extends StatelessWidget {
  final _Insight insight;
  const _InsightRow({required this.insight});

  @override
  Widget build(BuildContext context) {
    final row = Row(
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
        if (insight.onTap != null)
          Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
      ],
    );
    if (insight.onTap != null) {
      return GestureDetector(onTap: insight.onTap, child: row);
    }
    return row;
  }
}
