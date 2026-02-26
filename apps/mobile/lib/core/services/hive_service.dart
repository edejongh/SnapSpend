import 'package:hive_flutter/hive_flutter.dart';
import 'package:snapspend_core/snapspend_core.dart';

class HiveService {
  static const _txnBoxName = 'transactions';
  static const _budgetBoxName = 'budgets';
  static const _pendingBoxName = 'pending_ops';
  static const _userCategoryBoxName = 'user_categories';

  Box<Map>? _txnBox;
  Box<Map>? _budgetBox;
  Box<Map>? _pendingBox;
  Box<Map>? _userCategoryBox;

  Future<void> init() async {
    _txnBox = await Hive.openBox<Map>(_txnBoxName);
    _budgetBox = await Hive.openBox<Map>(_budgetBoxName);
    _pendingBox = await Hive.openBox<Map>(_pendingBoxName);
    _userCategoryBox = await Hive.openBox<Map>(_userCategoryBoxName);
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

  // ── User categories ───────────────────────────────────────────────────────

  Future<List<CategoryModel>> getUserCategories() async {
    return _require(_userCategoryBox)
        .values
        .map((e) => CategoryModel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> saveUserCategory(CategoryModel category) async {
    await _require(_userCategoryBox).put(category.categoryId, category.toMap());
  }

  Future<void> deleteUserCategory(String categoryId) async {
    await _require(_userCategoryBox).delete(categoryId);
  }

  // ── Pending ops queue ─────────────────────────────────────────────────────

  /// Appends an operation to the pending-ops queue.
  /// Returns the auto-assigned Hive key (used to dequeue after replay).
  Future<void> enqueuePendingOp(Map<String, dynamic> op) async {
    await _require(_pendingBox).add(Map.from(op));
  }

  /// Returns all pending ops as {key → op} — key needed for [dequeuePendingOp].
  Future<Map<dynamic, Map<String, dynamic>>> getPendingOps() async {
    final box = _require(_pendingBox);
    return {
      for (final key in box.keys)
        key: Map<String, dynamic>.from(box.get(key)!),
    };
  }

  /// Removes a single pending op by its Hive key after successful replay.
  Future<void> dequeuePendingOp(dynamic key) async {
    await _require(_pendingBox).delete(key);
  }

  // ── Housekeeping ─────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _txnBox?.clear();
    await _budgetBox?.clear();
    await _userCategoryBox?.clear();
    await _pendingBox?.clear();
  }

  Box<Map> _require(Box<Map>? box) {
    if (box == null) {
      throw StateError('HiveService not initialised. Call init() first.');
    }
    return box;
  }
}
