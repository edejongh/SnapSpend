import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/budget_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../widgets/budget_alert_banner.dart';
import '../widgets/budget_ring_chart.dart';
import '../widgets/monthly_summary_card.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/recurring_card.dart';
import '../widgets/spending_insights_card.dart';
import '../widgets/week_at_a_glance_card.dart';

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
              _FlaggedReceiptsBanner(),
              MonthlySummaryCard(),
              SizedBox(height: 12),
              _QuickStatsRow(),
              SizedBox(height: 12),
              WeekAtAGlanceCard(),
              SizedBox(height: 12),
              SpendingInsightsCard(),
              SizedBox(height: 12),
              RecurringCard(),
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
    final count = alerts.length;
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: count > 9
                    ? const EdgeInsets.symmetric(horizontal: 3, vertical: 1)
                    : null,
                width: count > 9 ? null : 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: count > 9 ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: count > 9
                      ? BorderRadius.circular(8)
                      : null,
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
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

// ── Flagged receipts banner ──────────────────────────────────────────────────

class _FlaggedReceiptsBanner extends ConsumerWidget {
  const _FlaggedReceiptsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = ref.watch(flaggedTransactionsProvider);
    if (flagged.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push('/transactions'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.rate_review_outlined,
                color: Colors.blue.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${flagged.length} receipt${flagged.length == 1 ? '' : 's'} '
                'need${flagged.length == 1 ? 's' : ''} review — tap to check',
                style: TextStyle(color: Colors.blue.shade800, fontSize: 13),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.blue.shade700, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Quick stats row ──────────────────────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  const _QuickStatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnCount = ref.watch(monthlyTransactionCountProvider);
    final avgDaily = ref.watch(avgDailySpendProvider);
    final todaySpend = ref.watch(todaySpendProvider);
    final streak = ref.watch(spendingStreakProvider);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.today_outlined,
                label: 'Today',
                value: CurrencyFormatter.format(todaySpend, 'ZAR'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatChip(
                icon: Icons.calendar_month_outlined,
                label: 'Daily avg',
                value: CurrencyFormatter.format(avgDaily, 'ZAR'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.receipt_outlined,
                label: 'This month',
                value: '$txnCount txn${txnCount == 1 ? '' : 's'}',
              ),
            ),
            if (streak >= 2) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Streak',
                  value: '$streak day${streak == 1 ? '' : 's'} 🔥',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatChip(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
