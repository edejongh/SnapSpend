import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';

final categoriesProvider = Provider<List<CategoryModel>>((ref) {
  return CategoryConstants.defaultCategories;
});

final categoryByIdProvider =
    Provider.family<CategoryModel?, String>((ref, id) {
  final categories = ref.watch(categoriesProvider);
  try {
    return categories.firstWhere((c) => c.categoryId == id);
  } catch (_) {
    return null;
  }
});
