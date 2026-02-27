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
        .toList();
    final vendorTotal = vendorTxns.fold(0.0, (s, tx) => s + tx.amountZAR);
    final vendorAvg =
        vendorTxns.isEmpty ? null : vendorTotal / vendorTxns.length;

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
