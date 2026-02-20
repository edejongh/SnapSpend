import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/transaction_list_tile.dart';
import '../../../shared/widgets/empty_state_widget.dart';

class RecentTransactionsList extends ConsumerWidget {
  const RecentTransactionsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        txnsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error loading transactions: $e'),
          data: (txns) {
            if (txns.isEmpty) {
              return const EmptyStateWidget(
                icon: Icons.receipt_long_outlined,
                title: 'No transactions yet',
                subtitle: 'Tap the camera button to scan your first receipt',
              );
            }
            final recent = txns.take(10).toList();
            return Column(
              children: recent
                  .map((txn) => TransactionListTile(transaction: txn))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
