import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'users_provider.dart';

final openFlagsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final service = ref.watch(adminFirebaseServiceProvider);
  // Sort by confidence ascending so the most uncertain flags appear first.
  return service.streamOpenFlags().map(
    (flags) => flags..sort((a, b) =>
        (a.ocrConfidence ?? 0).compareTo(b.ocrConfidence ?? 0)),
  );
});

final receiptDownloadUrlProvider =
    FutureProvider.family<String?, String>((ref, storagePath) async {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.getReceiptDownloadUrl(storagePath);
});
