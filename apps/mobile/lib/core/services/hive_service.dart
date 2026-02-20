import 'package:hive_flutter/hive_flutter.dart';
import 'package:snapspend_core/snapspend_core.dart';

class HiveService {
  static const _txnBoxName = 'transactions';
  static const _budgetBoxName = 'budgets';

  Box<Map>? _txnBox;
  Box<Map>? _budgetBox;

  Future<void> init() async {
    _txnBox = await Hive.openBox<Map>(_txnBoxName);
    _budgetBox = await Hive.openBox<Map>(_budgetBoxName);
  }

  // Transactions
  Future<List<TransactionModel>> getAllTransactions() async {
    final box = _requireBox(_txnBox);
    return box.values
        .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> saveTransaction(TransactionModel txn) async {
    final box = _requireBox(_txnBox);
    await box.put(txn.txnId, txn.toMap());
  }

  Future<void> deleteTransaction(String txnId) async {
    final box = _requireBox(_txnBox);
    await box.delete(txnId);
  }

  Stream<List<TransactionModel>> watchTransactions() {
    final box = _requireBox(_txnBox);
    return box.watch().map(
          (_) => box.values
              .map(
                (e) => TransactionModel.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date)),
        );
  }

  // Budgets
  Future<List<BudgetModel>> getAllBudgets() async {
    final box = _requireBox(_budgetBox);
    return box.values
        .map((e) => BudgetModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveBudget(BudgetModel budget) async {
    final box = _requireBox(_budgetBox);
    await box.put(budget.budgetId, budget.toMap());
  }

  Future<void> deleteBudget(String budgetId) async {
    final box = _requireBox(_budgetBox);
    await box.delete(budgetId);
  }

  Box<Map> _requireBox(Box<Map>? box) {
    if (box == null) {
      throw StateError('HiveService not initialised. Call init() first.');
    }
    return box;
  }

  Future<void> clearAll() async {
    await _txnBox?.clear();
    await _budgetBox?.clear();
  }
}
