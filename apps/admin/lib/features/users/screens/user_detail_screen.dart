import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/users_provider.dart';
import '../../../shared/widgets/admin_sidebar.dart';

class UserDetailScreen extends ConsumerWidget {
  final String uid;

  const UserDetailScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailProvider(uid));

    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('User Detail'),
                ),
                Expanded(
                  child: userAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (user) => user == null
                        ? const Center(child: Text('User not found'))
                        : Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('User: ${user.email} — coming soon'),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
