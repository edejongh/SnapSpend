import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/flags_provider.dart';
import '../../../core/services/admin_firebase_service.dart';
import '../../../shared/widgets/admin_sidebar.dart';
import '../widgets/flag_card.dart';

class OcrReviewScreen extends ConsumerStatefulWidget {
  const OcrReviewScreen({super.key});

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  TransactionModel? _selectedFlag;

  @override
  Widget build(BuildContext context) {
    final flagsAsync = ref.watch(openFlagsProvider);

    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('OCR Review'),
                ),
                Expanded(
                  child: flagsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (flags) => Row(
                      children: [
                        // Left panel — flags list
                        SizedBox(
                          width: 360,
                          child: flags.isEmpty
                              ? const Center(
                                  child: Text('No open flags'),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: flags.length,
                                  itemBuilder: (context, i) => FlagCard(
                                    transaction: flags[i],
                                    isSelected:
                                        _selectedFlag?.txnId ==
                                            flags[i].txnId,
                                    onTap: () => setState(
                                      () => _selectedFlag = flags[i],
                                    ),
                                  ),
                                ),
                        ),
                        const VerticalDivider(width: 1),
                        // Right panel — selected flag detail
                        Expanded(
                          child: _selectedFlag == null
                              ? const Center(
                                  child: Text(
                                    'Select a flag to review',
                                  ),
                                )
                              : _FlagDetailPanel(
                                  transaction: _selectedFlag!,
                                  onResolved: () {
                                    setState(() => _selectedFlag = null);
                                    ref.invalidate(openFlagsProvider);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagDetailPanel extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback onResolved;

  const _FlagDetailPanel({
    required this.transaction,
    required this.onResolved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.vendor,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Amount: ${CurrencyFormatter.format(transaction.amount, transaction.currency)}'),
          Text('Date: ${DateFormatter.formatDate(transaction.date)}'),
          Text('Category: ${transaction.category}'),
          Text(
            'OCR Confidence: ${((transaction.ocrConfidence ?? 0) * 100).toStringAsFixed(0)}%',
          ),
          const SizedBox(height: 16),
          if (transaction.ocrRawText != null) ...[
            Text(
              'Raw OCR Text:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                transaction.ocrRawText!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () async {
                  await AdminFirebaseService()
                      .resolveFlag(transaction.txnId, 'approved');
                  onResolved();
                },
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await AdminFirebaseService()
                      .resolveFlag(transaction.txnId, 'corrected');
                  onResolved();
                },
                icon: const Icon(Icons.edit),
                label: const Text('Correct'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () async {
                  await AdminFirebaseService()
                      .resolveFlag(transaction.txnId, 'dismissed');
                  onResolved();
                },
                icon: const Icon(Icons.close),
                label: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
