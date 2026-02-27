import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/reports_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../transactions/widgets/transaction_detail_sheet.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/filter_bar.dart';
import '../widgets/spending_bar_chart.dart';
import '../widgets/spending_calendar.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final total = ref.watch(reportTotalProvider);
    final previousTotal = ref.watch(previousPeriodTotalProvider);
    final spendByCategory = ref.watch(reportSpendByCategoryProvider);
    final spendByMonth = ref.watch(reportSpendByMonthProvider);
    final taxTotal = ref.watch(reportTaxDeductibleProvider);
    final taxTxns = ref.watch(reportTaxTransactionsProvider);
    final dayOfWeekSpend = ref.watch(reportSpendByDayOfWeekProvider);
    final topVendors = ref.watch(reportTopVendorsProvider);
    final dailySpend = ref.watch(reportSpendByDayProvider);
    final txnsAsync = ref.watch(transactionsProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
        ],
      ),
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
            _TotalCard(total: total, period: period, previousTotal: previousTotal),
            if (total > 0) ...[
              const SizedBox(height: 12),
              _PeriodSummaryCard(
                period: period,
                total: total,
                previousTotal: previousTotal,
                spendByCategory: spendByCategory,
              ),
            ],
            const SizedBox(height: 16),
            if (spendByMonth.isNotEmpty) ...[
              _SectionCard(
                title: 'Spending by Month',
                height: 200,
                child: SpendingBarChart(dataByMonth: spendByMonth),
              ),
              const SizedBox(height: 16),
            ],
            if (dailySpend.isNotEmpty) ...[
              _SectionCard(
                title: 'Daily Spending Heatmap',
                child: SpendingCalendar(
                  dailySpend: dailySpend,
                  month: period == 'Last Month'
                      ? DateTime(
                          DateTime.now().year, DateTime.now().month - 1)
                      : DateTime.now(),
                  onDayTap: (day) => _showDayTransactions(context, ref, day),
                ),
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
            if (topVendors.isNotEmpty) ...[
              const SizedBox(height: 16),
              _TopVendorsCard(vendors: topVendors, total: total),
            ],
            if (dayOfWeekSpend.isNotEmpty) ...[
              const SizedBox(height: 16),
              _DayOfWeekCard(data: dayOfWeekSpend),
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
            if (taxTotal > 0) ...[
              const SizedBox(height: 16),
              _TaxSummaryCard(total: taxTotal, transactions: taxTxns),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final txns = ref.read(reportTransactionsProvider);
    if (txns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    final categories = ref.read(categoriesProvider);
    final catById = {for (final c in categories) c.categoryId: c};

    final buffer = StringBuffer();
    buffer.writeln(
        'Date,Vendor,Category,Amount,Currency,Amount (ZAR),Tax Deductible,Note,Source');
    for (final t in txns) {
      final catName = catById[t.category]?.name ?? t.category;
      final note = (t.note ?? '').replaceAll(',', ';');
      buffer.writeln(
        '${t.date.toIso8601String().substring(0, 10)},'
        '"${t.vendor.replaceAll('"', "'")}",'
        '$catName,'
        '${t.amount.toStringAsFixed(2)},'
        '${t.currency},'
        '${t.amountZAR.toStringAsFixed(2)},'
        '${t.isTaxDeductible ? 'Yes' : 'No'},'
        '$note,'
        '${t.source}',
      );
    }

    final period = ref.read(reportPeriodProvider).replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/snapspend_${period}_$timestamp.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'SnapSpend Export — $period',
    );
  }

  void _showDayTransactions(
      BuildContext context, WidgetRef ref, DateTime day) {
    final allTxns = ref.read(reportTransactionsProvider);
    showDayTransactionsSheet(context, day, allTxns);
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  final String period;
  final double previousTotal;

  const _TotalCard({
    required this.total,
    required this.period,
    required this.previousTotal,
  });

  @override
  Widget build(BuildContext context) {
    final hasDelta = previousTotal > 0;
    final delta = total - previousTotal;
    final deltaPct =
        hasDelta ? (delta / previousTotal * 100).abs() : 0.0;
    final isUp = delta > 0;
    final isDown = delta < 0;

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
                    '${deltaPct.toStringAsFixed(0)}% vs previous period',
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
                'Total spend',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Period summary card ───────────────────────────────────────────────────────

class _PeriodSummaryCard extends ConsumerWidget {
  final String period;
  final double total;
  final double previousTotal;
  final Map<String, double> spendByCategory;

  const _PeriodSummaryCard({
    required this.period,
    required this.total,
    required this.previousTotal,
    required this.spendByCategory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(reportTransactionsProvider);
    final categories = ref.watch(categoriesProvider);
    final catById = {for (final c in categories) c.categoryId: c};

    // Top category by spend
    String? topCatName;
    double topCatAmount = 0;
    if (spendByCategory.isNotEmpty) {
      final top = spendByCategory.entries
          .reduce((a, b) => a.value >= b.value ? a : b);
      topCatName = catById[top.key]?.name ?? top.key;
      topCatAmount = top.value;
    }

    // Top vendor by visit count
    final vendorCounts = <String, int>{};
    for (final t in txns) {
      vendorCounts[t.vendor] = (vendorCounts[t.vendor] ?? 0) + 1;
    }
    final topVendorEntry = vendorCounts.isEmpty
        ? null
        : vendorCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);

    // Comparison sentence
    final hasDelta = previousTotal > 0;
    final delta = total - previousTotal;
    final isUp = delta > 0;
    final deltaPct =
        hasDelta ? (delta / previousTotal * 100).abs().toStringAsFixed(0) : '';

    final sentences = <String>[];
    if (hasDelta) {
      sentences.add(
        '${isUp ? 'Up' : 'Down'} $deltaPct% vs the previous period '
        '(${CurrencyFormatter.format(delta.abs(), 'ZAR')} ${isUp ? 'more' : 'less'}).',
      );
    }
    if (topCatName != null) {
      final pct = total > 0
          ? ' · ${(topCatAmount / total * 100).toStringAsFixed(0)}%'
          : '';
      sentences.add(
          'Biggest category: $topCatName (${CurrencyFormatter.format(topCatAmount, 'ZAR')}$pct).');
    }
    if (topVendorEntry != null && topVendorEntry.value >= 2) {
      sentences.add(
          'Most visited: ${topVendorEntry.key} (${topVendorEntry.value}×).');
    }
    if (txns.isNotEmpty) {
      sentences.add('${txns.length} transaction${txns.length == 1 ? '' : 's'} recorded.');
    }

    if (sentences.isEmpty) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_outline,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sentences.join('  '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.5,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final double? height;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.height,
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
            height != null ? SizedBox(height: height, child: child) : child,
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
    final prevByCategory = ref.watch(previousPeriodSpendByCategoryProvider);

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
              final prev = prevByCategory[e.key] ?? 0.0;
              final hasTrend = prev > 0;
              final isUp = hasTrend && e.value > prev;
              final isDown = hasTrend && e.value < prev;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.go('/transactions', extra: e.key),
                child: Padding(
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
                              Row(
                                children: [
                                  if (hasTrend)
                                    Icon(
                                      isUp
                                          ? Icons.arrow_upward
                                          : isDown
                                              ? Icons.arrow_downward
                                              : Icons.remove,
                                      size: 12,
                                      color: isUp
                                          ? Colors.red.shade600
                                          : isDown
                                              ? Colors.green.shade600
                                              : Colors.grey,
                                    ),
                                  if (hasTrend) const SizedBox(width: 2),
                                  Text(
                                    CurrencyFormatter.format(e.value, 'ZAR'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right,
                                      size: 16,
                                      color: Colors.grey.shade400),
                                ],
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
              ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TaxSummaryCard extends ConsumerWidget {
  final double total;
  final List<TransactionModel> transactions;

  const _TaxSummaryCard({
    required this.total,
    required this.transactions,
  });

  Future<void> _exportTax(
      BuildContext context, WidgetRef ref) async {
    final categories = ref.read(categoriesProvider);
    final catById = {for (final c in categories) c.categoryId: c};
    final period =
        ref.read(reportPeriodProvider).replaceAll(' ', '_');

    final buffer = StringBuffer();
    buffer.writeln(
        'Date,Vendor,Category,Amount (ZAR),Note');
    for (final t in transactions) {
      final catName = catById[t.category]?.name ?? t.category;
      final note = (t.note ?? '').replaceAll(',', ';');
      buffer.writeln(
        '${t.date.toIso8601String().substring(0, 10)},'
        '"${t.vendor.replaceAll('"', "'")}",'
        '$catName,'
        '${t.amountZAR.toStringAsFixed(2)},'
        '$note',
      );
    }

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
        '${dir.path}/snapspend_tax_${period}_$timestamp.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'SnapSpend Tax Report — $period',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long_outlined,
                    size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Tax Deductible',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(total, 'ZAR'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.download_outlined,
                      size: 18, color: Colors.green),
                  tooltip: 'Export tax report',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _exportTax(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...transactions.map((t) {
              final category = ref.watch(categoryByIdProvider(t.category));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(category?.icon ?? '📋'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.vendor,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          Text(
                            DateFormatter.formatDate(t.date),
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(t.amountZAR, 'ZAR'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
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

// ── Top vendors ───────────────────────────────────────────────────────────────

class _TopVendorsCard extends StatelessWidget {
  final List<MapEntry<String, double>> vendors;
  final double total;
  const _TopVendorsCard({required this.vendors, required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Vendors',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final entry in vendors) ...[
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => context.go(
                  '/transactions?search=${Uri.encodeComponent(entry.key)}',
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              entry.key,
                              style:
                                  Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                Text(
                                  CurrencyFormatter.format(
                                      entry.value, 'ZAR'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey.shade400),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: total > 0 ? entry.value / total : 0,
                          backgroundColor: Colors.grey.shade200,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Day-of-week chart ─────────────────────────────────────────────────────────

class _DayOfWeekCard extends StatelessWidget {
  final Map<int, double> data;
  const _DayOfWeekCard({required this.data});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0.0, max);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending by Day of Week',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Average spend per day over this period',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final weekday = i + 1;
                  final amount = data[weekday] ?? 0.0;
                  final fraction = maxVal > 0 ? (amount / maxVal) : 0.0;
                  final barH = (fraction * 56).clamp(4.0, 56.0);
                  final isWeekend = weekday >= 6;
                  final isMax = amount > 0 && amount == maxVal;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            height: barH,
                            decoration: BoxDecoration(
                              color: isMax
                                  ? Theme.of(context).colorScheme.primary
                                  : isWeekend
                                      ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _days[i],
                            style: TextStyle(
                              fontSize: 10,
                              color: isMax
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade500,
                              fontWeight: isMax
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
