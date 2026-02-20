abstract class SyncService {
  Future<void> syncPendingTransactions(String uid);

  Future<void> enqueuePendingOperation(Map<String, dynamic> operation);

  Stream<SyncStatus> watchSyncStatus();
}

enum SyncStatus {
  idle,
  syncing,
  error,
}
