import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapspend_core/snapspend_core.dart';

class FirebaseServiceImpl implements FirebaseService {
  final FirebaseFirestore _firestore;

  FirebaseServiceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromMap(doc.data()!);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<TransactionModel>> getTransactions(
    String uid, {
    DateTime? from,
    DateTime? to,
  }) async {
    Query query = _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true);

    if (from != null) {
      query = query.where('date', isGreaterThanOrEqualTo: from.toIso8601String());
    }
    if (to != null) {
      query = query.where('date', isLessThanOrEqualTo: to.toIso8601String());
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveTransaction(String uid, TransactionModel txn) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(txn.txnId)
        .set(txn.toMap());
  }

  @override
  Future<void> deleteTransaction(String uid, String txnId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(txnId)
        .delete();
  }

  @override
  Future<List<BudgetModel>> getBudgets(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .get();
    return snapshot.docs
        .map((doc) => BudgetModel.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> saveBudget(String uid, BudgetModel budget) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(budget.budgetId)
        .set(budget.toMap());
  }

  @override
  Stream<List<TransactionModel>> watchTransactions(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => TransactionModel.fromMap(
                  doc.data(),
                ),
              )
              .toList(),
        );
  }
}
