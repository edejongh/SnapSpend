import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/reports_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/filter_bar.dart';
import '../widgets/spending_bar_chart.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final total = ref.watch(reportTotalProvider);
    final spendByCategory = ref.watch(reportSpendByCategoryProvider);
    final spendByMonth = ref.watch(reportSpendByMonthProvider);
    final txnsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilterBar(
              periods: reportPeriods,
              selected: period,
              onChanged: (p) =>
                  ref.read(reportPeriodProvider.notifier).state = p,
            ),
            const SizedBox(height: 16),
            _TotalCard(total: total, period: period),
            const SizedBox(height: 16),
            if (spendByMonth.isNotEmpty) ...[
              _SectionCard(
                title: 'Spending by Month',
                height: 200,
                child: SpendingBarChart(dataByMonth: spendByMonth),
              ),
              const SizedBox(height: 16),
            ],
            if (spendByCategory.isNotEmpty) ...[
              _SectionCard(
                title: 'Spending by Category',
                height: 220,
                child: CategoryPieChart(spendByCategory: spendByCategory),
              ),
              const SizedBox(height: 16),
              _CategoryBreakdown(
                spendByCategory: spendByCategory,
                total: total,
              ),
            ],
            if (spendByCategory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'No transactions in this period',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final String period;

  const _TotalCard({required this.total, required this.period});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              period,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(total, 'ZAR'),
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Total spend',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final double height;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(height: height, child: child),
          ],
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends ConsumerWidget {
  final Map<String, double> spendByCategory;
  final double total;

  const _CategoryBreakdown({
    required this.spendByCategory,
    required this.total,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Breakdown',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...spendByCategory.entries.map((e) {
              final category = ref.watch(categoryByIdProvider(e.key));
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(
                      category?.icon ?? '📋',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                category?.name ?? e.key,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                CurrencyFormatter.format(e.value, 'ZAR'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.grey.shade200,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
