import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/users_provider.dart';
import '../../../shared/widgets/admin_sidebar.dart';

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Billing'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Refresh',
                      onPressed: () => ref.invalidate(usersProvider),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                Expanded(
                  child: usersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (users) => _BillingContent(users: users),
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

class _BillingContent extends StatefulWidget {
  final List<UserModel> users;
  const _BillingContent({required this.users});

  @override
  State<_BillingContent> createState() => _BillingContentState();
}

class _BillingContentState extends State<_BillingContent> {
  String _planFilter = 'all';
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final free =
        widget.users.where((u) => u.plan == 'free').toList();
    final pro =
        widget.users.where((u) => u.plan == 'pro').toList();
    final business =
        widget.users.where((u) => u.plan == 'business').toList();
    final total = widget.users.length;

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final recentSignups = widget.users
        .where((u) => u.createdAt.isAfter(thirtyDaysAgo))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final query = _search.toLowerCase();
    final filtered = widget.users.where((u) {
      if (_planFilter != 'all' && u.plan != _planFilter) return false;
      if (query.isEmpty) return true;
      return u.email.toLowerCase().contains(query) ||
          (u.displayName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan KPIs
          Row(
            children: [
              Expanded(
                child: _PlanKpiCard(
                  label: 'Free',
                  count: free.length,
                  total: total,
                  color: Colors.grey,
                  icon: Icons.person_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PlanKpiCard(
                  label: 'Pro',
                  count: pro.length,
                  total: total,
                  color: Colors.blue,
                  icon: Icons.star_outline,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PlanKpiCard(
                  label: 'Business',
                  count: business.length,
                  total: total,
                  color: Colors.purple,
                  icon: Icons.business_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PlanKpiCard(
                  label: 'Total',
                  count: total,
                  total: total,
                  color: Colors.teal,
                  icon: Icons.people_outline,
                  showPct: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan distribution
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan Distribution',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _PlanBar(
                            label: 'Free',
                            count: free.length,
                            total: total,
                            color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        _PlanBar(
                            label: 'Pro',
                            count: pro.length,
                            total: total,
                            color: Colors.blue),
                        const SizedBox(height: 12),
                        _PlanBar(
                            label: 'Business',
                            count: business.length,
                            total: total,
                            color: Colors.purple),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Recent signups
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Recent Sign-ups',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              'Last 30 days',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (recentSignups.isEmpty)
                          Text('None yet',
                              style:
                                  TextStyle(color: Colors.grey.shade500))
                        else
                          ...recentSignups.take(8).map(
                                (u) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 14,
                                        child: Text(
                                          u.email[0].toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              u.email,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w500),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              DateFormatter.formatRelative(
                                                  u.createdAt),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors
                                                      .grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _PlanBadge(plan: u.plan),
                                    ],
                                  ),
                                ),
                              ),
                        if (recentSignups.length > 8)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+ ${recentSignups.length - 8} more',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Users by plan table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'All Users',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 16),
                      for (final plan in ['all', 'free', 'pro', 'business'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(plan == 'all'
                                ? 'All (${widget.users.length})'
                                : '${plan[0].toUpperCase()}${plan.substring(1)} (${widget.users.where((u) => u.plan == plan).length})'),
                            selected: _planFilter == plan,
                            onSelected: (_) =>
                                setState(() => _planFilter = plan),
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: 220,
                        height: 36,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search email or name…',
                            prefixIcon: const Icon(Icons.search, size: 18),
                            suffixIcon: _search.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () => setState(() {
                                      _searchCtrl.clear();
                                      _search = '';
                                    }),
                                  )
                                : null,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 0),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (v) =>
                              setState(() => _search = v.trim()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...filtered.take(_search.isEmpty ? 20 : filtered.length).map(
                        (u) => ListTile(
                          leading: CircleAvatar(
                            child: Text(u.email[0].toUpperCase()),
                          ),
                          title: Text(u.displayName ?? u.email),
                          subtitle: u.displayName != null
                              ? Text(u.email)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PlanBadge(plan: u.plan),
                              const SizedBox(width: 8),
                              Text(
                                DateFormatter.formatShort(u.createdAt),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.open_in_new,
                                    size: 16),
                                onPressed: () =>
                                    context.go('/users/${u.uid}'),
                                tooltip: 'View user',
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (_search.isEmpty && filtered.length > 20)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16),
                      child: Text(
                        '${filtered.length - 20} more — use the Users page to see all',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanKpiCard extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;
  final bool showPct;

  const _PlanKpiCard({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
    this.showPct = true,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                if (showPct)
                  Text(
                    '$pct%',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
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

class _PlanBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _PlanBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$count (${(pct * 100).toStringAsFixed(0)}%)',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: pct,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

class _PlanBadge extends StatelessWidget {
  final String plan;
  const _PlanBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final color = plan == 'pro'
        ? Colors.blue
        : plan == 'business'
            ? Colors.purple
            : Colors.grey.shade500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        plan[0].toUpperCase() + plan.substring(1),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
