import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../core/providers/budget_provider.dart';
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
          _NotificationBell(),
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

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(budgetAlertsProvider);
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (alerts.isNotEmpty)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      onPressed: () => _showAlerts(context, alerts),
    );
  }

  void _showAlerts(
      BuildContext context, List<(BudgetModel, double)> alerts) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (_) => _AlertsSheet(alerts: alerts),
    );
  }
}

class _AlertsSheet extends StatelessWidget {
  final List<(BudgetModel, double)> alerts;
  const _AlertsSheet({required this.alerts});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            'Budget Alerts',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'All budgets are on track',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (final (budget, pct) in alerts) ...[
              _AlertRow(budget: budget, utilisation: pct),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final BudgetModel budget;
  final double utilisation;
  const _AlertRow({required this.budget, required this.utilisation});

  @override
  Widget build(BuildContext context) {
    final isOver = utilisation >= 1.0;
    final pctText = '${(utilisation * 100).toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOver ? Colors.red.shade50 : Colors.amber.shade50,
        border: Border.all(
            color: isOver ? Colors.red.shade300 : Colors.amber.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isOver ? Icons.cancel_outlined : Icons.warning_amber,
            color: isOver ? Colors.red.shade700 : Colors.amber.shade700,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isOver
                  ? '${budget.name} is over budget ($pctText)'
                  : '${budget.name} is at $pctText of limit',
              style: TextStyle(
                color: isOver ? Colors.red.shade900 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
