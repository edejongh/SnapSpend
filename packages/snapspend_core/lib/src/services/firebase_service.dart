import '../models/budget_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

abstract class FirebaseService {
  Future<UserModel?> getUser(String uid);

  Future<void> saveUser(UserModel user);

  Future<List<TransactionModel>> getTransactions(
    String uid, {
    DateTime? from,
    DateTime? to,
  });

  Future<void> saveTransaction(String uid, TransactionModel txn);

  Future<void> deleteTransaction(String uid, String txnId);

  Future<List<BudgetModel>> getBudgets(String uid);

  Future<void> saveBudget(String uid, BudgetModel budget);

  Stream<List<TransactionModel>> watchTransactions(String uid);
}
