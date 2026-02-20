import 'package:flutter/material.dart';
import 'package:snapspend_core/snapspend_core.dart';

class TransactionListTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;

  const TransactionListTile({
    super.key,
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            _categoryEmoji(transaction.category),
            style: const TextStyle(fontSize: 18),
          ),
        ),
        title: Text(
          transaction.vendor,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(DateFormatter.formatRelative(transaction.date)),
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
