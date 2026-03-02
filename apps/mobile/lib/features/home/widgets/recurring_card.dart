import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';

class RecurringCard extends ConsumerWidget {
  const RecurringCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurring = ref.watch(recurringTransactionsProvider);
    if (recurring.isEmpty) return const SizedBox.shrink();

    final totalMonthly =
        recurring.fold(0.0, (sum, r) => sum + r.avgMonthlyAmount);

    // Build set of vendor names that have a transaction this month
    final allTxns = ref.watch(transactionsProvider).asData?.value ?? [];
    final now = DateTime.now();
    final thisMonthVendors = allTxns
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .map((t) => t.vendor)
        .toSet();

    final chargedCount =
        recurring.where((r) => thisMonthVendors.contains(r.vendor)).length;
    final pendingCount = recurring.length - chargedCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recurring Expenses',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(totalMonthly, 'ZAR'),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'per month',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ],
            ),
            // Charged vs pending summary
            if (recurring.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  if (chargedCount > 0) ...[
                    Icon(Icons.check_circle_outline,
                        size: 13, color: Colors.green.shade600),
                    const SizedBox(width: 3),
                    Text(
                      '$chargedCount charged',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (pendingCount > 0) ...[
                    Icon(Icons.schedule,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 3),
                    Text(
                      '$pendingCount pending',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 12),
            ...recurring.take(5).map((r) => _RecurringRow(
                vendor: r,
                chargedThisMonth: thisMonthVendors.contains(r.vendor))),
            if (recurring.length > 5)
              GestureDetector(
                onTap: () => _showAllRecurring(context, recurring,
                    thisMonthVendors),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${recurring.length - 5} more',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAllRecurring(BuildContext context,
      List<RecurringVendor> recurring, Set<String> thisMonthVendors) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _AllRecurringSheet(
          recurring: recurring, thisMonthVendors: thisMonthVendors),
    );
  }
}

class _AllRecurringSheet extends StatelessWidget {
  final List<RecurringVendor> recurring;
  final Set<String> thisMonthVendors;
  const _AllRecurringSheet(
      {required this.recurring, required this.thisMonthVendors});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
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
          Text(
            'All Recurring Expenses',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final r in recurring)
            _RecurringRow(
              vendor: r,
              chargedThisMonth: thisMonthVendors.contains(r.vendor),
            ),
        ],
      ),
    );
  }
}

class _RecurringRow extends ConsumerWidget {
  final RecurringVendor vendor;
  final bool chargedThisMonth;
  const _RecurringRow(
      {required this.vendor, required this.chargedThisMonth});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(categoryByIdProvider(vendor.category));

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => context.go(
        '/transactions?search=${Uri.encodeComponent(vendor.vendor)}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: chargedThisMonth
                      ? Colors.green.shade50
                      : Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    cat?.icon ?? '📋',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (chargedThisMonth)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 1.5),
                      ),
                      child: const Icon(Icons.check,
                          size: 8, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.vendor,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: chargedThisMonth
                            ? Colors.grey.shade500
                            : null),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    chargedThisMonth
                        ? 'Charged this month'
                        : '${vendor.monthCount} months',
                    style: TextStyle(
                        fontSize: 11,
                        color: chargedThisMonth
                            ? Colors.green.shade600
                            : Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            Text(
              '${CurrencyFormatter.format(vendor.avgMonthlyAmount, 'ZAR')}/mo',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: chargedThisMonth ? Colors.grey.shade400 : null),
            ),
            const SizedBox(width: 4),
            if (!chargedThisMonth)
              GestureDetector(
                onTap: () => context.push(
                  '/snap/review',
                  extra: OcrResult(
                    rawText: '',
                    confidence: 1.0,
                    extractedAmount: vendor.avgMonthlyAmount,
                    extractedDate: DateTime.now(),
                    extractedVendor: vendor.vendor,
                    suggestedCategory: vendor.category,
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
