import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'router/app_router.dart';
import 'shared/theme/app_theme.dart';
// Firebase initialisation requires firebase_options.dart — see FIREBASE_SETUP.md
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Uncomment after adding firebase_options.dart (see FIREBASE_SETUP.md):
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  // Register Hive type adapters here when generated
  runApp(const ProviderScope(child: SnapSpendApp()));
}

class SnapSpendApp extends ConsumerWidget {
  const SnapSpendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SnapSpend',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
