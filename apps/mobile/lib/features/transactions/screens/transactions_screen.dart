import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';

// Search query state — scoped to this screen via autoDispose
final _txnSearchProvider = StateProvider.autoDispose<String>((ref) => '');

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final query = ref.watch(_txnSearchProvider).toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('All Transactions')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/snap/review'),
        tooltip: 'Add transaction',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search transactions…',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () =>
                            ref.read(_txnSearchProvider.notifier).state = '',
                      )
                    : null,
              ),
              onChanged: (v) =>
                  ref.read(_txnSearchProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allTxns) {
                final txns = query.isEmpty
                    ? allTxns
                    : allTxns.where((t) {
                        return t.vendor.toLowerCase().contains(query) ||
                            t.category.toLowerCase().contains(query) ||
                            (t.note?.toLowerCase().contains(query) ?? false);
                      }).toList();

                if (txns.isEmpty) {
                  return query.isNotEmpty
                      ? Center(
                          child: Text(
                            'No results for "$query"',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : const EmptyStateWidget(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions yet',
                          subtitle:
                              'Tap the camera button to scan your first receipt',
                        );
                }

                // Group by date
                final groups = <String, List<TransactionModel>>{};
                for (final txn in txns) {
                  groups.putIfAbsent(_dateKey(txn.date), () => []).add(txn);
                }

                final items = <_ListItem>[];
                for (final entry in groups.entries) {
                  items.add(_HeaderItem(entry.key));
                  for (final txn in entry.value) {
                    items.add(_TxnItem(txn));
                  }
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(transactionsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final item = items[i];
                      if (item is _HeaderItem) {
                        return _DateHeader(label: item.label);
                      }
                      final txn = (item as _TxnItem).transaction;
                      return _DismissibleTile(
                        transaction: txn,
                        onDelete: () => _confirmDelete(context, ref, txn),
                        onTap: () => _showDetail(context, ref, txn),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _dateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormatter.formatDate(date);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel txn) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
            'Remove "${txn.vendor}" — ${CurrencyFormatter.format(txn.amountZAR, 'ZAR')}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(transactionNotifierProvider.notifier)
          .deleteTransaction(txn.txnId);
    }
  }

  void _showDetail(
      BuildContext context, WidgetRef ref, TransactionModel txn) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _TransactionDetailSheet(transaction: txn),
    );
  }
}

// ── List item types ─────────────────────────────────────────────────────────

sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  final String label;
  _HeaderItem(this.label);
}

class _TxnItem extends _ListItem {
  final TransactionModel transaction;
  _TxnItem(this.transaction);
}

// ── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

// ── Dismissible tile ─────────────────────────────────────────────────────────

class _DismissibleTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _DismissibleTile({
    required this.transaction,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(transaction.txnId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the Firestore stream remove it reactively
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: _TransactionTile(transaction: transaction, onTap: onTap),
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _TransactionTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(transaction.category));

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          category?.icon ?? '📋',
          style: const TextStyle(fontSize: 18),
        ),
      ),
      title: Text(
        transaction.vendor,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(category?.name ?? transaction.category),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            CurrencyFormatter.format(transaction.amountZAR, 'ZAR'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (transaction.isTaxDeductible)
            const Text(
              'Tax deductible',
              style: TextStyle(fontSize: 10, color: Colors.green),
            ),
        ],
      ),
    );
  }
}

// ── Detail bottom sheet ──────────────────────────────────────────────────────

class _TransactionDetailSheet extends ConsumerWidget {
  final TransactionModel transaction;
  const _TransactionDetailSheet({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(transaction.category));
    final t = transaction;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(category?.icon ?? '📋',
                    style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.vendor,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(category?.name ?? t.category,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.format(t.amountZAR, 'ZAR'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.push('/edit-transaction', extra: t);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
          ),
          const Divider(height: 32),
          _DetailRow(label: 'Date', value: DateFormatter.formatDate(t.date)),
          if (t.currency != 'ZAR')
            _DetailRow(
                label: 'Original amount',
                value:
                    '${CurrencyFormatter.format(t.amount, t.currency)} ${t.currency}'),
          _DetailRow(
              label: 'Source',
              value: t.source == 'ocr' ? 'Scanned receipt' : 'Manual entry'),
          if (t.ocrConfidence != null)
            _DetailRow(
                label: 'OCR confidence',
                value: '${(t.ocrConfidence! * 100).toStringAsFixed(0)}%'),
          _DetailRow(
              label: 'Tax deductible', value: t.isTaxDeductible ? 'Yes' : 'No'),
          if (t.note != null && t.note!.isNotEmpty)
            _DetailRow(label: 'Note', value: t.note!),
          if (t.flaggedForReview)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Flagged for review — low OCR confidence'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
