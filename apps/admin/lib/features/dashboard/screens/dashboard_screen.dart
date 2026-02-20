import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/analytics_provider.dart';
import '../../../core/providers/flags_provider.dart';
import '../../../shared/widgets/admin_sidebar.dart';
import '../widgets/kpi_card.dart';
import '../widgets/revenue_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKpisProvider);
    final flagsAsync = ref.watch(openFlagsProvider);

    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Dashboard'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // KPI cards row
                        kpisAsync.when(
                          loading: () => const Row(
                            children: [
                              Expanded(child: LinearProgressIndicator()),
                            ],
                          ),
                          error: (e, _) => Text('Error: $e'),
                          data: (kpis) => Row(
                            children: [
                              Expanded(
                                child: KpiCard(
                                  label: 'Total Users',
                                  value: kpis.totalUsers.toString(),
                                  icon: Icons.people,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: KpiCard(
                                  label: 'Active Subscriptions',
                                  value:
                                      kpis.activeSubscriptions.toString(),
                                  icon: Icons.subscriptions,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: KpiCard(
                                  label: 'Receipts Scanned Today',
                                  value:
                                      kpis.receiptsScannedToday.toString(),
                                  icon: Icons.document_scanner,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: KpiCard(
                                  label: 'OCR Flags Open',
                                  value: kpis.openOcrFlags.toString(),
                                  icon: Icons.flag,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const RevenueChart(),
                        const SizedBox(height: 24),
                        // Recent flags mini-list
                        Text(
                          'Recent Flags',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        flagsAsync.when(
                          loading: () =>
                              const CircularProgressIndicator(),
                          error: (e, _) => Text('Error: $e'),
                          data: (flags) {
                            if (flags.isEmpty) {
                              return const Text('No open flags');
                            }
                            return Column(
                              children: flags.take(5).map((flag) {
                                return ListTile(
                                  leading: const Icon(
                                    Icons.flag,
                                    color: Colors.red,
                                  ),
                                  title: Text(flag.vendor),
                                  subtitle: Text(
                                    'Confidence: ${((flag.ocrConfidence ?? 0) * 100).toStringAsFixed(0)}%',
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
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
