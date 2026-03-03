import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/flags_provider.dart';
import '../../../core/providers/users_provider.dart';
import '../../../shared/widgets/admin_sidebar.dart';
import '../widgets/flag_card.dart';
import '../widgets/receipt_image_viewer.dart';

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
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 48, color: Colors.green),
                                      SizedBox(height: 12),
                                      Text('No open flags'),
                                    ],
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 4),
                                      child: Text(
                                        '${flags.length} flag${flags.length == 1 ? '' : 's'} open',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                              letterSpacing: 0.5,
                                            ),
                                      ),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 4),
                                        itemCount: flags.length,
                                        itemBuilder: (context, i) =>
                                            FlagCard(
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
                                  ],
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

  Future<void> _resolve(
      BuildContext context, WidgetRef ref, String resolution) async {
    final labels = {
      'approved': 'approved',
      'corrected': 'marked for correction',
      'dismissed': 'dismissed',
    };
    try {
      await ref.read(adminFirebaseServiceProvider).resolveFlag(transaction.txnId, resolution);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Flag ${labels[resolution] ?? resolution}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        onResolved();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasImage = transaction.receiptStoragePath != null;
    final imageUrlAsync = hasImage
        ? ref.watch(receiptDownloadUrlProvider(transaction.receiptStoragePath!))
        : null;

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
          const SizedBox(height: 4),
          _ConfidenceChip(confidence: transaction.ocrConfidence ?? 0),
          const SizedBox(height: 16),
          // Receipt image
          if (hasImage)
            SizedBox(
              height: 180,
              child: imageUrlAsync!.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const SizedBox.shrink(),
                data: (url) => ReceiptImageViewer(imageUrl: url),
              ),
            ),
          if (hasImage) const SizedBox(height: 16),
          if (transaction.ocrRawText != null) ...[
            Text(
              'Raw OCR Text:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transaction.ocrRawText!,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => _resolve(context, ref, 'approved'),
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _resolve(context, ref, 'corrected'),
                icon: const Icon(Icons.edit),
                label: const Text('Correct'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                onPressed: () => _resolve(context, ref, 'dismissed'),
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

class _ConfidenceChip extends StatelessWidget {
  final double confidence;
  const _ConfidenceChip({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.5
            ? Colors.orange
            : Colors.red;
    final label = confidence >= 0.7
        ? 'High confidence'
        : confidence >= 0.5
            ? 'Medium confidence'
            : 'Low confidence';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.analytics_outlined, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                '$label · ${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
