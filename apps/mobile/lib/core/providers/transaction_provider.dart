import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'hive_provider.dart';
import 'sync_provider.dart';

/// Reads from Hive (instant, offline-first).
/// Simultaneously subscribes to the Firestore stream and diff-syncs
/// any changes into Hive, which triggers the Hive stream to re-emit.
final transactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return const Stream.empty();

  final hive = ref.read(hiveServiceProvider);
  final firebase = ref.read(firebaseServiceProvider);

  // Background: Firestore → Hive diff sync
  final sub = firebase.watchTransactions(uid).listen((incoming) async {
    final existing = await hive.getAllTransactions();
    final existingIds = {for (final t in existing) t.txnId};
    final incomingIds = {for (final t in incoming) t.txnId};

    for (final txn in incoming) {
      await hive.saveTransaction(txn);
    }

    // Don't delete transactions that are pending a Firestore write —
    // they exist in Hive only because the write hasn't been replayed yet.
    final pendingOps = await hive.getPendingOps();
    final pendingSaveIds = pendingOps.values
        .where((op) => op['type'] == 'saveTransaction')
        .map((op) =>
            Map<String, dynamic>.from(op['data'] as Map)['txnId'] as String)
        .toSet();

    for (final id in existingIds.difference(incomingIds)) {
      if (!pendingSaveIds.contains(id)) {
        await hive.deleteTransaction(id);
      }
    }
  });
  ref.onDispose(sub.cancel);

  return hive.watchTransactions();
});

// Total spend this month
final monthlySpendProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  return txns
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

// Total spend last month
final lastMonthSpendProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  final lastMonth = DateTime(now.year, now.month - 1);
  return txns
      .where((t) =>
          t.date.year == lastMonth.year && t.date.month == lastMonth.month)
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

// Today's total spend
final todaySpendProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final today = DateTime.now();
  return txns
      .where((t) =>
          t.date.year == today.year &&
          t.date.month == today.month &&
          t.date.day == today.day)
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

// Transaction count this month
final monthlyTransactionCountProvider = Provider<int>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  return txns
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .length;
});

// Average daily spend this month (spend / days elapsed so far)
final avgDailySpendProvider = Provider<double>((ref) {
  final spend = ref.watch(monthlySpendProvider);
  final day = DateTime.now().day;
  if (day == 0) return 0.0;
  return spend / day;
});

// Transactions flagged for review (low OCR confidence)
final flaggedTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  return txns.where((t) => t.flaggedForReview).toList();
});

/// Total spend in the 7 days prior to this week (days 8–14 ago).
final previousWeekSpendProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final today = DateTime.now();
  final from = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: 14));
  final to = DateTime(today.year, today.month, today.day)
      .subtract(const Duration(days: 7));
  return txns
      .where((t) => !t.date.isBefore(from) && t.date.isBefore(to))
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

// Daily spend for the last 7 days, ordered oldest-first (day, total)
final weeklyDailySpendProvider =
    Provider<List<(DateTime, double)>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final today = DateTime.now();
  return List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    final key = DateTime(day.year, day.month, day.day);
    final total = txns
        .where((t) =>
            t.date.year == key.year &&
            t.date.month == key.month &&
            t.date.day == key.day)
        .fold(0.0, (sum, t) => sum + t.amountZAR);
    return (key, total);
  });
});

// Projected full-month spend based on daily average so far
final projectedMonthlySpendProvider = Provider<double>((ref) {
  final avgDaily = ref.watch(avgDailySpendProvider);
  final now = DateTime.now();
  final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
  return avgDaily * daysInMonth;
});

// Spend by category this month
final spendByCategoryProvider = Provider<Map<String, double>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  final thisMonth =
      txns.where((t) => t.date.year == now.year && t.date.month == now.month);
  final map = <String, double>{};
  for (final t in thisMonth) {
    map[t.category] = (map[t.category] ?? 0.0) + t.amountZAR;
  }
  return map;
});

// Most-visited vendor this month (only shown when visited 2+ times)
final topMerchantThisMonthProvider = Provider<(String, int)?>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  final thisMonth = txns
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .toList();
  if (thisMonth.isEmpty) return null;
  final counts = <String, int>{};
  for (final t in thisMonth) {
    counts[t.vendor] = (counts[t.vendor] ?? 0) + 1;
  }
  final top =
      counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return top.value >= 2 ? (top.key, top.value) : null;
});

// Largest single transaction this month
final largestTransactionThisMonthProvider =
    Provider<TransactionModel?>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  final thisMonth = txns
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .toList();
  if (thisMonth.isEmpty) return null;
  return thisMonth.reduce((a, b) => a.amountZAR >= b.amountZAR ? a : b);
});

/// Average monthly spend per category over the last 3 full months.
/// Key = categoryId, value = average monthly amount.
final avgMonthlyCategorySpendProvider =
    Provider<Map<String, double>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  // Look at the last 3 complete months
  final map = <String, double>{};
  for (int m = 1; m <= 3; m++) {
    final target = DateTime(now.year, now.month - m);
    final monthTxns = txns.where((t) =>
        t.date.year == target.year && t.date.month == target.month);
    for (final t in monthTxns) {
      map[t.category] = (map[t.category] ?? 0.0) + t.amountZAR;
    }
  }
  // Divide by 3 to get the monthly average
  return map.map((k, v) => MapEntry(k, v / 3));
});

/// A vendor that appears in ≥ 2 distinct calendar months.
class RecurringVendor {
  final String vendor;
  final String category;
  final double avgMonthlyAmount;
  final int monthCount;

  const RecurringVendor({
    required this.vendor,
    required this.category,
    required this.avgMonthlyAmount,
    required this.monthCount,
  });
}

/// Vendors that appear in 2+ distinct months — likely subscriptions.
/// Sorted by average monthly cost descending.
final recurringTransactionsProvider =
    Provider<List<RecurringVendor>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  if (txns.isEmpty) return [];

  // Group: vendor → set of "YYYY-MM" months it appears in
  final months = <String, Set<String>>{};
  final totals = <String, double>{};
  final categories = <String, String>{};

  for (final t in txns) {
    final key = t.vendor;
    final monthKey =
        '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
    months.putIfAbsent(key, () => {}).add(monthKey);
    totals[key] = (totals[key] ?? 0.0) + t.amountZAR;
    categories.putIfAbsent(key, () => t.category);
  }

  final recurring = <RecurringVendor>[];
  for (final vendor in months.keys) {
    final mc = months[vendor]!.length;
    if (mc >= 2) {
      recurring.add(RecurringVendor(
        vendor: vendor,
        category: categories[vendor]!,
        avgMonthlyAmount: totals[vendor]! / mc,
        monthCount: mc,
      ));
    }
  }

  recurring.sort((a, b) => b.avgMonthlyAmount.compareTo(a.avgMonthlyAmount));
  return recurring;
});

/// Number of consecutive days (ending today) on which at least one transaction
/// was recorded. Returns 0 if there's no transaction today.
final spendingStreakProvider = Provider<int>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  if (txns.isEmpty) return 0;

  final txnDays = txns
      .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
      .toSet();

  final today = DateTime.now();
  int streak = 0;
  var day = DateTime(today.year, today.month, today.day);

  while (txnDays.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
});

/// Whether the current month is the highest spending month ever recorded.
/// Returns false if there is only one month of data (no comparison possible).
final isRecordMonthProvider = Provider<bool>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  if (txns.isEmpty) return false;
  final now = DateTime.now();
  final monthTotals = <String, double>{};
  for (final t in txns) {
    final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
    monthTotals[key] = (monthTotals[key] ?? 0.0) + t.amountZAR;
  }
  final currentKey =
      '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final currentTotal = monthTotals[currentKey] ?? 0.0;
  if (currentTotal == 0) return false;
  final otherMonths =
      monthTotals.entries.where((e) => e.key != currentKey);
  if (otherMonths.isEmpty) return false;
  final prevMax = otherMonths.map((e) => e.value).reduce(
      (a, b) => a > b ? a : b);
  return currentTotal > prevMax;
});

/// The day of the week (1=Mon…7=Sun) with the highest average spend,
/// computed from the last 90 days. Returns null when insufficient data.
final peakSpendDayProvider = Provider<String?>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  if (txns.isEmpty) return null;
  final cutoff = DateTime.now().subtract(const Duration(days: 90));
  final recent = txns.where((t) => t.date.isAfter(cutoff)).toList();
  if (recent.length < 10) return null; // need enough data
  // Accumulate spend per weekday (Mon=1 … Sun=7)
  final totals = List.filled(8, 0.0); // index 0 unused
  final counts = List.filled(8, 0);
  for (final t in recent) {
    final d = t.date.weekday;
    totals[d] += t.amountZAR;
    counts[d]++;
  }
  // Find weekday with highest average spend (only consider days with ≥3 txns)
  int? peakDay;
  double peakAvg = 0;
  for (int d = 1; d <= 7; d++) {
    if (counts[d] < 3) continue;
    final avg = totals[d] / counts[d];
    if (avg > peakAvg) {
      peakAvg = avg;
      peakDay = d;
    }
  }
  if (peakDay == null) return null;
  const names = ['', 'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'];
  return names[peakDay];
});

/// The recurring vendor with the highest average monthly spend that hasn't
/// appeared in the current month yet (only shown after day 7).
/// Returns null if no such vendor exists.
final skippedRecurringProvider = Provider<RecurringVendor?>((ref) {
  final recurring = ref.watch(recurringTransactionsProvider);
  if (recurring.isEmpty) return null;
  final now = DateTime.now();
  if (now.day <= 7) return null; // too early to call it a skip
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final thisMonthVendors = txns
      .where((t) => t.date.year == now.year && t.date.month == now.month)
      .map((t) => t.vendor)
      .toSet();
  final skipped = recurring
      .where((r) => !thisMonthVendors.contains(r.vendor))
      .toList();
  return skipped.isEmpty ? null : skipped.first; // already sorted by avg desc
});

/// All distinct vendor names, sorted alphabetically. Used for autocomplete.
final allVendorNamesProvider = Provider<List<String>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final names = txns.map((t) => t.vendor).toSet().toList()..sort();
  return names;
});

/// Most-used category for a given vendor name (case-insensitive match).
/// Returns null if no prior transactions exist for that vendor.
final vendorCategoryProvider =
    Provider.family<String?, String>((ref, vendor) {
  if (vendor.trim().isEmpty) return null;
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final lower = vendor.trim().toLowerCase();
  final matches = txns.where((t) => t.vendor.toLowerCase() == lower);
  if (matches.isEmpty) return null;
  final counts = <String, int>{};
  for (final t in matches) {
    counts[t.category] = (counts[t.category] ?? 0) + 1;
  }
  return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
});

// Transaction CRUD notifier
class TransactionNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addTransaction(TransactionModel txn) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return;
    }
    // Write to Hive immediately — UI updates reactively
    await ref.read(hiveServiceProvider).saveTransaction(txn);
    state = const AsyncData(null);
    // Push to Firestore; enqueue for later replay if offline
    try {
      await ref.read(firebaseServiceProvider).saveTransaction(uid, txn);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'saveTransaction',
        'data': txn.toMap(),
      });
    }
    // Create admin review flag for low-confidence OCR scans (non-fatal)
    if (txn.flaggedForReview) {
      try {
        await ref.read(firebaseServiceProvider).createAdminFlag(uid, txn);
      } catch (_) {
        // Non-fatal — admin flag failure does not block the user
      }
    }
    FirebaseAnalytics.instance.logEvent(
      name: 'transaction_added',
      parameters: {
        'source': txn.source,
        'currency': txn.currency,
        'category': txn.category,
        'is_tax_deductible': txn.isTaxDeductible.toString(),
      },
    );
  }

  Future<void> updateTransaction(TransactionModel txn) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return;
    }
    await ref.read(hiveServiceProvider).saveTransaction(txn);
    state = const AsyncData(null);
    try {
      await ref.read(firebaseServiceProvider).saveTransaction(uid, txn);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'saveTransaction',
        'data': txn.toMap(),
      });
    }
  }

  Future<void> deleteTransaction(String txnId) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return;
    }
    await ref.read(hiveServiceProvider).deleteTransaction(txnId);
    state = const AsyncData(null);
    try {
      await ref.read(firebaseServiceProvider).deleteTransaction(uid, txnId);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'deleteTransaction',
        'id': txnId,
      });
    }
    FirebaseAnalytics.instance
        .logEvent(name: 'transaction_deleted');
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, void>(TransactionNotifier.new);
