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

  // ── Transactions ────────────────────────────────────────────────────────

  Future<List<TransactionModel>> getAllTransactions() async {
    final box = _require(_txnBox);
    return _txnsFromBox(box);
  }

  Future<void> saveTransaction(TransactionModel txn) async {
    await _require(_txnBox).put(txn.txnId, txn.toMap());
  }

  Future<void> deleteTransaction(String txnId) async {
    await _require(_txnBox).delete(txnId);
  }

  Future<void> clearTransactions() async {
    await _require(_txnBox).clear();
  }

  /// Emits the current list immediately, then re-emits on every change.
  Stream<List<TransactionModel>> watchTransactions() async* {
    final box = _require(_txnBox);
    yield _txnsFromBox(box);
    await for (final _ in box.watch()) {
      yield _txnsFromBox(box);
    }
  }

  List<TransactionModel> _txnsFromBox(Box<Map> box) {
    return box.values
        .map((e) => TransactionModel.fromMap(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  // ── Budgets ──────────────────────────────────────────────────────────────

  Future<List<BudgetModel>> getAllBudgets() async {
    return _budgetsFromBox(_require(_budgetBox));
  }

  Future<void> saveBudget(BudgetModel budget) async {
    await _require(_budgetBox).put(budget.budgetId, budget.toMap());
  }

  Future<void> deleteBudget(String budgetId) async {
    await _require(_budgetBox).delete(budgetId);
  }

  Future<void> clearBudgets() async {
    await _require(_budgetBox).clear();
  }

  /// Emits the current list immediately, then re-emits on every change.
  Stream<List<BudgetModel>> watchBudgets() async* {
    final box = _require(_budgetBox);
    yield _budgetsFromBox(box);
    await for (final _ in box.watch()) {
      yield _budgetsFromBox(box);
    }
  }

  List<BudgetModel> _budgetsFromBox(Box<Map> box) {
    return box.values
        .map((e) => BudgetModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  // ── Housekeeping ─────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _txnBox?.clear();
    await _budgetBox?.clear();
  }

  Box<Map> _require(Box<Map>? box) {
    if (box == null) {
      throw StateError('HiveService not initialised. Call init() first.');
    }
    return box;
  }
}
