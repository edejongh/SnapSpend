import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';

// Watches FirebaseAuth state changes, including profile updates (displayName etc)
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

// Fetches the current UserModel from Firestore
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;
  if (user == null) return null;
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getUser(user.uid);
});

// Provider for the concrete FirebaseService implementation
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  throw UnimplementedError(
    'firebaseServiceProvider must be overridden with a concrete implementation',
  );
});

String _friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Invalid email or password.';
    case 'email-already-in-use':
      return 'An account with this email already exists.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

// Auth actions notifier
class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        throw _friendlyAuthError(e);
      }
    });
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      try {
        final credential =
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final user = credential.user!;
        final now = DateTime.now();
        final userModel = UserModel(
          uid: user.uid,
          email: email,
          plan: 'free',
          defaultCurrency: 'ZAR',
          createdAt: now,
          lastActiveAt: now,
          onboardingComplete: false,
        );
        final firebaseService = ref.read(firebaseServiceProvider);
        await firebaseService.saveUser(userModel);
      } on FirebaseAuthException catch (e) {
        throw _friendlyAuthError(e);
      }
    });
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await FirebaseAuth.instance.signOut();
    });
  }

  Future<void> googleSignIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // TODO: Implement Google Sign-In with google_sign_in package
      throw UnimplementedError('Google Sign-In not yet implemented');
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
