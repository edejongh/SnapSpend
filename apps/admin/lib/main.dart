import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router/admin_router.dart';
import 'shared/theme/admin_theme.dart';
// Firebase initialisation requires firebase_options.dart — see FIREBASE_SETUP.md
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uncomment after adding firebase_options.dart (see FIREBASE_SETUP.md):
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: SnapSpendAdminApp()));
}

class SnapSpendAdminApp extends ConsumerWidget {
  const SnapSpendAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(adminRouterProvider);
    return MaterialApp.router(
      title: 'SnapSpend Admin',
      theme: AdminTheme.theme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
