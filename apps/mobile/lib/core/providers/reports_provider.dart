import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'transaction_provider.dart';

const reportPeriods = [
  'This Month',
  'Last Month',
  'Last 3 Months',
  'Last 6 Months',
  'This Year',
  'Last Year',
  'Custom…',
];

final reportPeriodProvider =
    StateProvider<String>((ref) => 'This Month');

/// Only used when reportPeriodProvider == 'Custom…'.
final reportCustomRangeProvider =
    StateProvider<(DateTime, DateTime)?>((_) => null);

(DateTime, DateTime) reportDateRange(String period) {
  final now = DateTime.now();
  final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
  switch (period) {
    case 'Last Month':
      final lastMonth = DateTime(now.year, now.month - 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (DateTime(lastMonth.year, lastMonth.month, 1), lastMonthEnd);
    case 'Last 3 Months':
      return (DateTime(now.year, now.month - 2, 1), end);
    case 'Last 6 Months':
      return (DateTime(now.year, now.month - 5, 1), end);
    case 'This Year':
      return (DateTime(now.year, 1, 1), end);
    case 'Last Year':
      return (DateTime(now.year - 1, 1, 1),
          DateTime(now.year - 1, 12, 31, 23, 59, 59));
    default: // This Month
      return (DateTime(now.year, now.month, 1), end);
  }
}

/// Date range of the period immediately preceding the selected one.
(DateTime, DateTime) _previousPeriodDateRange(String period) {
  final now = DateTime.now();
  switch (period) {
    case 'Last Month':
      final twoBack = DateTime(now.year, now.month - 2);
      final twoBackEnd = DateTime(now.year, now.month - 1, 0, 23, 59, 59);
      return (DateTime(twoBack.year, twoBack.month, 1), twoBackEnd);
    case 'Last 3 Months':
      return (DateTime(now.year, now.month - 5, 1),
          DateTime(now.year, now.month - 3, 0, 23, 59, 59));
    case 'Last 6 Months':
      return (DateTime(now.year, now.month - 11, 1),
          DateTime(now.year, now.month - 6, 0, 23, 59, 59));
    case 'This Year':
      // Compare to same YTD period last year for a fair comparison
      return (DateTime(now.year - 1, 1, 1),
          DateTime(now.year - 1, now.month, now.day, 23, 59, 59));
    case 'Last Year':
      // Compare to the year before
      return (DateTime(now.year - 2, 1, 1),
          DateTime(now.year - 2, 12, 31, 23, 59, 59));
    default: // This Month → compare to last month
      final lastMonth = DateTime(now.year, now.month - 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (DateTime(lastMonth.year, lastMonth.month, 1), lastMonthEnd);
  }
}

/// Total spend in the previous period (for comparison).
/// Returns 0 for custom ranges since there is no defined previous period.
final previousPeriodTotalProvider = Provider<double>((ref) {
  final period = ref.watch(reportPeriodProvider);
  if (period == 'Custom…') return 0.0;
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final (from, to) = _previousPeriodDateRange(period);
  return txns
      .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

final reportTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final (DateTime from, DateTime to) = period == 'Custom…'
      ? (ref.watch(reportCustomRangeProvider) ?? reportDateRange('This Month'))
      : reportDateRange(period);
  return txns
      .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
      .toList();
});

final reportTotalProvider = Provider<double>((ref) {
  return ref
      .watch(reportTransactionsProvider)
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

final reportSpendByCategoryProvider = Provider<Map<String, double>>((ref) {
  final txns = ref.watch(reportTransactionsProvider);
  final map = <String, double>{};
  for (final t in txns) {
    map[t.category] = (map[t.category] ?? 0.0) + t.amountZAR;
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return Map.fromEntries(sorted);
});

final reportSpendByMonthProvider = Provider<Map<String, double>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final txns = ref.watch(reportTransactionsProvider);
  final now = DateTime.now();

  final numMonths = switch (period) {
    'Last 3 Months' => 3,
    'Last 6 Months' => 6,
    'This Year' => now.month,
    'Last Year' => 12,
    _ => 1,
  };

  final isLastYear = period == 'Last Year';
  final baseYear = isLastYear ? now.year - 1 : now.year;
  final baseMonth = isLastYear ? 12 : now.month;

  // Build ordered map with every month initialised to 0
  final map = <String, double>{};
  for (int i = numMonths - 1; i >= 0; i--) {
    final m = DateTime(baseYear, baseMonth - i);
    map[_monthLabel(m)] = 0.0;
  }

  for (final t in txns) {
    final label = _monthLabel(t.date);
    if (map.containsKey(label)) {
      map[label] = (map[label] ?? 0.0) + t.amountZAR;
    }
  }

  return map;
});

/// Average spend per day of week (1=Monday…7=Sunday) across the period.
final reportSpendByDayOfWeekProvider = Provider<Map<int, double>>((ref) {
  final txns = ref.watch(reportTransactionsProvider);
  if (txns.isEmpty) return {};
  final sums = <int, double>{};
  final counts = <int, int>{};
  for (final t in txns) {
    final d = t.date.weekday;
    sums[d] = (sums[d] ?? 0.0) + t.amountZAR;
    counts[d] = (counts[d] ?? 0) + 1;
  }
  return {for (final d in sums.keys) d: sums[d]! / counts[d]!};
});

/// Top 5 vendors by spend in the selected period.
final reportTopVendorsProvider =
    Provider<List<MapEntry<String, double>>>((ref) {
  final txns = ref.watch(reportTransactionsProvider);
  final map = <String, double>{};
  for (final t in txns) {
    map[t.vendor] = (map[t.vendor] ?? 0.0) + t.amountZAR;
  }
  final sorted = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(5).toList();
});

/// Total tax-deductible spend in the selected period.
final reportTaxDeductibleProvider = Provider<double>((ref) {
  return ref
      .watch(reportTransactionsProvider)
      .where((t) => t.isTaxDeductible)
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

/// Tax-deductible transactions in the selected period, sorted newest first.
final reportTaxTransactionsProvider =
    Provider<List<TransactionModel>>((ref) {
  return ref
      .watch(reportTransactionsProvider)
      .where((t) => t.isTaxDeductible)
      .toList();
});

/// Spend by category for the previous period (for trend indicators).
final previousPeriodSpendByCategoryProvider =
    Provider<Map<String, double>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final (from, to) = _previousPeriodDateRange(period);
  final prevTxns =
      txns.where((t) => !t.date.isBefore(from) && !t.date.isAfter(to));
  final map = <String, double>{};
  for (final t in prevTxns) {
    map[t.category] = (map[t.category] ?? 0.0) + t.amountZAR;
  }
  return map;
});

/// Daily spend totals for a single-month period. Key = "YYYY-MM-DD".
/// Only populated when the selected period is a single month.
final reportSpendByDayProvider = Provider<Map<String, double>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  if (period != 'This Month' && period != 'Last Month') return {};
  final txns = ref.watch(reportTransactionsProvider);
  final map = <String, double>{};
  for (final t in txns) {
    final key =
        '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
    map[key] = (map[key] ?? 0.0) + t.amountZAR;
  }
  return map;
});

String _monthLabel(DateTime date) {
  const abbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${abbr[date.month - 1]} ${date.year.toString().substring(2)}';
}
