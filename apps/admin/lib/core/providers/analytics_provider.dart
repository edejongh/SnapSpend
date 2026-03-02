import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../services/admin_firebase_service.dart';
import 'users_provider.dart';

class DashboardKpis {
  final int totalUsers;
  final int activeSubscriptions;
  final int receiptsScannedToday;
  final int openOcrFlags;

  const DashboardKpis({
    required this.totalUsers,
    required this.activeSubscriptions,
    required this.receiptsScannedToday,
    required this.openOcrFlags,
  });
}

final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) async {
  final service = ref.watch(adminFirebaseServiceProvider);
  return service.getDashboardKpis();
});

/// Monthly signup counts derived from the loaded users list.
/// Returns a list of (month label, count) for the last 6 months.
final monthlySignupsProvider =
    Provider<List<(String, int)>>((ref) {
  final usersAsync = ref.watch(usersProvider);
  final users = usersAsync.asData?.value ?? <UserModel>[];

  final now = DateTime.now();
  final months = List.generate(6, (i) {
    final d = DateTime(now.year, now.month - (5 - i));
    return d;
  });

  return months.map((m) {
    final count = users
        .where((u) =>
            u.createdAt.year == m.year && u.createdAt.month == m.month)
        .length;
    const abbr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return ('${abbr[m.month - 1]} ${m.year.toString().substring(2)}', count);
  }).toList();
});
