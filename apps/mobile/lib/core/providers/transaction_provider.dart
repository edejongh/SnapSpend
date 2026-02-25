import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'hive_provider.dart';

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
    for (final id in existingIds.difference(incomingIds)) {
      await hive.deleteTransaction(id);
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      // Write to Hive immediately (optimistic) then Firestore
      await ref.read(hiveServiceProvider).saveTransaction(txn);
      await ref.read(firebaseServiceProvider).saveTransaction(uid, txn);
    });
  }

  Future<void> updateTransaction(TransactionModel txn) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await ref.read(hiveServiceProvider).saveTransaction(txn);
      await ref.read(firebaseServiceProvider).saveTransaction(uid, txn);
    });
  }

  Future<void> deleteTransaction(String txnId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await ref.read(hiveServiceProvider).deleteTransaction(txnId);
      await ref.read(firebaseServiceProvider).deleteTransaction(uid, txnId);
    });
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, void>(TransactionNotifier.new);
