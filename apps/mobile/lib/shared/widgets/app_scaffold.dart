import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../core/providers/sync_provider.dart';

/// Shared scaffold used by all top-level tab screens.
/// Renders the NavigationBar with the correct selected index derived
/// from the current GoRouter location, and a sync status indicator.
class AppScaffold extends ConsumerWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus =
        ref.watch(syncStatusProvider).asData?.value ?? SyncStatus.idle;
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          if (syncStatus == SyncStatus.syncing)
            const LinearProgressIndicator(minHeight: 2),
          if (syncStatus == SyncStatus.error)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              child: Text(
                'Sync failed — changes will retry when back online',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexForLocation(location),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Snap',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.push('/snap');
            case 2:
              context.go('/reports');
            case 3:
              context.go('/settings');
          }
        },
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/snap')) return 1;
    if (location.startsWith('/reports')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }
}
