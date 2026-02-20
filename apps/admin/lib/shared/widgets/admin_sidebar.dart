import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/admin_theme.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final isNarrow = MediaQuery.of(context).size.width < 900;

    if (isNarrow) {
      return Drawer(
        child: _SidebarContent(currentRoute: currentRoute),
      );
    }

    return SizedBox(
      width: 240,
      child: _SidebarContent(currentRoute: currentRoute),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  final String currentRoute;

  const _SidebarContent({required this.currentRoute});

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
                    color: Colors.white.withOpacity(0.5),
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
          ),
          _SidebarItem(
            icon: Icons.credit_card_outlined,
            label: 'Billing',
            route: '/billing',
            isActive: currentRoute.startsWith('/billing'),
          ),
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

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive
            ? Colors.white.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.6),
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
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
