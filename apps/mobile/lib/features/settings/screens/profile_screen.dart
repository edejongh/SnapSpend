import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:snapspend_core/snapspend_core.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl.text = user?.displayName ?? '';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match.')),
        );
      }
      return;
    }
    if (newCtrl.text.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
        await ref
            .read(firebaseServiceProvider)
            .saveUser(userModel.copyWith(displayName: newName));
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
        data: (userModel) => ListView(
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
          ],
        ),
      ),
    );
  }
}
