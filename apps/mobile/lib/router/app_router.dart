import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../features/snap/screens/snap_screen.dart';
import '../features/transactions/screens/transactions_screen.dart';
import '../features/snap/screens/receipt_review_screen.dart';
import '../features/reports/screens/reports_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/profile_screen.dart';
import '../features/settings/screens/budget_setup_screen.dart';
import '../features/settings/screens/categories_screen.dart';
import '../features/settings/screens/notifications_screen.dart';
import 'package:snapspend_core/snapspend_core.dart';

/// Notifies GoRouter whenever auth state or Firestore user data changes,
/// so redirect logic re-evaluates (e.g. after onboardingComplete flips).
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(currentUserProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = FirebaseAuth.instance.currentUser;
      final isAuthenticated = user != null;

      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/register';
      final isOnboardingRoute = loc == '/onboarding';

      // Not logged in → login
      if (!isAuthenticated) {
        if (!isAuthRoute) return '/login';
        return null;
      }

      // Logged in — check onboarding status
      final userAsync = ref.read(currentUserProvider);

      // Still fetching user doc — don't redirect yet
      if (userAsync.isLoading) return null;

      final onboardingComplete =
          userAsync.asData?.value?.onboardingComplete ?? false;

      if (!onboardingComplete) {
        if (!isOnboardingRoute) return '/onboarding';
        return null;
      }

      // Onboarding done — bounce away from auth/onboarding routes
      if (isAuthRoute || isOnboardingRoute) return '/home';
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
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
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
        path: '/transactions',
        builder: (context, state) => TransactionsScreen(
          initialCategory: state.extra as String?,
          initialSearch: state.uri.queryParameters['search'],
          initialFlagged: state.uri.queryParameters.containsKey('flagged'),
          initialDateRange: state.uri.queryParameters['range'],
          autoFocusSearch: state.uri.queryParameters.containsKey('focus'),
        ),
      ),
      GoRoute(
        path: '/edit-transaction',
        builder: (context, state) {
          final txn = state.extra as TransactionModel;
          return ReceiptReviewScreen(existingTransaction: txn);
        },
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
          GoRoute(
            path: 'categories',
            builder: (context, state) => const CategoriesScreen(),
          ),
          GoRoute(
            path: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
