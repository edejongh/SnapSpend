import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
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

  bool _receiptExpanded = false;

  /// ZAR exchange rate for the selected currency (1 <currency> = _rateToZAR ZAR).
  double _rateToZAR = 1.0;
  bool _fetchingRate = false;
  bool _isSaving = false;

  /// The current vendor text, kept in sync with _vendorCtrl so we can
  /// watch vendorCategoryProvider reactively.
  String _vendorText = '';
  /// Whether the category was manually set by the user (suppresses suggestions).
  bool _categoryManuallySet = false;

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
    _vendorText = _vendorCtrl.text;
    _vendorCtrl.addListener(() {
      if (mounted && _vendorCtrl.text != _vendorText) {
        setState(() => _vendorText = _vendorCtrl.text);
      }
    });
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
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final existing = widget.existingTransaction;
    final ocr = widget.ocrResult;
    final noteText = _noteCtrl.text.trim();
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    final txnId = existing?.txnId ?? const Uuid().v4();

    // Upload receipt image for new OCR transactions (non-fatal if it fails)
    String? receiptStoragePath = existing?.receiptStoragePath;
    if (!_isEditing && ocr?.imagePath != null && uid != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('receipts/$uid/$txnId.jpg');
        await storageRef.putFile(File(ocr!.imagePath!));
        receiptStoragePath = await storageRef.getDownloadURL();
      } catch (_) {
        // Non-fatal — transaction is saved without an image
      }
    }

    final txn = TransactionModel(
      txnId: txnId,
      amount: amount,
      currency: _selectedCurrency,
      amountZAR: amount * _rateToZAR,
      category: _selectedCategory ?? 'other',
      vendor: _vendorCtrl.text.trim(),
      date: _selectedDate,
      note: noteText.isEmpty ? null : noteText,
      receiptStoragePath: receiptStoragePath,
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
    if (mounted) setState(() => _isSaving = false);
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
                    Expanded(
                      child: Text(
                        'OCR confidence is low — please review carefully',
                        style: TextStyle(color: Colors.amber.shade900, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.amber.shade800,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Retake', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            // Receipt image preview (for OCR scans)
            if (ocr?.imagePath != null) ...[
              _ReceiptPreview(
                imagePath: ocr!.imagePath!,
                expanded: _receiptExpanded,
                onToggle: () =>
                    setState(() => _receiptExpanded = !_receiptExpanded),
              ),
              const SizedBox(height: 12),
            ],
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
            _VendorSuggestions(
              vendor: _vendorText,
              onSelect: (name) {
                _vendorCtrl.text = name;
                setState(() => _vendorText = name);
              },
            ),
            _VendorCategorySuggestion(
              vendor: _vendorText,
              currentCategory: _selectedCategory,
              categoryManuallySet: _categoryManuallySet,
              onAccept: (catId) =>
                  setState(() {
                    _selectedCategory = catId;
                    _categoryManuallySet = true;
                  }),
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
              onChanged: (v) => setState(() {
                _selectedCategory = v;
                _categoryManuallySet = true;
              }),
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
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
            ),
          ],
        ),
      ),
    );
  }

}

// ── Receipt image preview ──────────────────────────────────────────────────────

class _ReceiptPreview extends StatelessWidget {
  final String imagePath;
  final bool expanded;
  final VoidCallback onToggle;

  const _ReceiptPreview({
    required this.imagePath,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: SizedBox(
                height: 80,
                width: double.infinity,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              secondChild: GestureDetector(
                onLongPress: () => _openFullscreen(context),
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Container(
              color: Colors.grey.shade100,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    expanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    expanded ? 'Collapse receipt' : 'View receipt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            title: const Text('Receipt'),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Vendor name autocomplete suggestions ──────────────────────────────────────

class _VendorSuggestions extends ConsumerWidget {
  final String vendor;
  final void Function(String name) onSelect;

  const _VendorSuggestions({required this.vendor, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = vendor.trim();
    if (query.isEmpty) return const SizedBox.shrink();

    final allNames = ref.watch(allVendorNamesProvider);
    final lower = query.toLowerCase();
    final matches = allNames
        .where((n) => n.toLowerCase().contains(lower) && n != query)
        .take(5)
        .toList();

    if (matches.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (final name in matches)
            ActionChip(
              label: Text(name,
                  style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: () => onSelect(name),
            ),
        ],
      ),
    );
  }
}

// ── Vendor category suggestion ────────────────────────────────────────────────

class _VendorCategorySuggestion extends ConsumerWidget {
  final String vendor;
  final String? currentCategory;
  final bool categoryManuallySet;
  final void Function(String catId) onAccept;

  const _VendorCategorySuggestion({
    required this.vendor,
    required this.currentCategory,
    required this.categoryManuallySet,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only suggest when not already manually set
    if (categoryManuallySet) return const SizedBox.shrink();
    final suggestedCatId =
        ref.watch(vendorCategoryProvider(vendor.trim()));
    if (suggestedCatId == null) return const SizedBox.shrink();
    // Don't suggest if it's already the selected category
    if (suggestedCatId == currentCategory) return const SizedBox.shrink();
    final category = ref.watch(categoryByIdProvider(suggestedCatId));
    if (category == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(Icons.history, size: 13, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            'Usually: ',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          GestureDetector(
            onTap: () => onAccept(suggestedCatId),
            child: Text(
              '${category.icon} ${category.name}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Text(
            ' — tap to use',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

extension on _ReceiptReviewScreenState {
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
