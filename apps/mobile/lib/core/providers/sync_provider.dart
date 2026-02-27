import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'hive_provider.dart';
import '../services/sync_service_impl.dart';

/// True when the device has at least one active network connection.
final isOnlineProvider = StreamProvider<bool>((ref) {
  return Connectivity()
      .onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));
});

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
