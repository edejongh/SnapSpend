import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  final OcrResult? ocrResult;
  final TransactionModel? existingTransaction;

  const ReceiptReviewScreen({
    super.key,
    this.ocrResult,
    this.existingTransaction,
  });

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

  /// ZAR exchange rate for the selected currency (1 <currency> = _rateToZAR ZAR).
  double _rateToZAR = 1.0;
  bool _fetchingRate = false;

  bool get _isEditing => widget.existingTransaction != null;

  @override
  void initState() {
    super.initState();
    final txn = widget.existingTransaction;
    final ocr = widget.ocrResult;

    // Determine default currency: existing txn > OCR > user profile > app default
    final profileCurrency = ref
            .read(currentUserProvider)
            .asData
            ?.value
            ?.defaultCurrency ??
        AppConstants.defaultCurrency;

    if (txn != null) {
      _amountCtrl = TextEditingController(
        text: txn.amount.toStringAsFixed(2),
      );
      _vendorCtrl = TextEditingController(text: txn.vendor);
      _noteCtrl = TextEditingController(text: txn.note ?? '');
      _selectedCurrency = txn.currency;
      _selectedCategory = txn.category;
      _selectedDate = txn.date;
      _isTaxDeductible = txn.isTaxDeductible;
      // Derive the stored rate so the ZAR hint shows correctly immediately
      if (txn.currency != AppConstants.defaultCurrency && txn.amount > 0) {
        _rateToZAR = txn.amountZAR / txn.amount;
      }
    } else {
      _amountCtrl = TextEditingController(
        text: ocr?.extractedAmount?.toStringAsFixed(2) ?? '',
      );
      _vendorCtrl = TextEditingController(text: ocr?.extractedVendor ?? '');
      _noteCtrl = TextEditingController();
      _selectedCurrency = profileCurrency;
      _selectedCategory = ocr?.suggestedCategory;
      _selectedDate = ocr?.extractedDate ?? DateTime.now();
      _isTaxDeductible = false;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _vendorCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onCurrencyChanged(String currency) async {
    setState(() {
      _selectedCurrency = currency;
      if (currency == AppConstants.defaultCurrency) {
        _rateToZAR = 1.0;
        _fetchingRate = false;
      } else {
        _fetchingRate = true;
      }
    });
    if (currency == AppConstants.defaultCurrency) return;
    try {
      final rate = await ref
          .read(currencyServiceProvider)
          .convert(1.0, currency, AppConstants.defaultCurrency);
      if (mounted) setState(() { _rateToZAR = rate; _fetchingRate = false; });
    } catch (_) {
      if (mounted) setState(() { _fetchingRate = false; });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final existing = widget.existingTransaction;
    final ocr = widget.ocrResult;
    final noteText = _noteCtrl.text.trim();

    final txn = TransactionModel(
      txnId: existing?.txnId ?? const Uuid().v4(),
      amount: amount,
      currency: _selectedCurrency,
      amountZAR: amount * _rateToZAR,
      category: _selectedCategory ?? 'other',
      vendor: _vendorCtrl.text.trim(),
      date: _selectedDate,
      note: noteText.isEmpty ? null : noteText,
      isTaxDeductible: _isTaxDeductible,
      ocrRawText: existing?.ocrRawText ?? ocr?.rawText,
      ocrConfidence: existing?.ocrConfidence ?? ocr?.confidence,
      source: existing?.source ?? (ocr != null ? 'ocr' : 'manual'),
      flaggedForReview: existing?.flaggedForReview ??
          (ocr?.confidence ?? 1.0) < AppConstants.ocrFlagThreshold,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (_isEditing) {
      await ref
          .read(transactionNotifierProvider.notifier)
          .updateTransaction(txn);
      if (mounted) context.pop();
    } else {
      await ref
          .read(transactionNotifierProvider.notifier)
          .addTransaction(txn);
      if (mounted) context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocr = widget.ocrResult;
    final categories = ref.watch(categoriesProvider);
    final lowConfidence =
        ocr != null && ocr.confidence < AppConstants.ocrConfidenceThreshold;
    final isNonZAR = _selectedCurrency != AppConstants.defaultCurrency;

    final title = _isEditing
        ? 'Edit Transaction'
        : (ocr != null ? 'Review Receipt' : 'Add Transaction');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: Validators.amount,
                    onChanged: (_) => setState(() {}),
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
                        _onCurrencyChanged(v ?? AppConstants.defaultCurrency),
                  ),
                ),
              ],
            ),
            if (isNonZAR) ...[
              const SizedBox(height: 6),
              _buildZarHint(),
            ],
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
              subtitle: Text(DateFormatter.formatDate(_selectedDate)),
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
            PrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Save Transaction',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZarHint() {
    if (_fetchingRate) {
      return const Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text(
            'Fetching exchange rate…',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final zarAmount = amount * _rateToZAR;
    return Text(
      '≈ ${CurrencyFormatter.format(zarAmount, 'ZAR')}  '
      '(1 $_selectedCurrency = ${CurrencyFormatter.format(_rateToZAR, 'ZAR')})',
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
    );
  }
}
