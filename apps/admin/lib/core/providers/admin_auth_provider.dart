import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Watches FirebaseAuth state changes
final adminAuthStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Checks if the current user has admin custom claim
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(adminAuthStateProvider).asData?.value;
  if (user == null) return false;
  final idTokenResult = await user.getIdTokenResult(true);
  return idTokenResult.claims?['admin'] == true;
});

class AdminAuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Verify admin claim
      final idTokenResult =
          await credential.user?.getIdTokenResult(true);
      if (idTokenResult?.claims?['admin'] != true) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Access denied: admin privileges required');
      }
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(FirebaseAuth.instance.signOut);
  }
}

final adminAuthNotifierProvider =
    AsyncNotifierProvider<AdminAuthNotifier, void>(AdminAuthNotifier.new);
