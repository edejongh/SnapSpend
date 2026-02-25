import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final userModel = userAsync.asData?.value;

    return AppScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/profile'),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Budgets'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/budget'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Default Currency'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  userModel?.defaultCurrency ?? AppConstants.defaultCurrency,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: userModel == null
                ? null
                : () => _showCurrencyPicker(context, ref, userModel),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    UserModel userModel,
  ) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Default Currency'),
        children: [
          for (final currency in AppConstants.supportedCurrencies)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, currency),
              child: Row(
                children: [
                  if (currency == userModel.defaultCurrency)
                    const Icon(Icons.check, size: 18)
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(currency),
                ],
              ),
            ),
        ],
      ),
    );

    if (selected == null || selected == userModel.defaultCurrency) return;

    await ref
        .read(firebaseServiceProvider)
        .saveUser(userModel.copyWith(defaultCurrency: selected));
    ref.invalidate(currentUserProvider);
  }
}
