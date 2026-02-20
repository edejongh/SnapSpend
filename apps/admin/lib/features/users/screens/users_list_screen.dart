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
                          hintText: 'Search by email...',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
                Expanded(
                  child: usersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (users) {
                      final filtered = _searchQuery.isEmpty
                          ? users
                          : users
                              .where(
                                (u) => u.email.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ),
                              )
                              .toList();

                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Card(
                          child: DataTable2(
                            columnSpacing: 16,
                            columns: const [
                              DataColumn2(label: Text('Email'), size: ColumnSize.L),
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
                                  DataCell(Text(user.email)),
                                  DataCell(
                                    StatChip(
                                      label: user.plan.toUpperCase(),
                                      color: _planColor(user.plan),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormatter.formatShort(
                                          user.createdAt),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      DateFormatter.formatRelative(
                                          user.lastActiveAt),
                                    ),
                                  ),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.open_in_new,
                                          size: 18),
                                      onPressed: () =>
                                          context.go('/users/${user.uid}'),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
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
    switch (plan) {
      case 'pro':
        return Colors.blue;
      case 'business':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
