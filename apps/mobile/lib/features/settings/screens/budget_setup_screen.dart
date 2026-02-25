import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/budget_provider.dart';
import '../../../core/providers/category_provider.dart';
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
            itemBuilder: (context, i) =>
                _BudgetTile(budget: budgets[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetSheet(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBudgetSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddBudgetSheet(),
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

    return Card(
      child: ListTile(
        title: Text(budget.name),
        subtitle: Text(
            '$label · ${CurrencyFormatter.format(budget.limitAmount, 'ZAR')} / month'),
        trailing: IconButton(
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
      ),
    );
  }
}

class _AddBudgetSheet extends ConsumerStatefulWidget {
  const _AddBudgetSheet();

  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  String? _selectedCategoryId; // null = overall
  double _alertAt = 0.8;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final budget = BudgetModel(
      budgetId: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      limitAmount: double.parse(_limitCtrl.text),
      period: 'monthly',
      categoryId: _selectedCategoryId,
      alertAt: _alertAt,
      createdAt: DateTime.now(),
    );
    await ref.read(budgetNotifierProvider.notifier).addBudget(budget);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final notifierState = ref.watch(budgetNotifierProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add Budget',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
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
                  labelText: 'Monthly limit (ZAR)',
                  prefixText: 'R '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: Validators.amount,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Overall (all spending)')),
                ...categories.map((c) => DropdownMenuItem(
                    value: c.categoryId,
                    child: Text('${c.icon} ${c.name}'))),
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
              label: 'Save Budget',
              onPressed: notifierState.isLoading ? null : _save,
              isLoading: notifierState.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
