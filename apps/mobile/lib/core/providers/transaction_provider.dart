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
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, void>(TransactionNotifier.new);
