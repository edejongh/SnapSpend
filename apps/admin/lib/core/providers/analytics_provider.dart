import 'package:flutter_riverpod/flutter_riverpod.dart';
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
