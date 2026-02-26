import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'hive_provider.dart';

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
        await _registerFcmToken();
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
        await _registerFcmToken();
      } on FirebaseAuthException catch (e) {
        throw _friendlyAuthError(e);
      }
    });
  }

  /// Saves the current FCM token to Firestore so the server can send push
  /// notifications to this device. Non-fatal — never blocks auth flow.
  Future<void> _registerFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ref.read(firebaseServiceProvider).saveFcmToken(uid, token);
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(hiveServiceProvider).clearAll();
      await FirebaseAuth.instance.signOut();
    });
  }

  Future<void> googleSignIn() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the sign-in flow
        state = const AsyncData(null);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // Create Firestore user doc for first-time Google sign-ins
      if (result.additionalUserInfo?.isNewUser == true) {
        final user = result.user!;
        final now = DateTime.now();
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoURL: user.photoURL,
          plan: 'free',
          defaultCurrency: AppConstants.defaultCurrency,
          createdAt: now,
          lastActiveAt: now,
          onboardingComplete: false,
        );
        await ref.read(firebaseServiceProvider).saveUser(userModel);
      }
      await _registerFcmToken();
    });
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
