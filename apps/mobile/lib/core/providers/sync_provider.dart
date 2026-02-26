import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'hive_provider.dart';
import '../services/sync_service_impl.dart';

final syncServiceProvider = Provider<SyncServiceImpl>((ref) {
  return SyncServiceImpl(
    firebaseService: ref.read(firebaseServiceProvider),
    hiveService: ref.read(hiveServiceProvider),
  );
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return const Stream.empty();

  final sync = ref.read(syncServiceProvider);
  // Replay any ops that failed while offline at startup
  sync.syncPendingTransactions(uid);
  return sync.watchSyncStatus(uid);
});
