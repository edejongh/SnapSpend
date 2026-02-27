import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
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

enum _TxnDateRange { all, thisMonth, lastMonth, last30Days, last7Days }

extension _TxnDateRangeLabel on _TxnDateRange {
  String get label => switch (this) {
        _TxnDateRange.all => 'All time',
        _TxnDateRange.thisMonth => 'This month',
        _TxnDateRange.lastMonth => 'Last month',
        _TxnDateRange.last30Days => 'Last 30 days',
        _TxnDateRange.last7Days => 'Last 7 days',
      };
}

final _txnDateRangeProvider =
    StateProvider.autoDispose<_TxnDateRange>((ref) => _TxnDateRange.all);

// (minZAR, maxZAR) — null means no bound
final _txnAmountRangeProvider =
    StateProvider.autoDispose<(double?, double?)>((ref) => (null, null));

// Show only tax-deductible transactions when true
final _txnTaxFilterProvider =
    StateProvider.autoDispose<bool>((ref) => false);

// Multi-select mode
final _selectionModeProvider =
    StateProvider.autoDispose<bool>((ref) => false);
final _selectedTxnIdsProvider =
    StateProvider.autoDispose<Set<String>>((ref) => {});

class TransactionsScreen extends ConsumerWidget {
  final String? initialCategory;
  final String? initialSearch;
  const TransactionsScreen({super.key, this.initialCategory, this.initialSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(transactionsProvider);
    final query = ref.watch(_txnSearchProvider).toLowerCase();
    final categoryFilter = ref.watch(_txnCategoryFilterProvider);
    final categories = ref.watch(categoriesProvider);
    final sort = ref.watch(_txnSortProvider);
    final dateRange = ref.watch(_txnDateRangeProvider);
    final amountRange = ref.watch(_txnAmountRangeProvider);
    final taxOnly = ref.watch(_txnTaxFilterProvider);
    final selectionMode = ref.watch(_selectionModeProvider);
    final selectedIds = ref.watch(_selectedTxnIdsProvider);

    // Apply deep-link category on first build (provider is null on fresh open)
    if (initialCategory != null && categoryFilter == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_txnCategoryFilterProvider.notifier).state = initialCategory;
      });
    }

    // Apply deep-link search on first build
    if (initialSearch != null && query.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(_txnSearchProvider.notifier).state = initialSearch!;
      });
    }

    void exitSelection() {
      ref.read(_selectionModeProvider.notifier).state = false;
      ref.read(_selectedTxnIdsProvider.notifier).state = {};
    }

    Future<void> deleteSelected(List<TransactionModel> allTxns) async {
      final ids = Set<String>.from(selectedIds);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete transactions?'),
          content: Text(
              'Delete ${ids.length} selected transaction${ids.length == 1 ? '' : 's'}? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed != true) return;
      for (final id in ids) {
        await ref
            .read(transactionNotifierProvider.notifier)
            .deleteTransaction(id);
      }
      exitSelection();
    }

    return AppScaffold(
      appBar: selectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: exitSelection,
              ),
              title: Text('${selectedIds.length} selected'),
              actions: [
                if (selectedIds.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete selected',
                    onPressed: () => txnsAsync.whenData(
                        (txns) => deleteSelected(txns)),
                  ),
              ],
            )
          : AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.verified_outlined,
              color: taxOnly
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: taxOnly ? 'Showing tax deductible only' : 'Tax deductible only',
            onPressed: () => ref
                .read(_txnTaxFilterProvider.notifier)
                .state = !taxOnly,
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list),
                if (amountRange.$1 != null || amountRange.$2 != null)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Amount filter',
            onPressed: () => _showAmountFilter(context, ref, amountRange),
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context, ref),
          ),
          PopupMenuButton<_TxnDateRange>(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.date_range_outlined),
                if (dateRange != _TxnDateRange.all)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Date range',
            initialValue: dateRange,
            onSelected: (d) =>
                ref.read(_txnDateRangeProvider.notifier).state = d,
            itemBuilder: (_) => _TxnDateRange.values
                .map((d) => PopupMenuItem(
                      value: d,
                      child: Row(
                        children: [
                          if (d == dateRange)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text(d.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
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
        bottom: PreferredSize(
          preferredSize:
              Size.fromHeight(categories.isNotEmpty ? 108 : 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                                ref.read(_txnSearchProvider.notifier).state =
                                    '',
                          )
                        : null,
                  ),
                  onChanged: (v) =>
                      ref.read(_txnSearchProvider.notifier).state = v,
                ),
              ),
              if (categories.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 4),
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
            ],
          ),
        ),
      ),
      floatingActionButton: selectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/snap/review'),
              tooltip: 'Add transaction',
              child: const Icon(Icons.add),
            ),
      body: txnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTxns) {
          var txns = categoryFilter == null
              ? allTxns
              : allTxns
                  .where((t) => t.category == categoryFilter)
                  .toList();

          // Apply date range filter
          if (dateRange != _TxnDateRange.all) {
            final now = DateTime.now();
            final DateTime from;
            final DateTime? to;
            switch (dateRange) {
              case _TxnDateRange.thisMonth:
                from = DateTime(now.year, now.month);
                to = null;
              case _TxnDateRange.lastMonth:
                from = DateTime(now.year, now.month - 1);
                to = DateTime(now.year, now.month);
              case _TxnDateRange.last30Days:
                from = now.subtract(const Duration(days: 30));
                to = null;
              case _TxnDateRange.last7Days:
                from = now.subtract(const Duration(days: 7));
                to = null;
              case _TxnDateRange.all:
                from = DateTime(2000);
                to = null;
            }
            txns = txns
                .where((t) =>
                    !t.date.isBefore(from) &&
                    (to == null || t.date.isBefore(to)))
                .toList();
          }

          if (taxOnly) {
            txns = txns.where((t) => t.isTaxDeductible).toList();
          }

          if (amountRange.$1 != null || amountRange.$2 != null) {
            txns = txns.where((t) {
              if (amountRange.$1 != null && t.amountZAR < amountRange.$1!)
                return false;
              if (amountRange.$2 != null && t.amountZAR > amountRange.$2!)
                return false;
              return true;
            }).toList();
          }

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
          final filteredTotal =
              txns.fold(0.0, (sum, t) => sum + t.amountZAR);
          final isFiltered = query.isNotEmpty ||
              categoryFilter != null ||
              dateRange != _TxnDateRange.all ||
              amountRange.$1 != null ||
              amountRange.$2 != null ||
              taxOnly;

          // Group by date
          final groups = <String, List<TransactionModel>>{};
          for (final txn in txns) {
            groups.putIfAbsent(_dateKey(txn.date), () => []).add(txn);
          }

          final items = <_ListItem>[];
          for (final entry in groups.entries) {
            final dailyTotal =
                entry.value.fold(0.0, (sum, t) => sum + t.amountZAR);
            items.add(_HeaderItem(entry.key, dailyTotal));
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
                      horizontal: 16, vertical: 6),
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${txns.length} result${txns.length == 1 ? '' : 's'} · '
                          '${CurrencyFormatter.format(filteredTotal, 'ZAR')} total',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.read(_txnSearchProvider.notifier).state = '';
                          ref.read(_txnCategoryFilterProvider.notifier).state = null;
                          ref.read(_txnDateRangeProvider.notifier).state = _TxnDateRange.all;
                          ref.read(_txnAmountRangeProvider.notifier).state = (null, null);
                          ref.read(_txnTaxFilterProvider.notifier).state = false;
                        },
                        child: Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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
                        return _DateHeader(
                            label: item.label, total: item.dailyTotal);
                      }
                      final txn = (item as _TxnItem).transaction;
                      if (selectionMode) {
                        final isSelected = selectedIds.contains(txn.txnId);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) {
                            final current = Set<String>.from(selectedIds);
                            if (isSelected) {
                              current.remove(txn.txnId);
                            } else {
                              current.add(txn.txnId);
                            }
                            ref
                                .read(_selectedTxnIdsProvider.notifier)
                                .state = current;
                            if (current.isEmpty) exitSelection();
                          },
                          title: Text(txn.vendor,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            txn.note != null && txn.note!.isNotEmpty
                                ? txn.note!
                                : '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: Text(
                            CurrencyFormatter.format(
                                txn.amountZAR, 'ZAR'),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          controlAffinity:
                              ListTileControlAffinity.leading,
                        );
                      }
                      return _DismissibleTile(
                        transaction: txn,
                        onDelete: () =>
                            _confirmDelete(context, ref, txn),
                        onTap: () => _showDetail(context, ref, txn),
                        onLongPress: () {
                          ref
                              .read(_selectionModeProvider.notifier)
                              .state = true;
                          ref
                              .read(_selectedTxnIdsProvider.notifier)
                              .state = {txn.txnId};
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
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

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final allTxns = ref.read(transactionsProvider).asData?.value ?? [];
    final categoryFilter = ref.read(_txnCategoryFilterProvider);
    final dateRange = ref.read(_txnDateRangeProvider);
    final query = ref.read(_txnSearchProvider).toLowerCase();
    final amountRange = ref.read(_txnAmountRangeProvider);
    final taxOnly = ref.read(_txnTaxFilterProvider);

    var txns = categoryFilter == null
        ? allTxns
        : allTxns.where((t) => t.category == categoryFilter).toList();

    if (dateRange != _TxnDateRange.all) {
      final now = DateTime.now();
      DateTime from;
      DateTime? to;
      switch (dateRange) {
        case _TxnDateRange.thisMonth:
          from = DateTime(now.year, now.month);
          to = null;
        case _TxnDateRange.lastMonth:
          from = DateTime(now.year, now.month - 1);
          to = DateTime(now.year, now.month);
        case _TxnDateRange.last30Days:
          from = now.subtract(const Duration(days: 30));
          to = null;
        case _TxnDateRange.last7Days:
          from = now.subtract(const Duration(days: 7));
          to = null;
        case _TxnDateRange.all:
          from = DateTime(2000);
          to = null;
      }
      txns = txns
          .where((t) =>
              !t.date.isBefore(from) && (to == null || t.date.isBefore(to)))
          .toList();
    }

    if (taxOnly) {
      txns = txns.where((t) => t.isTaxDeductible).toList();
    }

    if (amountRange.$1 != null || amountRange.$2 != null) {
      txns = txns.where((t) {
        if (amountRange.$1 != null && t.amountZAR < amountRange.$1!)
          return false;
        if (amountRange.$2 != null && t.amountZAR > amountRange.$2!)
          return false;
        return true;
      }).toList();
    }

    if (query.isNotEmpty) {
      txns = txns
          .where((t) =>
              t.vendor.toLowerCase().contains(query) ||
              t.category.toLowerCase().contains(query) ||
              (t.note?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    if (txns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }

    final categories = ref.read(categoriesProvider);
    final catById = {for (final c in categories) c.categoryId: c};

    final buffer = StringBuffer();
    buffer.writeln(
        'Date,Vendor,Category,Amount,Currency,Amount (ZAR),Tax Deductible,Note,Source');
    for (final t in txns) {
      final catName = catById[t.category]?.name ?? t.category;
      final note = (t.note ?? '').replaceAll(',', ';');
      buffer.writeln(
        '${t.date.toIso8601String().substring(0, 10)},'
        '"${t.vendor.replaceAll('"', "'")}",'
        '$catName,'
        '${t.amount.toStringAsFixed(2)},'
        '${t.currency},'
        '${t.amountZAR.toStringAsFixed(2)},'
        '${t.isTaxDeductible ? 'Yes' : 'No'},'
        '$note,'
        '${t.source}',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final dir = await getTemporaryDirectory();
    final file =
        File('${dir.path}/snapspend_transactions_$timestamp.csv');
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'SnapSpend Transactions Export',
    );
  }

  Future<void> _showAmountFilter(
    BuildContext context,
    WidgetRef ref,
    (double?, double?) current,
  ) async {
    final minCtrl =
        TextEditingController(text: current.$1?.toStringAsFixed(0) ?? '');
    final maxCtrl =
        TextEditingController(text: current.$2?.toStringAsFixed(0) ?? '');

    final result = await showDialog<(double?, double?)?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter by Amount (ZAR)'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: minCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Min',
                  prefixText: 'R ',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: maxCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max',
                  prefixText: 'R ',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, (null, null)),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final min = double.tryParse(minCtrl.text);
              final max = double.tryParse(maxCtrl.text);
              Navigator.pop(ctx, (min, max));
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (result != null) {
      ref.read(_txnAmountRangeProvider.notifier).state = result;
    }
  }
}

// ── List item types ─────────────────────────────────────────────────────────

sealed class _ListItem {}

class _HeaderItem extends _ListItem {
  final String label;
  final double dailyTotal;
  _HeaderItem(this.label, this.dailyTotal);
}

class _TxnItem extends _ListItem {
  final TransactionModel transaction;
  _TxnItem(this.transaction);
}

// ── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String label;
  final double total;
  const _DateHeader({required this.label, required this.total});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(CurrencyFormatter.format(total, 'ZAR'), style: style),
        ],
      ),
    );
  }
}

// ── Dismissible tile ─────────────────────────────────────────────────────────

class _DismissibleTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DismissibleTile({
    required this.transaction,
    required this.onDelete,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(transaction.txnId),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        } else {
          // Swipe start-to-end: edit
          context.push('/edit-transaction', extra: transaction);
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.edit_outlined, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: _TransactionTile(
          transaction: transaction,
          onTap: onTap,
          onLongPress: onLongPress),
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TransactionTile(
      {required this.transaction, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(transaction.category));

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: transaction.receiptStoragePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                transaction.receiptStoragePath!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(category?.icon ?? '📋',
                      style: const TextStyle(fontSize: 18)),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(category?.icon ?? '📋',
                            style: const TextStyle(fontSize: 18)),
                      ),
              ),
            )
          : CircleAvatar(
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
      subtitle: Text(
        transaction.note != null && transaction.note!.isNotEmpty
            ? '${category?.name ?? transaction.category} · ${transaction.note}'
            : category?.name ?? transaction.category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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

  Future<void> _duplicateTransaction(
      BuildContext context, WidgetRef ref, TransactionModel t) async {
    Navigator.pop(context);
    final duplicate = t.copyWith(
      txnId: const Uuid().v4(),
      date: DateTime.now(),
      receiptStoragePath: null,
      ocrRawText: null,
      ocrConfidence: null,
      flaggedForReview: false,
      source: 'manual',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref
        .read(transactionNotifierProvider.notifier)
        .addTransaction(duplicate);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Duplicated "${t.vendor}"'),
          action: SnackBarAction(
            label: 'Edit',
            onPressed: () =>
                context.push('/edit-transaction', extra: duplicate),
          ),
        ),
      );
    }
  }

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
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _duplicateTransaction(context, ref, t),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Duplicate'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(transactionNotifierProvider.notifier)
                          .updateTransaction(
                              t.copyWith(flaggedForReview: false));
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber.shade800,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Dismiss'),
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
