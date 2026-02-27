import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/hive_provider.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/app_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final userModel = userAsync.asData?.value;
    final themeMode = ref.watch(themeModeProvider);

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
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/categories'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/notifications'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Appearance'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(
                    value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(
                    value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeModeProvider.notifier).setMode(mode);
                }
              },
            ),
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
          _SyncTile(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              'Delete Account',
              style:
                  TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Step 1: confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all your data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    // Step 2: re-authentication
    final hasPassword =
        user.providerData.any((p) => p.providerId == 'password');

    try {
      if (hasPassword) {
        final passwordCtrl = TextEditingController();
        final password = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirm Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Enter your password to confirm account deletion.'),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, passwordCtrl.text),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('Delete my account'),
              ),
            ],
          ),
        );
        if (password == null || password.isEmpty) return;
        if (!context.mounted) return;

        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(cred);
      } else {
        // Google re-auth
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return;
        final googleAuth = await googleUser.authentication;
        final cred = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await user.reauthenticateWithCredential(cred);
      }

      // Step 3: delete Firestore data
      await ref
          .read(firebaseServiceProvider)
          .deleteUserData(user.uid);

      // Step 4: clear local Hive cache
      await ref.read(hiveServiceProvider).clearAll();

      // Step 5: delete Firebase Auth account (triggers auth state change → redirect to /login)
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(e.message ?? 'Failed to delete account.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Failed to delete account. Please try again.')),
      );
    }
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

class _SyncTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus =
        ref.watch(syncStatusProvider).asData?.value ?? SyncStatus.idle;
    final uid = ref.watch(authStateProvider).asData?.value?.uid;
    final isSyncing = syncStatus == SyncStatus.syncing;

    String subtitle;
    switch (syncStatus) {
      case SyncStatus.syncing:
        subtitle = 'Syncing…';
      case SyncStatus.error:
        subtitle = 'Last sync failed — tap to retry';
      case SyncStatus.idle:
      default:
        subtitle = 'All changes saved';
    }

    return ListTile(
      leading: isSyncing
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              syncStatus == SyncStatus.error
                  ? Icons.sync_problem_outlined
                  : Icons.cloud_done_outlined,
              color: syncStatus == SyncStatus.error ? Colors.red : null,
            ),
      title: const Text('Sync'),
      subtitle: Text(subtitle),
      onTap: isSyncing || uid == null
          ? null
          : () async {
              final sync = ref.read(syncServiceProvider);
              await sync.syncPendingTransactions(uid);
              ref.invalidate(transactionsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync complete')),
                );
              }
            },
    );
  }
}
