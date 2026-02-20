import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';

// Watches transactions from Hive (offline-first)
final transactionsProvider =
    StreamProvider<List<TransactionModel>>((ref) async* {
  // TODO: Wire up to HiveService once implemented
  // For now, yields an empty list
  yield [];
});

// Total spend this month
final monthlySpendProvider = Provider<double>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  return txns
      .where(
        (t) => t.date.year == now.year && t.date.month == now.month,
      )
      .fold(0.0, (sum, t) => sum + t.amountZAR);
});

// Spend by category this month
final spendByCategoryProvider = Provider<Map<String, double>>((ref) {
  final txns = ref.watch(transactionsProvider).asData?.value ?? [];
  final now = DateTime.now();
  final thisMonth = txns.where(
    (t) => t.date.year == now.year && t.date.month == now.month,
  );
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
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.saveTransaction(uid, txn);
      // TODO: Also save to Hive for offline-first
    });
  }

  Future<void> updateTransaction(TransactionModel txn) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.saveTransaction(uid, txn);
    });
  }

  Future<void> deleteTransaction(String txnId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.deleteTransaction(uid, txnId);
    });
  }
}

final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, void>(TransactionNotifier.new);
