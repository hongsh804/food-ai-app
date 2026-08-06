import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/app_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/backend_settings.dart';
import 'services/meal_history_store.dart';
import 'widgets/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackendSettings.instance.initialize();
  await MealHistoryStore.instance.load();
  final preferences = await SharedPreferences.getInstance();
  final hasSeenOnboarding =
      preferences.getBool('has_seen_onboarding_v2') ?? false;
  runApp(FoodAiApp(showOnboarding: !hasSeenOnboarding));
}

class FoodAiApp extends StatefulWidget {
  const FoodAiApp({super.key, required this.showOnboarding});

  final bool showOnboarding;

  @override
  State<FoodAiApp> createState() => _FoodAiAppState();
}

class _FoodAiAppState extends State<FoodAiApp> {
  late bool _showOnboarding = widget.showOnboarding;

  Future<void> _finishOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('has_seen_onboarding_v2', true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GlucoLog',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic'],
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: AppColors.ink,
          displayColor: AppColors.ink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
        dividerColor: AppColors.border,
      ),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        child: _showOnboarding
            ? OnboardingScreen(
                key: const ValueKey('onboarding'),
                onStart: _finishOnboarding,
              )
            : const AppShell(key: ValueKey('shell')),
      ),
    );
  }
}
