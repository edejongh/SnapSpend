import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/users_provider.dart';
import '../../../shared/widgets/admin_sidebar.dart';
import '../../../shared/widgets/stat_chip.dart';

class UsersListScreen extends ConsumerStatefulWidget {
  const UsersListScreen({super.key});

  @override
  ConsumerState<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends ConsumerState<UsersListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Users'),
                  actions: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search by name or email...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(usersProvider),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                Expanded(
                  child: usersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error: $e'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => ref.invalidate(usersProvider),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                    data: (users) {
                      final q = _searchQuery.toLowerCase();
                      final filtered = _searchQuery.isEmpty
                          ? users
                          : users
                              .where(
                                (u) =>
                                    u.email.toLowerCase().contains(q) ||
                                    (u.displayName
                                            ?.toLowerCase()
                                            .contains(q) ??
                                        false),
                              )
                              .toList();

                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Text(
                                    _searchQuery.isEmpty
                                        ? '${users.length} users total'
                                        : '${filtered.length} of ${users.length} users',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                  if (users.length >= 100) ...[
                                    const SizedBox(width: 6),
                                    Tooltip(
                                      message: 'Showing first 100 users only',
                                      child: Icon(Icons.info_outline,
                                          size: 14,
                                          color: Colors.amber.shade700),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: Card(
                                child: DataTable2(
                                  columnSpacing: 16,
                                  columns: const [
                                    DataColumn2(
                                        label: Text('User'),
                                        size: ColumnSize.L),
                                    DataColumn(label: Text('Plan')),
                                    DataColumn(label: Text('Joined')),
                                    DataColumn(label: Text('Last Active')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filtered.map((user) {
                                    return DataRow2(
                                      onTap: () =>
                                          context.go('/users/${user.uid}'),
                                      cells: [
                                        DataCell(
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (user.displayName != null)
                                                Text(
                                                  user.displayName!,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              Text(
                                                user.email,
                                                style: TextStyle(
                                                  fontSize: user.displayName !=
                                                          null
                                                      ? 12
                                                      : 14,
                                                  color: user.displayName !=
                                                          null
                                                      ? Colors.grey.shade600
                                                      : null,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          StatChip(
                                            label: user.plan.toUpperCase(),
                                            color: _planColor(user.plan),
                                          ),
                                        ),
                                        DataCell(
                                          Text(DateFormatter.formatShort(
                                              user.createdAt)),
                                        ),
                                        DataCell(
                                          Text(DateFormatter.formatRelative(
                                              user.lastActiveAt)),
                                        ),
                                        DataCell(
                                          IconButton(
                                            icon: const Icon(Icons.open_in_new,
                                                size: 18),
                                            onPressed: () => context
                                                .go('/users/${user.uid}'),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _planColor(String plan) {
    return switch (plan) {
      'pro' => Colors.blue,
      'business' => Colors.purple,
      _ => Colors.grey,
    };
  }
}
