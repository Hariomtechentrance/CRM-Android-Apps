import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/theme_provider.dart';
import 'core/secure_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  SecureConfig.validateConfig();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Load persisted theme before building the widget tree so there is no flash.
  final prefs = await SharedPreferences.getInstance();
  final savedDark = prefs.getBool('isDarkMode') ?? false;

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith(
          (ref) => savedDark ? ThemeMode.dark : ThemeMode.light),
    ],
    child: const FlowCRMApp(),
  ));
}

class FlowCRMApp extends ConsumerWidget {
  const FlowCRMApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FlowCRM',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
