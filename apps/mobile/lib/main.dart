import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/hive_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/firebase_service_impl.dart';
import 'core/services/hive_service.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'shared/theme/app_theme.dart';

final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Route Flutter and platform errors to Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Analytics collection
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(!kDebugMode);

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  await Hive.initFlutter();
  final hiveService = HiveService();
  await hiveService.init();

  final firebaseServiceImpl = FirebaseServiceImpl();

  // Keep FCM token fresh when it rotates
  FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      firebaseServiceImpl.saveFcmToken(uid, token);
    }
  });

  // Show foreground FCM messages as an in-app banner
  FirebaseMessaging.onMessage.listen((message) {
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title;
    final body = notification.body;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            if (body != null) Text(body),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  });

  final container = ProviderContainer(
    overrides: [
      firebaseServiceProvider.overrideWithValue(firebaseServiceImpl),
      hiveServiceProvider.overrideWithValue(hiveService),
    ],
  );
  await container.read(themeModeProvider.notifier).load();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const SnapSpendApp(),
    ),
  );
}

class SnapSpendApp extends ConsumerWidget {
  const SnapSpendApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'SnapSpend',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
