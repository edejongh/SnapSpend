import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'auth_provider.dart';
import 'hive_provider.dart';
import 'sync_provider.dart';

/// User's custom categories — fetched from Firestore with Hive fallback.
final userCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final uid = ref.watch(authStateProvider).asData?.value?.uid;
  if (uid == null) return [];

  final hive = ref.read(hiveServiceProvider);
  final firebase = ref.read(firebaseServiceProvider);

  try {
    final categories = await firebase.getUserCategories(uid);
    for (final cat in categories) {
      await hive.saveUserCategory(cat);
    }
    return categories;
  } catch (_) {
    return hive.getUserCategories();
  }
});

/// All categories: defaults first, then user custom categories.
final categoriesProvider = Provider<List<CategoryModel>>((ref) {
  final userCats = ref.watch(userCategoriesProvider).asData?.value ?? [];
  return [...CategoryConstants.defaultCategories, ...userCats];
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

/// CRUD for user's custom categories.
class CategoryNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> saveCategory(CategoryModel category) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref.read(hiveServiceProvider).saveUserCategory(category);
    try {
      await ref.read(firebaseServiceProvider).saveUserCategory(uid, category);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'saveUserCategory',
        'data': category.toMap(),
      });
    }
    ref.invalidate(userCategoriesProvider);
  }

  Future<void> deleteCategory(String categoryId) async {
    final uid = ref.read(authStateProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref.read(hiveServiceProvider).deleteUserCategory(categoryId);
    try {
      await ref
          .read(firebaseServiceProvider)
          .deleteUserCategory(uid, categoryId);
    } catch (_) {
      await ref.read(syncServiceProvider).enqueuePendingOperation({
        'type': 'deleteUserCategory',
        'id': categoryId,
      });
    }
    ref.invalidate(userCategoriesProvider);
  }
}

final categoryNotifierProvider =
    AsyncNotifierProvider<CategoryNotifier, void>(CategoryNotifier.new);
