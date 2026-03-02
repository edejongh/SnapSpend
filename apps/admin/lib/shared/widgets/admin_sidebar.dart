import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/admin_auth_provider.dart';
import '../../core/providers/flags_provider.dart';
import '../theme/admin_theme.dart';

class AdminSidebar extends ConsumerWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isNarrow = MediaQuery.of(context).size.width < 900;
    final email =
        ref.watch(adminAuthStateProvider).asData?.value?.email ?? '';
    final onLogout =
        () => ref.read(adminAuthNotifierProvider.notifier).logout();
    final openFlagCount =
        ref.watch(openFlagsProvider).asData?.value?.length ?? 0;

    final content = _SidebarContent(
      currentRoute: currentRoute,
      email: email,
      onLogout: onLogout,
      openFlagCount: openFlagCount,
    );

    if (isNarrow) {
      return Drawer(child: content);
    }

    return SizedBox(width: 240, child: content);
  }
}

class _SidebarContent extends StatelessWidget {
  final String currentRoute;
  final String email;
  final VoidCallback onLogout;
  final int openFlagCount;

  const _SidebarContent({
    required this.currentRoute,
    required this.email,
    required this.onLogout,
    required this.openFlagCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AdminTheme.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SnapSpend',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _SidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/dashboard',
            isActive: currentRoute.startsWith('/dashboard'),
          ),
          _SidebarItem(
            icon: Icons.people_outline,
            label: 'Users',
            route: '/users',
            isActive: currentRoute.startsWith('/users'),
          ),
          _SidebarItem(
            icon: Icons.rate_review_outlined,
            label: 'OCR Review',
            route: '/ocr-review',
            isActive: currentRoute.startsWith('/ocr-review'),
            badge: openFlagCount > 0 ? openFlagCount : null,
          ),
          _SidebarItem(
            icon: Icons.credit_card_outlined,
            label: 'Billing',
            route: '/billing',
            isActive: currentRoute.startsWith('/billing'),
          ),
          const Spacer(),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                email,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onLogout,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Icon(Icons.logout,
                          color: Colors.white.withValues(alpha: 0.55),
                          size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'Log out',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;
  final int? badge;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final itemColor =
        isActive ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(route),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: itemColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: itemColor,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge! > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
