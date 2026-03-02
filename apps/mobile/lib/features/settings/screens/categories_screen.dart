import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/category_provider.dart';
import '../../../core/providers/transaction_provider.dart';

// Predefined colour palette for custom categories
const _palette = [
  '#E57373', '#F06292', '#BA68C8', '#7986CB',
  '#4FC3F7', '#4DB6AC', '#81C784', '#FFD54F',
  '#FF8A65', '#A1887F', '#90A4AE', '#78909C',
];

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userCatsAsync = ref.watch(userCategoriesProvider);
    final spendByCategory = ref.watch(spendByCategoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategorySheet(context, ref, null),
        tooltip: 'Add category',
        child: const Icon(Icons.add),
      ),
      body: userCatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (userCats) => ListView(
          children: [
            _SectionHeader(label: 'Default categories'),
            for (final cat in CategoryConstants.defaultCategories)
              _CategoryTile(
                category: cat,
                isDefault: true,
                onEdit: null,
                onDelete: null,
                spend: spendByCategory[cat.categoryId],
                onTap: spendByCategory.containsKey(cat.categoryId)
                    ? () => context.push('/transactions',
                        extra: cat.categoryId)
                    : null,
              ),
            const Divider(),
            _SectionHeader(label: 'My categories'),
            if (userCats.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No custom categories yet — tap + to add one',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              for (final cat in userCats)
                _CategoryTile(
                  category: cat,
                  isDefault: false,
                  onEdit: () => _showCategorySheet(context, ref, cat),
                  onDelete: () => _confirmDelete(context, ref, cat),
                  spend: spendByCategory[cat.categoryId],
                  onTap: spendByCategory.containsKey(cat.categoryId)
                      ? () => context.push('/transactions',
                          extra: cat.categoryId)
                      : null,
                ),
            // Bottom padding for FAB
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategorySheet(
    BuildContext context,
    WidgetRef ref,
    CategoryModel? existing,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategorySheet(existing: existing),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoryModel cat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
            'Remove "${cat.name}"? Existing transactions using this category '
            'will still reference it by ID.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(categoryNotifierProvider.notifier)
          .deleteCategory(cat.categoryId);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryModel category;
  final bool isDefault;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final double? spend;
  final VoidCallback? onTap;

  const _CategoryTile({
    required this.category,
    required this.isDefault,
    required this.onEdit,
    required this.onDelete,
    this.spend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSpend = spend != null && spend! > 0;
    final hasTax = category.taxDeductibleByDefault;

    Widget? subtitle;
    if (hasSpend || hasTax) {
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasTax)
            const Text(
              'Tax deductible by default',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          if (hasSpend)
            Text(
              '${CurrencyFormatter.format(spend!, 'ZAR')} this month',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
        ],
      );
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: _hexColor(category.color),
        child: Text(category.icon, style: const TextStyle(fontSize: 18)),
      ),
      title: Text(category.name),
      subtitle: subtitle,
      trailing: isDefault
          ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20,
                      color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(
          int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ── Add / Edit sheet ──────────────────────────────────────────────────────────

class _CategorySheet extends ConsumerStatefulWidget {
  final CategoryModel? existing;
  const _CategorySheet({this.existing});

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late String _selectedColor;
  late bool _taxDeductible;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cat = widget.existing;
    _nameCtrl = TextEditingController(text: cat?.name ?? '');
    _iconCtrl = TextEditingController(text: cat?.icon ?? '');
    _selectedColor = cat?.color ?? _palette.first;
    _taxDeductible = cat?.taxDeductibleByDefault ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Color get _previewColor {
    try {
      return Color(int.parse(_selectedColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final cat = CategoryModel(
      categoryId: widget.existing?.categoryId ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      icon: _iconCtrl.text.trim().isEmpty ? '📋' : _iconCtrl.text.trim(),
      color: _selectedColor,
      keywords: widget.existing?.keywords ?? [],
      isDefault: false,
      taxDeductibleByDefault: _taxDeductible,
    );
    await ref.read(categoryNotifierProvider.notifier).saveCategory(cat);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final previewIcon =
        _iconCtrl.text.trim().isEmpty ? '📋' : _iconCtrl.text.trim();
    final previewName =
        _nameCtrl.text.trim().isEmpty ? 'Preview' : _nameCtrl.text.trim();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
            Row(
              children: [
                Text(
                  isEditing ? 'Edit Category' : 'New Category',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Live preview
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _previewColor,
                      child: Text(previewIcon,
                          style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      previewName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Emoji icon field
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    controller: _iconCtrl,
                    decoration: const InputDecoration(labelText: 'Icon'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    maxLength: 2,
                    onChanged: (_) => setState(() {}),
                    buildCounter: (_, {required currentLength,
                      required isFocused, maxLength}) => null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Name'),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Colour',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hex in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(
                            int.parse(hex.replaceFirst('#', '0xFF'))),
                        shape: BoxShape.circle,
                        border: _selectedColor == hex
                            ? Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tax deductible by default'),
              value: _taxDeductible,
              onChanged: (v) => setState(() => _taxDeductible = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Add Category'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
