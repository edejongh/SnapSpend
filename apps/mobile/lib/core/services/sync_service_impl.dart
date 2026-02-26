import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'hive_service.dart';

class SyncServiceImpl implements SyncService {
  final FirebaseService _firebaseService;
  final HiveService _hiveService;
  final Connectivity _connectivity;

  SyncServiceImpl({
    required FirebaseService firebaseService,
    required HiveService hiveService,
    Connectivity? connectivity,
  })  : _firebaseService = firebaseService,
        _hiveService = hiveService,
        _connectivity = connectivity ?? Connectivity();

  /// Replays all queued write operations against Firestore.
  /// Safe to call when offline — exits early if no connection.
  @override
  Future<void> syncPendingTransactions(String uid) async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return;

    final ops = await _hiveService.getPendingOps();
    if (ops.isEmpty) return;

    for (final entry in ops.entries) {
      final op = entry.value;
      final type = op['type'] as String?;
      try {
        switch (type) {
          case 'saveTransaction':
            final txn = TransactionModel.fromMap(
                Map<String, dynamic>.from(op['data'] as Map));
            await _firebaseService.saveTransaction(uid, txn);
          case 'deleteTransaction':
            await _firebaseService.deleteTransaction(
                uid, op['id'] as String);
          case 'saveBudget':
            final budget = BudgetModel.fromMap(
                Map<String, dynamic>.from(op['data'] as Map));
            await _firebaseService.saveBudget(uid, budget);
          case 'deleteBudget':
            await _firebaseService.deleteBudget(uid, op['id'] as String);
          default:
            break; // Unknown op type — remove it
        }
        await _hiveService.dequeuePendingOp(entry.key);
      } catch (_) {
        // Leave in queue — will retry next time connectivity returns
      }
    }
  }

  @override
  Future<void> enqueuePendingOperation(Map<String, dynamic> operation) async {
    await _hiveService.enqueuePendingOp(operation);
  }

  /// Emits [SyncStatus.idle] initially, then [SyncStatus.syncing] each time
  /// connectivity is regained, triggering a pending-ops replay.
  @override
  Stream<SyncStatus> watchSyncStatus(String uid) async* {
    yield SyncStatus.idle;
    await for (final result in _connectivity.onConnectivityChanged) {
      if (!result.contains(ConnectivityResult.none)) {
        yield SyncStatus.syncing;
        try {
          await syncPendingTransactions(uid);
          yield SyncStatus.idle;
        } catch (_) {
          yield SyncStatus.error;
        }
      }
    }
  }
}
