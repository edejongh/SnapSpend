import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/budget_provider.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class BudgetSetupScreen extends ConsumerWidget {
  const BudgetSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('No budgets yet',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Tap + to set your first budget',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: budgets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _BudgetTile(budget: budgets[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBudgetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showBudgetSheet(BuildContext context, WidgetRef ref,
      [BudgetModel? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BudgetSheet(existingBudget: existing),
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  final BudgetModel budget;
  const _BudgetTile({required this.budget});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = budget.categoryId != null
        ? ref.watch(categoryByIdProvider(budget.categoryId!))
        : null;
    final label = category != null
        ? '${category.icon} ${category.name}'
        : 'Overall';

    final utilisation = ref.watch(budgetUtilisationProvider);
    final utilisationKey = budget.categoryId ?? 'overall';
    final pct = (utilisation[utilisationKey] ?? 0.0).clamp(0.0, 1.0);

    // Current spend for this budget
    final monthlySpend = ref.watch(monthlySpendProvider);
    final spendByCategory = ref.watch(spendByCategoryProvider);
    final spent = budget.categoryId == null
        ? monthlySpend
        : (spendByCategory[budget.categoryId] ?? 0.0);

    final isOver = pct >= 1.0;
    final isNearLimit = pct >= budget.alertAt;
    final barColor = isOver
        ? Theme.of(context).colorScheme.error
        : isNearLimit
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBudgetSheet(context, ref, budget),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(budget.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        Text(
                          '${CurrencyFormatter.format(spent, 'ZAR')} / ${CurrencyFormatter.format(budget.limitAmount, 'ZAR')}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: isOver
                                        ? Theme.of(context)
                                            .colorScheme
                                            .error
                                        : Colors.grey.shade600,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$label · ${(pct * 100).toStringAsFixed(0)}% used',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete budget?'),
                content: Text('Remove "${budget.name}"?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete')),
                ],
              ),
            );
            if (confirmed == true) {
              await ref
                  .read(budgetNotifierProvider.notifier)
                  .deleteBudget(budget.budgetId);
            }
          },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetSheet(BuildContext context, WidgetRef ref,
      BudgetModel existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BudgetSheet(existingBudget: existing),
    );
  }
}

class _BudgetSheet extends ConsumerStatefulWidget {
  final BudgetModel? existingBudget;
  const _BudgetSheet({this.existingBudget});

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _limitCtrl;
  late String? _selectedCategoryId;
  late double _alertAt;

  bool get _isEditing => widget.existingBudget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.existingBudget;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _limitCtrl = TextEditingController(
        text: b != null ? b.limitAmount.toStringAsFixed(2) : '');
    _selectedCategoryId = b?.categoryId;
    _alertAt = b?.alertAt ?? 0.8;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final existing = widget.existingBudget;
    final budget = BudgetModel(
      budgetId: existing?.budgetId ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      limitAmount: double.parse(_limitCtrl.text),
      period: 'monthly',
      categoryId: _selectedCategoryId,
      alertAt: _alertAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    if (_isEditing) {
      await ref.read(budgetNotifierProvider.notifier).updateBudget(budget);
    } else {
      await ref.read(budgetNotifierProvider.notifier).addBudget(budget);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final notifierState = ref.watch(budgetNotifierProvider);
    final avgCategorySpend = ref.watch(avgMonthlyCategorySpendProvider);

    // Suggestion = avg monthly spend for selected category (or overall)
    final suggested = _selectedCategoryId != null
        ? avgCategorySpend[_selectedCategoryId]
        : (avgCategorySpend.values.isEmpty
            ? null
            : avgCategorySpend.values.fold(0.0, (a, b) => a + b));

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit Budget' : 'Add Budget',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Budget name'),
              validator: (v) => Validators.required(v, fieldName: 'Name'),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _limitCtrl,
              decoration: const InputDecoration(
                  labelText: 'Monthly limit (ZAR)', prefixText: 'R '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.amount,
            ),
            if (suggested != null && suggested > 0 && !_isEditing) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => setState(() =>
                    _limitCtrl.text = suggested.toStringAsFixed(0)),
                child: Text(
                  'Suggested: R ${suggested.toStringAsFixed(0)} / mo'
                  ' (3-month avg)  — tap to use',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Overall (all spending)')),
                ...categories.map((c) => DropdownMenuItem(
                    value: c.categoryId, child: Text('${c.icon} ${c.name}'))),
              ],
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Alert at ${(_alertAt * 100).toInt()}%',
                    style: Theme.of(context).textTheme.bodyMedium),
                Expanded(
                  child: Slider(
                    value: _alertAt,
                    min: 0.5,
                    max: 1.0,
                    divisions: 10,
                    onChanged: (v) => setState(() => _alertAt = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (notifierState.hasError)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(notifierState.error.toString(),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            PrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Save Budget',
              onPressed: notifierState.isLoading ? null : _save,
              isLoading: notifierState.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
