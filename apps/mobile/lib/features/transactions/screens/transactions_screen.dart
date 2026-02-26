import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state_widget.dart';

// Search, filter and sort state — scoped to this screen via autoDispose
final _txnSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final _txnCategoryFilterProvider =
    StateProvider.autoDispose<String?>((ref) => null);

enum _TxnSort { newest, oldest, amountDesc, amountAsc, vendor }

extension _TxnSortLabel on _TxnSort {
  String get label => switch (this) {
        _TxnSort.newest => 'Newest first',
        _TxnSort.oldest => 'Oldest first',
        _TxnSort.amountDesc => 'Highest amount',
        _TxnSort.amountAsc => 'Lowest amount',
        _TxnSort.vendor => 'Vendor A–Z',
      };
}

final _txnSortProvider =
    StateProvider.autoDispose<_TxnSort>((ref) => _TxnSort.newest);

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final query = ref.watch(_txnSearchProvider).toLowerCase();
    final categoryFilter = ref.watch(_txnCategoryFilterProvider);
    final categories = ref.watch(categoriesProvider);
    final sort = ref.watch(_txnSortProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          PopupMenuButton<_TxnSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: (s) =>
                ref.read(_txnSortProvider.notifier).state = s,
            itemBuilder: (_) => _TxnSort.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          if (s == sort)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
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
          // Category filter chips
          if (categories.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: categoryFilter == null,
                      onSelected: (_) => ref
                          .read(_txnCategoryFilterProvider.notifier)
                          .state = null,
                    ),
                  ),
                  ...categories.map((cat) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilterChip(
                          avatar: Text(cat.icon,
                              style: const TextStyle(fontSize: 14)),
                          label: Text(cat.name),
                          selected: categoryFilter == cat.categoryId,
                          onSelected: (_) => ref
                              .read(_txnCategoryFilterProvider.notifier)
                              .state = categoryFilter == cat.categoryId
                                  ? null
                                  : cat.categoryId,
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: txnsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allTxns) {
                var txns = categoryFilter == null
                    ? allTxns
                    : allTxns
                        .where((t) => t.category == categoryFilter)
                        .toList();
                if (query.isNotEmpty) {
                  txns = txns.where((t) {
                    return t.vendor.toLowerCase().contains(query) ||
                        t.category.toLowerCase().contains(query) ||
                        (t.note?.toLowerCase().contains(query) ?? false);
                  }).toList();
                }

                // Apply sort
                txns = List.of(txns);
                switch (sort) {
                  case _TxnSort.newest:
                    txns.sort((a, b) => b.date.compareTo(a.date));
                  case _TxnSort.oldest:
                    txns.sort((a, b) => a.date.compareTo(b.date));
                  case _TxnSort.amountDesc:
                    txns.sort((a, b) => b.amountZAR.compareTo(a.amountZAR));
                  case _TxnSort.amountAsc:
                    txns.sort((a, b) => a.amountZAR.compareTo(b.amountZAR));
                  case _TxnSort.vendor:
                    txns.sort((a, b) =>
                        a.vendor.toLowerCase().compareTo(b.vendor.toLowerCase()));
                }

                if (txns.isEmpty) {
                  if (query.isNotEmpty || categoryFilter != null) {
                    return const Center(
                      child: Text(
                        'No matching transactions',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return const EmptyStateWidget(
                    icon: Icons.receipt_long_outlined,
                    title: 'No transactions yet',
                    subtitle:
                        'Tap the camera button to scan your first receipt',
                  );
                }

                // Summary bar when filtered or searching
                final filteredTotal = txns.fold(
                    0.0, (sum, t) => sum + t.amountZAR);
                final isFiltered =
                    query.isNotEmpty || categoryFilter != null;

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

                return Column(
                  children: [
                    if (isFiltered)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Text(
                          '${txns.length} result${txns.length == 1 ? '' : 's'} · '
                          '${CurrencyFormatter.format(filteredTotal, 'ZAR')} total',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    Expanded(
                      child: RefreshIndicator(
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
                              onDelete: () =>
                                  _confirmDelete(context, ref, txn),
                              onTap: () => _showDetail(context, ref, txn),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
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

  void _shareTransaction(TransactionModel t, String? categoryName) {
    final lines = [
      '${t.vendor} — ${CurrencyFormatter.format(t.amountZAR, 'ZAR')}',
      'Date: ${DateFormatter.formatDate(t.date)}',
      'Category: ${categoryName ?? t.category}',
      if (t.note != null && t.note!.isNotEmpty) 'Note: ${t.note}',
      if (t.isTaxDeductible) 'Tax deductible',
    ];
    Share.share(lines.join('\n'), subject: 'SnapSpend — ${t.vendor}');
  }

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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/edit-transaction', extra: t);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _shareTransaction(t, category?.name),
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
          if (t.receiptStoragePath != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) =>
                      _ReceiptViewer(url: t.receiptStoragePath!),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Hero(
                  tag: 'receipt_${t.txnId}',
                  child: Image.network(
                    t.receiptStoragePath!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tap to zoom',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
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

// ── Full-screen receipt viewer ────────────────────────────────────────────────

class _ReceiptViewer extends StatelessWidget {
  final String url;
  const _ReceiptViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Receipt'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Hero(
            tag: url,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const CircularProgressIndicator(color: Colors.white);
              },
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
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
