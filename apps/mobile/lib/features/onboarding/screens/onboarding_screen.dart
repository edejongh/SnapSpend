import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snapspend_core/snapspend_core.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 1 — name
  final _nameCtrl = TextEditingController();
  final _nameKey = GlobalKey<FormState>();

  // Step 2 — currency
  String _currency = AppConstants.defaultCurrency;

  // Step 3 — budget
  final _budgetCtrl = TextEditingController();
  bool _skipBudget = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName?.isNotEmpty == true) {
      _nameCtrl.text = user!.displayName!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage == 1) {
      if (!_nameKey.currentState!.validate()) return;
    }
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _complete() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final name = _nameCtrl.text.trim();

      // Update Firebase Auth display name
      await user.updateDisplayName(name);

      // Load existing UserModel and update it
      final userModel = await ref.read(currentUserProvider.future);
      final now = DateTime.now();

      final updatedUser = (userModel ?? UserModel(
        uid: user.uid,
        email: user.email ?? '',
        plan: 'free',
        defaultCurrency: _currency,
        createdAt: now,
        lastActiveAt: now,
        onboardingComplete: false,
      )).copyWith(
        displayName: name,
        defaultCurrency: _currency,
        lastActiveAt: now,
        onboardingComplete: true,
      );

      await ref.read(firebaseServiceProvider).saveUser(updatedUser);

      // Create initial budget if provided
      if (!_skipBudget && _budgetCtrl.text.trim().isNotEmpty) {
        final limit = double.tryParse(_budgetCtrl.text.trim());
        if (limit != null && limit > 0) {
          final budget = BudgetModel(
            budgetId: const Uuid().v4(),
            name: 'Monthly Budget',
            limitAmount: limit,
            period: 'monthly',
            alertAt: 0.8,
            createdAt: now,
          );
          await ref
              .read(firebaseServiceProvider)
              .saveBudget(user.uid, budget);
        }
      }

      // Invalidate so the router re-evaluates onboardingComplete
      ref.invalidate(currentUserProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final active = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _next),
                  _NamePage(
                    formKey: _nameKey,
                    controller: _nameCtrl,
                    onNext: _next,
                  ),
                  _CurrencyPage(
                    selected: _currency,
                    onChanged: (c) => setState(() => _currency = c),
                    onNext: _next,
                  ),
                  _BudgetPage(
                    controller: _budgetCtrl,
                    currency: _currency,
                    skip: _skipBudget,
                    onSkipChanged: (v) => setState(() => _skipBudget = v),
                    onComplete: _complete,
                    isSaving: _isSaving,
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

// ── Pages ────────────────────────────────────────────────────────────────────

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      emoji: '📸',
      title: 'Welcome to SnapSpend',
      subtitle:
          'Snap a receipt, and we\'ll handle the rest.\nTrack spending, set budgets, and stay on top of your finances.',
      action: PrimaryButton(label: 'Get started', onPressed: onNext),
    );
  }
}

class _NamePage extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final VoidCallback onNext;

  const _NamePage({
    required this.formKey,
    required this.controller,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      emoji: '👋',
      title: 'What should we call you?',
      subtitle: 'This is how you\'ll appear in the app.',
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'e.g. Alex',
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          validator: (v) => Validators.required(v, fieldName: 'Display name'),
        ),
      ),
      action: PrimaryButton(label: 'Continue', onPressed: onNext),
    );
  }
}

class _CurrencyPage extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  const _CurrencyPage({
    required this.selected,
    required this.onChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return _OnboardingPage(
      emoji: '💱',
      title: 'Your home currency',
      subtitle: 'All amounts will be shown in this currency.',
      content: DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(labelText: 'Currency'),
        items: AppConstants.supportedCurrencies
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => onChanged(v ?? AppConstants.defaultCurrency),
      ),
      action: PrimaryButton(label: 'Continue', onPressed: onNext),
    );
  }
}

class _BudgetPage extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final bool skip;
  final ValueChanged<bool> onSkipChanged;
  final VoidCallback onComplete;
  final bool isSaving;

  const _BudgetPage({
    required this.controller,
    required this.currency,
    required this.skip,
    required this.onSkipChanged,
    required this.onComplete,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = _symbol(currency);
    return _OnboardingPage(
      emoji: '🎯',
      title: 'Set a monthly budget',
      subtitle: 'We\'ll alert you when you\'re getting close. You can always change this later.',
      content: Column(
        children: [
          TextFormField(
            controller: controller,
            enabled: !skip,
            decoration: InputDecoration(
              labelText: 'Monthly limit',
              prefixText: '$symbol ',
            ),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: skip,
                onChanged: (v) => onSkipChanged(v ?? false),
              ),
              const Text('Skip for now'),
            ],
          ),
        ],
      ),
      action: PrimaryButton(
        label: "Let's go!",
        onPressed: isSaving ? null : onComplete,
        isLoading: isSaving,
      ),
    );
  }

  String _symbol(String code) {
    const map = {
      'ZAR': 'R', 'USD': '\$', 'EUR': '€', 'GBP': '£',
      'KES': 'KSh', 'NGN': '₦', 'BWP': 'P',
    };
    return map[code] ?? code;
  }
}

// ── Shared page layout ───────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget? content;
  final Widget action;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.content,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Center(
            child: Text(emoji, style: const TextStyle(fontSize: 72)),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey.shade600, height: 1.5),
          ),
          if (content != null) ...[
            const SizedBox(height: 32),
            content!,
          ],
          const Spacer(),
          action,
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
