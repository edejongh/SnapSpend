import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../services/admin_firebase_service.dart';

final adminFirebaseServiceProvider = Provider<AdminFirebaseService>((ref) {
  return AdminFirebaseService();
});

final usersProvider = FutureProvider<List<UserModel>>((ref) async {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.getAllUsers();
});

final userDetailProvider =
    FutureProvider.family<UserModel?, String>((ref, uid) async {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.getUser(uid);
});
