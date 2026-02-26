import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'hive_provider.dart';
import 'sync_provider.dart';
import 'transaction_provider.dart';

/// Reads from Hive (instant, offline-first).
/// Simultaneously subscribes to the Firestore stream and diff-syncs
/// any changes into Hive, which triggers the Hive stream to re-emit.
final budgetsProvider = StreamProvider<List<BudgetModel>>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return const Stream.empty();

  final hive = ref.read(hiveServiceProvider);
  final firebase = ref.read(firebaseServiceProvider);

  // Background: Firestore → Hive diff sync
  final sub = firebase.watchBudgets(uid).listen((incoming) async {
    final existing = await hive.getAllBudgets();
    final existingIds = {for (final b in existing) b.budgetId};
    final incomingIds = {for (final b in incoming) b.budgetId};

    for (final budget in incoming) {
      await hive.saveBudget(budget);
    }

    // Skip deleting budgets that are pending a Firestore write
    final pendingOps = await hive.getPendingOps();
    final pendingSaveIds = pendingOps.values
        .where((op) => op['type'] == 'saveBudget')
        .map((op) =>
            Map<String, dynamic>.from(op['data'] as Map)['budgetId'] as String)
        .toSet();

    for (final id in existingIds.difference(incomingIds)) {
      if (!pendingSaveIds.contains(id)) {
        await hive.deleteBudget(id);
      }
    }
  });
  ref.onDispose(sub.cancel);

  return hive.watchBudgets();
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
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return;
    }
    await ref.read(hiveServiceProvider).saveBudget(budget);
    state = const AsyncData(null);
    try {
      await ref.read(firebaseServiceProvider).saveBudget(uid, budget);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'saveBudget',
        'data': budget.toMap(),
      });
    }
    FirebaseAnalytics.instance.logEvent(
      name: 'budget_created',
      parameters: {
        'has_category': (budget.categoryId != null).toString(),
        'alert_at': (budget.alertAt * 100).toInt().toString(),
      },
    );
  }

  Future<void> updateBudget(BudgetModel budget) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return;
    }
    await ref.read(hiveServiceProvider).saveBudget(budget);
    state = const AsyncData(null);
    try {
      await ref.read(firebaseServiceProvider).saveBudget(uid, budget);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'saveBudget',
        'data': budget.toMap(),
      });
    }
  }

  Future<void> deleteBudget(String budgetId) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) {
      state = AsyncError('Not authenticated', StackTrace.current);
      return;
    }
    await ref.read(hiveServiceProvider).deleteBudget(budgetId);
    state = const AsyncData(null);
    try {
      await ref.read(firebaseServiceProvider).deleteBudget(uid, budgetId);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'deleteBudget',
        'id': budgetId,
      });
    }
  }
}

final budgetNotifierProvider =
    AsyncNotifierProvider<BudgetNotifier, void>(BudgetNotifier.new);

/// Budgets that have reached or exceeded their alertAt threshold.
/// Each record is (budget, current utilisation fraction).
final budgetAlertsProvider = Provider<List<(BudgetModel, double)>>((ref) {
  final budgets = ref.watch(budgetsProvider).asData?.value ?? [];
  final util = ref.watch(budgetUtilisationProvider);
  final result = <(BudgetModel, double)>[];
  for (final b in budgets) {
    if (b.limitAmount <= 0) continue;
    final pct = util[b.categoryId ?? 'overall'] ?? 0.0;
    if (pct >= b.alertAt) result.add((b, pct));
  }
  return result;
});
