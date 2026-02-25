import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/snap/screens/snap_screen.dart';
import '../features/snap/screens/receipt_review_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/profile_screen.dart';
import '../features/settings/screens/budget_setup_screen.dart';
import 'package:snapspend_core/snapspend_core.dart';

/// A [ChangeNotifier] that listens to Firebase auth state changes so GoRouter
/// can refresh its redirect logic without creating a new router instance.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authListenable = _AuthListenable();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    refreshListenable: _authListenable,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isAuthenticated = user != null;

      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/snap',
        builder: (context, state) => const SnapScreen(),
        routes: [
          GoRoute(
            path: 'review',
            builder: (context, state) {
              final ocrResult = state.extra as OcrResult?;
              return ReceiptReviewScreen(ocrResult: ocrResult);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'budget',
            builder: (context, state) => const BudgetSetupScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
