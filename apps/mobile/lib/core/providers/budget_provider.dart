import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'transaction_provider.dart';

// Watches budgets for the current user in real-time from Firestore
final budgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firebaseServiceProvider).watchBudgets(uid);
});

// Budget utilisation: categoryId (or 'overall') → % used (0.0–1.0)
final budgetUtilisationProvider = Provider<Map<String, double>>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? [];
  final spendByCategory = ref.watch(spendByCategoryProvider);
  final monthlySpend = ref.watch(monthlySpendProvider);

  final map = <String, double>{};
  for (final budget in budgets) {
    if (budget.limitAmount <= 0) continue;
    if (budget.categoryId == null) {
      map['overall'] = monthlySpend / budget.limitAmount;
    } else {
      final spend = spendByCategory[budget.categoryId] ?? 0.0;
      map[budget.categoryId!] = spend / budget.limitAmount;
    }
  }
  return map;
});

// Budget CRUD notifier
class BudgetNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> addBudget(BudgetModel budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await ref.read(firebaseServiceProvider).saveBudget(uid, budget);
    });
  }

  Future<void> updateBudget(BudgetModel budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await ref.read(firebaseServiceProvider).saveBudget(uid, budget);
    });
  }

  Future<void> deleteBudget(String budgetId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      await ref.read(firebaseServiceProvider).deleteBudget(uid, budgetId);
    });
  }
}

final budgetNotifierProvider =
    AsyncNotifierProvider<BudgetNotifier, void>(BudgetNotifier.new);
