import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/users_provider.dart';
import '../../../shared/widgets/admin_sidebar.dart';
import '../../../shared/widgets/stat_chip.dart';

class UserDetailScreen extends ConsumerWidget {
  final String uid;

  const UserDetailScreen({super.key, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userDetailProvider(uid));
    final txnsAsync = ref.watch(userTransactionsProvider(uid));

    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/users'),
                  ),
                  title: const Text('User Detail'),
                ),
                Expanded(
                  child: userAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (user) => user == null
                        ? const Center(child: Text('User not found'))
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _ProfileHeader(user: user, ref: ref),
                                const SizedBox(height: 24),
                                txnsAsync.when(
                                  loading: () => const Center(
                                      child: CircularProgressIndicator()),
                                  error: (e, _) =>
                                      Text('Error loading transactions: $e'),
                                  data: (txns) => Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _StatsRow(txns: txns),
                                      const SizedBox(height: 24),
                                      _RecentTransactions(txns: txns),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserModel user;
  final WidgetRef ref;
  const _ProfileHeader({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final initials = user.displayName != null && user.displayName!.isNotEmpty
        ? user.displayName!
            .split(' ')
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : user.email[0].toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 36,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(initials,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 20),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.displayName ?? user.email,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 10),
                      _PlanDropdown(user: user, ref: ref),
                    ],
                  ),
                  if (user.displayName != null) ...[
                    const SizedBox(height: 2),
                    Text(user.email,
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label:
                            'Joined ${DateFormatter.formatShort(user.createdAt)}',
                      ),
                      _InfoChip(
                        icon: Icons.access_time_outlined,
                        label:
                            'Active ${DateFormatter.formatRelative(user.lastActiveAt)}',
                      ),
                      _InfoChip(
                        icon: Icons.currency_exchange,
                        label: user.defaultCurrency,
                      ),
                      if (!user.onboardingComplete)
                        _InfoChip(
                          icon: Icons.warning_amber_outlined,
                          label: 'Onboarding incomplete',
                          color: Colors.orange,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDropdown extends StatefulWidget {
  final UserModel user;
  final WidgetRef ref;
  const _PlanDropdown({required this.user, required this.ref});

  @override
  State<_PlanDropdown> createState() => _PlanDropdownState();
}

class _PlanDropdownState extends State<_PlanDropdown> {
  bool _saving = false;

  Color _planColor(String plan) => switch (plan) {
        'pro' => Colors.blue,
        'business' => Colors.purple,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    if (_saving) {
      return const SizedBox(
          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return PopupMenuButton<String>(
      tooltip: 'Change plan',
      child: StatChip(
        label: widget.user.plan.toUpperCase(),
        color: _planColor(widget.user.plan),
        trailing: const Icon(Icons.arrow_drop_down, size: 14),
      ),
      itemBuilder: (_) => [
        for (final plan in ['free', 'pro', 'business'])
          PopupMenuItem(
            value: plan,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _planColor(plan),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(plan[0].toUpperCase() + plan.substring(1)),
                if (plan == widget.user.plan) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.check, size: 14),
                ],
              ],
            ),
          ),
      ],
      onSelected: (plan) async {
        if (plan == widget.user.plan) return;
        setState(() => _saving = true);
        try {
          await widget.ref.read(adminFirebaseServiceProvider).updateUserPlan(widget.user.uid, plan);
          widget.ref.invalidate(userDetailProvider(widget.user.uid));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Plan updated to ${plan[0].toUpperCase()}${plan.substring(1)}'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<TransactionModel> txns;
  const _StatsRow({required this.txns});

  @override
  Widget build(BuildContext context) {
    final totalSpend =
        txns.fold(0.0, (sum, t) => sum + t.amountZAR);
    final taxTotal = txns
        .where((t) => t.isTaxDeductible)
        .fold(0.0, (sum, t) => sum + t.amountZAR);
    final ocrCount = txns.where((t) => t.source == 'ocr').length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Transactions',
            value: txns.length.toString(),
            icon: Icons.receipt_long_outlined,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Total Spend',
            value: CurrencyFormatter.format(totalSpend, 'ZAR'),
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Tax Deductible',
            value: CurrencyFormatter.format(taxTotal, 'ZAR'),
            icon: Icons.receipt_outlined,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'OCR Scans',
            value: ocrCount.toString(),
            icon: Icons.document_scanner_outlined,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<TransactionModel> txns;
  const _RecentTransactions({required this.txns});

  @override
  Widget build(BuildContext context) {
    if (txns.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No transactions yet')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Showing ${txns.length > 50 ? '50' : txns.length} of ${txns.length}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...txns.take(50).map((t) => _TransactionRow(txn: t)),
          ],
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final TransactionModel txn;
  const _TransactionRow({required this.txn});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Source indicator
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: txn.source == 'ocr'
                    ? Colors.orange.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                txn.source == 'ocr'
                    ? Icons.document_scanner_outlined
                    : Icons.edit_outlined,
                size: 14,
                color: txn.source == 'ocr' ? Colors.orange : Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.vendor,
                      style:
                          const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${txn.category} · ${DateFormatter.formatDate(txn.date)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.format(txn.amountZAR, 'ZAR'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (txn.isTaxDeductible)
                  Text(
                    'Tax deductible',
                    style: TextStyle(
                        fontSize: 11, color: Colors.green.shade600),
                  ),
              ],
            ),
            if (txn.flaggedForReview) ...[
              const SizedBox(width: 8),
              const Tooltip(
                message: 'Flagged for review',
                child: Icon(Icons.flag, size: 14, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}
