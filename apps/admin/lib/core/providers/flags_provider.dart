import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../services/admin_firebase_service.dart';
import 'users_provider.dart';

final openFlagsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.streamOpenFlags();
});

final receiptDownloadUrlProvider =
    FutureProvider.family<String?, String>((ref, storagePath) async {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.getReceiptDownloadUrl(storagePath);
});
