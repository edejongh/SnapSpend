import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'transaction_provider.dart';

const reportPeriods = [
  'This Month',
  'Last Month',
  'Last 3 Months',
  'Last 6 Months',
  'This Year',
];

final reportPeriodProvider =
    StateProvider<String>((ref) => 'This Month');

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
      return (DateTime(now.year - 1, 1, 1),
          DateTime(now.year - 1, 12, 31, 23, 59, 59));
    default: // This Month → compare to last month
      final lastMonth = DateTime(now.year, now.month - 1);
      final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
      return (DateTime(lastMonth.year, lastMonth.month, 1), lastMonthEnd);
  }
}

/// Total spend in the previous period (for comparison).
final previousPeriodTotalProvider = Provider<double>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final (from, to) = _previousPeriodDateRange(period);
  return txns
      .where((t) => !t.date.isBefore(from) && !t.date.isAfter(to))
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

final reportTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final period = ref.watch(reportPeriodProvider);
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final (from, to) = reportDateRange(period);
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
    _ => 1,
  };

  // Build ordered map with every month initialised to 0
  final map = <String, double>{};
  for (int i = numMonths - 1; i >= 0; i--) {
    final m = DateTime(now.year, now.month - i);
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

String _monthLabel(DateTime date) {
  const abbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${abbr[date.month - 1]} ${date.year.toString().substring(2)}';
}
