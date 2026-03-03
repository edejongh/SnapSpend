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
  Future<void> deleteBudget(String uid, String budgetId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(budgetId)
        .delete();
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
              .map((doc) => TransactionModel.fromMap(doc.data()))
              .toList(),
        );
  }

  @override
  Stream<List<BudgetModel>> watchBudgets(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BudgetModel.fromMap(doc.data()))
              .toList(),
        );
  }

  @override
  Future<void> saveFcmToken(String uid, String token) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  @override
  Future<List<CategoryModel>> getUserCategories(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .get();
    return snapshot.docs
        .map((doc) => CategoryModel.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<void> saveUserCategory(String uid, CategoryModel category) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(category.categoryId)
        .set(category.toMap());
  }

  @override
  Future<void> deleteUserCategory(String uid, String categoryId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('categories')
        .doc(categoryId)
        .delete();
  }

  @override
  Future<void> touchLastActive(String uid) async {
    await _firestore.collection('users').doc(uid).set(
      {'lastActiveAt': DateTime.now().toIso8601String()},
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> createAdminFlag(String uid, TransactionModel txn) async {
    await _firestore.collection('admin_flags').doc(txn.txnId).set({
      ...txn.toMap(),
      'uid': uid,
      'status': 'open',
    });
  }

  @override
  Future<void> deleteUserData(String uid) async {
    final userRef = _firestore.collection('users').doc(uid);

    // Fetch all subcollections + admin flags in parallel then delete concurrently.
    final results = await Future.wait([
      userRef.collection('transactions').get(),
      userRef.collection('budgets').get(),
      userRef.collection('categories').get(),
      _firestore.collection('admin_flags').where('uid', isEqualTo: uid).get(),
    ]);

    final deletes = results.expand((snap) => snap.docs).map((doc) => doc.reference.delete());
    await Future.wait(deletes);

    await userRef.delete();
  }
}
