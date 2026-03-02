import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:snapspend_core/snapspend_core.dart';

class TransactionListTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final String? categoryIcon;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: transaction.receiptStoragePath != null
            ? _ReceiptThumbnail(
                storagePath: transaction.receiptStoragePath!,
                fallbackIcon:
                    categoryIcon ?? _categoryEmoji(transaction.category),
              )
            : CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  categoryIcon ?? _categoryEmoji(transaction.category),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
        title: Text(
          transaction.vendor,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: transaction.note != null && transaction.note!.isNotEmpty
            ? Text(
                '${DateFormatter.formatRelative(transaction.date)} · ${transaction.note!}',
                overflow: TextOverflow.ellipsis,
              )
            : Text(DateFormatter.formatRelative(transaction.date)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyFormatter.format(transaction.amountZAR, 'ZAR'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (transaction.isTaxDeductible)
              const Text(
                'Tax deductible',
                style: TextStyle(fontSize: 10, color: Colors.green),
              ),
            if (transaction.flaggedForReview)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 10, color: Colors.amber.shade700),
                  const SizedBox(width: 2),
                  Text(
                    'Review',
                    style: TextStyle(
                        fontSize: 10, color: Colors.amber.shade700),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _categoryEmoji(String categoryId) {
    try {
      return CategoryConstants.defaultCategories
          .firstWhere((c) => c.categoryId == categoryId)
          .icon;
    } catch (_) {
      return '📋';
    }
  }
}

/// Resolves a Firebase Storage path (or legacy download URL) to a thumbnail.
/// Supports both formats:
///   - Storage path:   "receipts/uid/txnId.jpg"
///   - Download URL:   "https://firebasestorage.googleapis.com/..."
class _ReceiptThumbnail extends StatefulWidget {
  final String storagePath;
  final String fallbackIcon;

  const _ReceiptThumbnail({
    required this.storagePath,
    required this.fallbackIcon,
  });

  @override
  State<_ReceiptThumbnail> createState() => _ReceiptThumbnailState();
}

class _ReceiptThumbnailState extends State<_ReceiptThumbnail> {
  late final Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    final path = widget.storagePath;
    // If already a download URL, use it directly; otherwise resolve via Storage.
    if (path.startsWith('https://')) {
      _urlFuture = Future.value(path);
    } else {
      _urlFuture =
          FirebaseStorage.instance.ref(path).getDownloadURL();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              snapshot.data!,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _fallback(context),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : _fallback(context),
            ),
          );
        }
        return _fallback(context);
      },
    );
  }

  Widget _fallback(BuildContext context) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(widget.fallbackIcon,
          style: const TextStyle(fontSize: 18)),
    );
  }
}
