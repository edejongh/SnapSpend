import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/budget_alert_banner.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/budget_ring_chart.dart';
import '../widgets/recent_transactions_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final greeting = _greeting();
    final firebaseUser = userAsync.asData?.value;
    final rawName = firebaseUser?.displayName ??
        firebaseUser?.email?.split('@').first ??
        'there';
    final displayName =
        rawName[0].toUpperCase() + rawName.substring(1);

    return AppScaffold(
      appBar: AppBar(
        title: Text('$greeting, $displayName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Open notifications panel
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/snap'),
        child: const Icon(Icons.camera_alt),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(transactionsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              BudgetAlertBanner(),
              MonthlySummaryCard(),
              SizedBox(height: 20),
              BudgetRingChart(),
              SizedBox(height: 20),
              RecentTransactionsList(),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
