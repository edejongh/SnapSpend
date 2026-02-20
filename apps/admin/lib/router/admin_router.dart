import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/providers/admin_auth_provider.dart';
import '../features/auth/screens/admin_login_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/users/screens/users_list_screen.dart';
import '../features/users/screens/user_detail_screen.dart';
import '../features/ocr_review/screens/ocr_review_screen.dart';
import '../features/billing/screens/billing_screen.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(adminAuthStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final isAuthenticated = authState.asData?.value != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) return '/login';
      if (isAuthenticated && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const AdminLoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UsersListScreen(),
        routes: [
          GoRoute(
            path: ':uid',
            builder: (context, state) {
              final uid = state.pathParameters['uid']!;
              return UserDetailScreen(uid: uid);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/ocr-review',
        builder: (context, state) => const OcrReviewScreen(),
      ),
      GoRoute(
        path: '/billing',
        builder: (context, state) => const BillingScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
