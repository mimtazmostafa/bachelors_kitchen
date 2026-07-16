 import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/favorites_provider.dart';
import 'providers/language_provider.dart';
import 'providers/meal_planner_provider.dart';
import 'providers/subscription_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load .env before runApp so services that read keys at startup see them.
  // Safe to call even if .env is missing (the file is gitignored by default).
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // No .env present — services will fall back to --dart-define or fail
    // gracefully. We intentionally swallow so the app still launches.
  }
  runApp(const BachelorsKitchenApp());
}

class BachelorsKitchenApp extends StatelessWidget {
  const BachelorsKitchenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(
          create: (_) => MealPlannerProvider()..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => SubscriptionProvider()..load(),
        ),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, lang, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: "Bachelor's Kitchen",
            theme: AppTheme.light(),
            locale: lang.isBn ? const Locale("bn", "BD") : const Locale("en"),
            supportedLocales: const [
              Locale("en"),
              Locale("bn"),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
