import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  final OcrResult? ocrResult;

  const ReceiptReviewScreen({super.key, this.ocrResult});

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _vendorCtrl;
  late final TextEditingController _noteCtrl;
  late String _selectedCurrency;
  late String? _selectedCategory;
  late DateTime _selectedDate;
  late bool _isTaxDeductible;

  @override
  void initState() {
    super.initState();
    final ocr = widget.ocrResult;
    _amountCtrl = TextEditingController(
      text: ocr?.extractedAmount?.toStringAsFixed(2) ?? '',
    );
    _vendorCtrl = TextEditingController(text: ocr?.extractedVendor ?? '');
    _noteCtrl = TextEditingController();
    _selectedCurrency = AppConstants.defaultCurrency;
    _selectedCategory = ocr?.suggestedCategory;
    _selectedDate = ocr?.extractedDate ?? DateTime.now();
    _isTaxDeductible = false;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final txn = TransactionModel(
      txnId: const Uuid().v4(),
      amount: amount,
      currency: _selectedCurrency,
      amountZAR: amount, // TODO: Convert via CurrencyService if not ZAR
      category: _selectedCategory ?? 'other',
      vendor: _vendorCtrl.text.trim(),
      date: _selectedDate,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      isTaxDeductible: _isTaxDeductible,
      ocrRawText: widget.ocrResult?.rawText,
      ocrConfidence: widget.ocrResult?.confidence,
      source: widget.ocrResult != null ? 'ocr' : 'manual',
      flaggedForReview:
          (widget.ocrResult?.confidence ?? 1.0) < AppConstants.ocrFlagThreshold,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await ref.read(transactionNotifierProvider.notifier).addTransaction(txn);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final ocr = widget.ocrResult;
    final categories = ref.watch(categoriesProvider);
    final lowConfidence =
        ocr != null && ocr.confidence < AppConstants.ocrConfidenceThreshold;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Receipt')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (lowConfidence)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                    Expanded(
                      child: Text(
                        'OCR confidence is low — please review',
                        style: TextStyle(color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            // Amount + Currency row
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: Validators.amount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: AppConstants.supportedCurrencies
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCurrency = v ?? 'ZAR'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(labelText: 'Vendor'),
              validator: (v) => Validators.required(v, fieldName: 'Vendor'),
            ),
            const SizedBox(height: 12),
            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle:
                  Text(DateFormatter.formatDate(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Category'),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.categoryId,
                      child: Text('${c.icon} ${c.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a note...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax Deductible'),
              value: _isTaxDeductible,
              onChanged: (v) => setState(() => _isTaxDeductible = v),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Save Transaction', onPressed: _save),
          ],
        ),
      ),
    );
  }
}
