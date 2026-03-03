import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';

void showTransactionDetail(
    BuildContext context, TransactionModel transaction) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => TransactionDetailSheet(transaction: transaction),
  );
}

/// Shows a bottom sheet listing all transactions for [day].
/// Each row is tappable to open the full [TransactionDetailSheet].
void showDayTransactionsSheet(
    BuildContext context, DateTime day, List<TransactionModel> allTxns) {
  final dayTxns = allTxns
      .where((t) =>
          t.date.year == day.year &&
          t.date.month == day.month &&
          t.date.day == day.day)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  if (dayTxns.isEmpty) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DayTransactionsSheet(day: day, transactions: dayTxns),
  );
}

class _DayTransactionsSheet extends ConsumerWidget {
  final DateTime day;
  final List<TransactionModel> transactions;
  const _DayTransactionsSheet(
      {required this.day, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total =
        transactions.fold(0.0, (sum, t) => sum + t.amountZAR);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormatter.formatDate(day),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                CurrencyFormatter.format(total, 'ZAR'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in transactions) _DayTxnRow(transaction: t),
        ],
      ),
    );
  }
}

class _DayTxnRow extends ConsumerWidget {
  final TransactionModel transaction;
  const _DayTxnRow({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category =
        ref.watch(categoryByIdProvider(transaction.category));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(category?.icon ?? '📋'),
      ),
      title: Text(transaction.vendor,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(category?.name ?? transaction.category),
      trailing: Text(
        CurrencyFormatter.format(transaction.amountZAR, 'ZAR'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      onTap: () => showTransactionDetail(context, transaction),
    );
  }
}

class TransactionDetailSheet extends ConsumerWidget {
  final TransactionModel transaction;
  const TransactionDetailSheet({super.key, required this.transaction});

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

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, TransactionModel t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
            'Remove "${t.vendor}" — ${CurrencyFormatter.format(t.amountZAR, 'ZAR')}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(transactionNotifierProvider.notifier)
          .deleteTransaction(t.txnId);
      if (context.mounted) Navigator.pop(context);
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

    // Vendor history (all other transactions with same vendor)
    final allTxns = ref.watch(transactionsProvider).asData?.value ?? [];
    final vendorTxns = allTxns
        .where((tx) => tx.vendor == t.vendor && tx.txnId != t.txnId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final vendorTotal = vendorTxns.fold(0.0, (s, tx) => s + tx.amountZAR);
    final vendorAvg =
        vendorTxns.isEmpty ? null : vendorTotal / vendorTxns.length;
    final recentVisits = vendorTxns.take(3).toList();

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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _confirmDelete(context, ref, t),
                icon: Icon(Icons.delete_outline,
                    size: 18,
                    color: Theme.of(context).colorScheme.error),
                label: Text('Delete',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  side: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .error
                          .withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          if (t.receiptStoragePath != null) ...[
            const SizedBox(height: 12),
            _ReceiptImage(storagePath: t.receiptStoragePath!),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Tap to zoom',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
          const Divider(height: 32),
          _DetailRow(
              label: 'Date', value: DateFormatter.formatDate(t.date)),
          if (t.currency != 'ZAR')
            _DetailRow(
                label: 'Original amount',
                value:
                    '${CurrencyFormatter.format(t.amount, t.currency)} ${t.currency}'),
          _DetailRow(
              label: 'Source',
              value:
                  t.source == 'ocr' ? 'Scanned receipt' : 'Manual entry'),
          if (t.ocrConfidence != null)
            _DetailRow(
                label: 'OCR confidence',
                value:
                    '${(t.ocrConfidence! * 100).toStringAsFixed(0)}%'),
          _DetailRow(
              label: 'Tax deductible',
              value: t.isTaxDeductible ? 'Yes' : 'No'),
          if (t.note != null && t.note!.isNotEmpty)
            _DetailRow(label: 'Note', value: t.note!),
          if (vendorTxns.isNotEmpty) ...[
            const Divider(height: 28),
            Text(
              '${t.vendor} history',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
            ),
            const SizedBox(height: 8),
            _DetailRow(
                label: 'Visits',
                value:
                    '${vendorTxns.length + 1} total (${vendorTxns.length} other)'),
            _DetailRow(
                label: 'Total spent',
                value: CurrencyFormatter.format(
                    vendorTotal + t.amountZAR, 'ZAR')),
            if (vendorAvg != null)
              _DetailRow(
                  label: 'Avg per visit',
                  value: CurrencyFormatter.format(
                      (vendorTotal + t.amountZAR) / (vendorTxns.length + 1),
                      'ZAR')),
            const SizedBox(height: 10),
            // Last 3 visits (excluding current transaction)
            for (final tx in recentVisits)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => showTransactionDetail(context, tx),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Text(
                        DateFormatter.formatDate(tx.date),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(tx.amountZAR, 'ZAR'),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 14, color: Colors.grey.shade400),
                    ],
                  ),
                ),
              ),
          ],
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

/// Resolves a Firebase Storage path (or legacy HTTPS download URL) and
/// shows the receipt image. Tapping opens the full-screen viewer.
class _ReceiptImage extends StatefulWidget {
  final String storagePath;
  const _ReceiptImage({required this.storagePath});

  @override
  State<_ReceiptImage> createState() => _ReceiptImageState();
}

class _ReceiptImageState extends State<_ReceiptImage> {
  late final Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    final path = widget.storagePath;
    _urlFuture = path.startsWith('https://')
        ? Future.value(path)
        : FirebaseStorage.instance.ref(path).getDownloadURL();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text('Image unavailable',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final url = snapshot.data!;
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) =>
                  _ReceiptViewer(url: url, heroTag: widget.storagePath),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Hero(
              tag: widget.storagePath,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => SizedBox(
                  height: 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            size: 36, color: Colors.grey.shade400),
                        const SizedBox(height: 8),
                        Text('Image unavailable',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReceiptViewer extends StatelessWidget {
  final String url;
  // heroTag must match the tag used in _ReceiptImage (the storage path).
  final String heroTag;
  const _ReceiptViewer({required this.url, required this.heroTag});

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
            tag: heroTag,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const CircularProgressIndicator(
                    color: Colors.white);
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
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 14)),
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
