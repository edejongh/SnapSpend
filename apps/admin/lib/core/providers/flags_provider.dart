import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../services/admin_firebase_service.dart';
import 'users_provider.dart';

final openFlagsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.getOpenFlags();
});
