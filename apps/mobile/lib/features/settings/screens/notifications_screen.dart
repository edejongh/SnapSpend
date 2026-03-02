import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyBudgetAlerts = 'notif_budget_alerts';
const _keyWeeklySummary = 'notif_weekly_summary';
const _keyFlaggedReminders = 'notif_flagged_reminders';

class NotificationPrefs {
  final bool budgetAlerts;
  final bool weeklySummary;
  final bool flaggedReminders;

  const NotificationPrefs({
    required this.budgetAlerts,
    required this.weeklySummary,
    required this.flaggedReminders,
  });

  NotificationPrefs copyWith({
    bool? budgetAlerts,
    bool? weeklySummary,
    bool? flaggedReminders,
  }) =>
      NotificationPrefs(
        budgetAlerts: budgetAlerts ?? this.budgetAlerts,
        weeklySummary: weeklySummary ?? this.weeklySummary,
        flaggedReminders: flaggedReminders ?? this.flaggedReminders,
      );
}

final notificationPrefsProvider =
    AsyncNotifierProvider<_NotifPrefsNotifier, NotificationPrefs>(
        _NotifPrefsNotifier.new);

class _NotifPrefsNotifier extends AsyncNotifier<NotificationPrefs> {
  @override
  Future<NotificationPrefs> build() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPrefs(
      budgetAlerts: prefs.getBool(_keyBudgetAlerts) ?? true,
      weeklySummary: prefs.getBool(_keyWeeklySummary) ?? false,
      flaggedReminders: prefs.getBool(_keyFlaggedReminders) ?? true,
    );
  }

  Future<void> toggle(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    final current = state.asData?.value;
    if (current == null) return;
    switch (key) {
      case _keyBudgetAlerts:
        state = AsyncData(current.copyWith(budgetAlerts: value));
      case _keyWeeklySummary:
        state = AsyncData(current.copyWith(weeklySummary: value));
      case _keyFlaggedReminders:
        state = AsyncData(current.copyWith(flaggedReminders: value));
    }
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(notificationPrefsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (prefs) => ListView(
          children: [
            const _SectionHeader(label: 'Alerts'),
            SwitchListTile(
              secondary: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Budget alerts'),
              subtitle: const Text('Notify when spending nears your budget limit'),
              value: prefs.budgetAlerts,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .toggle(_keyBudgetAlerts, v),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.rate_review_outlined),
              title: const Text('Flagged receipt reminders'),
              subtitle: const Text('Remind you to review low-confidence scans'),
              value: prefs.flaggedReminders,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .toggle(_keyFlaggedReminders, v),
            ),
            const Divider(),
            const _SectionHeader(label: 'Reports'),
            SwitchListTile(
              secondary: const Icon(Icons.bar_chart_outlined),
              title: const Text('Weekly spending summary'),
              subtitle: const Text('Receive a weekly overview every Monday'),
              value: prefs.weeklySummary,
              onChanged: (v) => ref
                  .read(notificationPrefsProvider.notifier)
                  .toggle(_keyWeeklySummary, v),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Notifications are managed by your device. '
                'Make sure SnapSpend has notification permission in System Settings.',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}
