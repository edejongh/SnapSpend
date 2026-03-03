import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../transactions/widgets/transaction_detail_sheet.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  late String _selectedCurrency;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
    // Will be overwritten once currentUserProvider resolves
    _selectedCurrency = AppConstants.defaultCurrency;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool _hasPasswordProvider(User? user) {
    return user?.providerData
            .any((p) => p.providerId == 'password') ??
        false;
  }

  Future<void> _changePassword(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              decoration:
                  const InputDecoration(labelText: 'Current password'),
              obscureText: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              decoration: const InputDecoration(labelText: 'New password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration:
                  const InputDecoration(labelText: 'Confirm new password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Update')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (newCtrl.text != confirmCtrl.text) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
      }
      return;
    }
    if (newCtrl.text.length < 6) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
              content: Text('Password must be at least 6 characters.')),
        );
      }
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newCtrl.text);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
              content: Text(e.message ?? 'Failed to update password.')),
        );
      }
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (file == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref = FirebaseStorage.instance
          .ref()
          .child('avatars/${user.uid}.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();

      await user.updatePhotoURL(url);

      final userModel = await this.ref.read(currentUserProvider.future);
      if (userModel != null) {
        await this.ref
            .read(firebaseServiceProvider)
            .saveUser(userModel.copyWith(photoURL: url));
        this.ref.invalidate(currentUserProvider);
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final newName = _nameCtrl.text.trim();

      // Update Firebase Auth profile
      await user.updateDisplayName(newName);

      // Update Firestore UserModel
      final userModel = await ref.read(currentUserProvider.future);
      if (userModel != null) {
        final updated = userModel.copyWith(
          displayName: newName,
          defaultCurrency: _selectedCurrency,
        );
        await ref.read(firebaseServiceProvider).saveUser(updated);
        ref.invalidate(currentUserProvider);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to update profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final initial = (firebaseUser?.displayName?.isNotEmpty == true
            ? firebaseUser!.displayName![0]
            : firebaseUser?.email?[0] ?? '?')
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (userModel) {
          // Sync currency once model loads (only overwrite if still default)
          if (userModel != null &&
              _selectedCurrency == AppConstants.defaultCurrency) {
            _selectedCurrency = userModel.defaultCurrency;
          }
          return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    backgroundImage: firebaseUser?.photoURL != null
                        ? NetworkImage(firebaseUser!.photoURL!)
                        : null,
                    child: firebaseUser?.photoURL == null
                        ? Text(
                            initial,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                          )
                        : null,
                  ),
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: _isUploadingPhoto
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: firebaseUser?.email ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    readOnly: true,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        Validators.required(v, fieldName: 'Display name'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Default currency',
                      prefixIcon: Icon(Icons.currency_exchange_outlined),
                    ),
                    items: AppConstants.supportedCurrencies
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (c) {
                      if (c != null) setState(() => _selectedCurrency = c);
                    },
                  ),
                  if (userModel != null) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue:
                          DateFormatter.formatDate(userModel.createdAt),
                      decoration: const InputDecoration(
                        labelText: 'Member since',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      readOnly: true,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Save Changes',
                    onPressed: _isSaving ? null : _save,
                    isLoading: _isSaving,
                  ),
                  // Show password change only for email/password accounts
                  if (_hasPasswordProvider(firebaseUser)) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: const Text('Change Password'),
                      onPressed: () => _changePassword(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _LifetimeStatsSection(),
          ],
        );
        },
      ),
    );
  }
}

class _LifetimeStatsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(transactionsProvider).asData?.value ?? [];
    if (txns.isEmpty) return const SizedBox.shrink();

    final streak = ref.watch(spendingStreakProvider);
    final total = txns.fold(0.0, (s, t) => s + t.amountZAR);

    // Average monthly spend (across distinct months that have data)
    final distinctMonths = txns
        .map((t) => '${t.date.year}-${t.date.month}')
        .toSet();
    final avgMonthly = distinctMonths.isEmpty
        ? 0.0
        : total / distinctMonths.length;

    // Year-to-date total
    final thisYear = DateTime.now().year;
    final ytdTotal = txns
        .where((t) => t.date.year == thisYear)
        .fold(0.0, (s, t) => s + t.amountZAR);

    // Tax deductible total this calendar year
    final taxTotal = txns
        .where((t) => t.isTaxDeductible && t.date.year == thisYear)
        .fold(0.0, (s, t) => s + t.amountZAR);

    // Most active month
    final monthCounts = <String, int>{};
    for (final t in txns) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      monthCounts[key] = (monthCounts[key] ?? 0) + 1;
    }
    final topMonth = monthCounts.isEmpty
        ? null
        : monthCounts.entries
            .reduce((a, b) => a.value >= b.value ? a : b);

    String? topMonthLabel;
    if (topMonth != null) {
      final parts = topMonth.key.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      topMonthLabel = '${months[dt.month - 1]} ${dt.year}';
    }

    // Most expensive transaction ever
    final biggest = txns.isEmpty
        ? null
        : txns.reduce((a, b) => a.amountZAR >= b.amountZAR ? a : b);

    // Unique vendors
    final uniqueVendors = txns.map((t) => t.vendor).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Stats',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _StatRow(
          icon: Icons.receipt_long_outlined,
          label: 'Total transactions',
          value: '${txns.length}',
        ),
        if (ytdTotal > 0)
          _StatRow(
            icon: Icons.calendar_today_outlined,
            label: '$thisYear so far',
            value: CurrencyFormatter.format(ytdTotal, 'ZAR'),
          ),
        _StatRow(
          icon: Icons.attach_money_outlined,
          label: 'Total tracked',
          value: CurrencyFormatter.format(total, 'ZAR'),
        ),
        if (streak > 0)
          _StatRow(
            icon: Icons.local_fire_department_outlined,
            label: 'Current streak',
            value: '$streak day${streak == 1 ? '' : 's'} 🔥',
          ),
        if (distinctMonths.length >= 2)
          _StatRow(
            icon: Icons.trending_flat_outlined,
            label: 'Avg per month',
            value: CurrencyFormatter.format(avgMonthly, 'ZAR'),
          ),
        if (uniqueVendors > 0)
          _StatRow(
            icon: Icons.store_outlined,
            label: 'Unique vendors',
            value: '$uniqueVendors',
          ),
        if (biggest != null)
          _StatRow(
            icon: Icons.arrow_upward_outlined,
            label: 'Biggest purchase',
            value: '${biggest.vendor} · ${CurrencyFormatter.format(biggest.amountZAR, 'ZAR')}',
            onTap: () => showTransactionDetail(context, biggest),
          ),
        if (topMonthLabel != null)
          _StatRow(
            icon: Icons.calendar_month_outlined,
            label: 'Most active month',
            value: '$topMonthLabel (${topMonth!.value} txns)',
          ),
        if (taxTotal > 0)
          _StatRow(
            icon: Icons.receipt_long_outlined,
            label: 'Tax deductible $thisYear',
            value: CurrencyFormatter.format(taxTotal, 'ZAR'),
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  const _StatRow(
      {required this.icon, required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
          ],
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}
