import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'transaction_provider.dart';

// Watches budgets from Hive (offline-first)
final budgetsProvider = StreamProvider<List<BudgetModel>>((ref) async* {
  // TODO: Wire up to HiveService once implemented
  yield [];
});

// Budget utilisation: categoryId → % used (0.0–1.0)
final budgetUtilisationProvider = Provider<Map<String, double>>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? [];
  final spendByCategory = ref.watch(spendByCategoryProvider);
  final monthlySpend = ref.watch(monthlySpendProvider);

  final map = <String, double>{};
  for (final budget in budgets) {
    if (budget.limitAmount <= 0) continue;
    if (budget.categoryId == null) {
      // Overall budget
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
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.saveBudget(uid, budget);
    });
  }

  Future<void> updateBudget(BudgetModel budget) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final uid = ref.read(authStateProvider).asData?.value?.uid;
      if (uid == null) throw Exception('Not authenticated');
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.saveBudget(uid, budget);
    });
  }

  Future<void> deleteBudget(String budgetId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // TODO: Add deleteBudget to FirebaseService
    });
  }
}

final budgetNotifierProvider =
    AsyncNotifierProvider<BudgetNotifier, void>(BudgetNotifier.new);
