import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:snapspend_core/snapspend_core.dart';

class SyncServiceImpl implements SyncService {
  final FirebaseService _firebaseService;
  final Connectivity _connectivity;

  SyncServiceImpl({
    required FirebaseService firebaseService,
    Connectivity? connectivity,
  })  : _firebaseService = firebaseService,
        _connectivity = connectivity ?? Connectivity();

  @override
  Future<void> syncPendingTransactions(String uid) async {
    final result = await _connectivity.checkConnectivity();
    if (result.contains(ConnectivityResult.none)) return;
    // TODO: Read pending queue from Hive and replay operations
  }

  @override
  Future<void> enqueuePendingOperation(Map<String, dynamic> operation) async {
    // TODO: Persist operation to a Hive pending-ops box
  }

  @override
  Stream<SyncStatus> watchSyncStatus() async* {
    yield SyncStatus.idle;
    await for (final result in _connectivity.onConnectivityChanged) {
      if (!result.contains(ConnectivityResult.none)) {
        yield SyncStatus.syncing;
        // TODO: Trigger sync and yield idle/error on completion
      }
    }
  }
}
