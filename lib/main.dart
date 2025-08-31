import 'package:flutter/material.dart';
import 'package:wasel/pages/customer_home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_page.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AuthProvider
  final authProvider = AuthProvider();
  await authProvider.initialize(); // ✅ loads token & user

  // Onboarding check
  final prefs = await SharedPreferences.getInstance();
  final hasOnboarded = prefs.getBool('hasOnboarded') ?? false;

  // Decide first screen
  Widget firstScreen;
  if (!hasOnboarded) {
    firstScreen = OnboardingScreen();
  } else if (authProvider.isAuthenticated) { // ✅ use AuthProvider
    firstScreen = CustomerHomePage();
  } else {
    firstScreen = LoginScreen();
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => authProvider,
      child: MaterialApp(
        title: 'Wasel',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: Color(0xFF0D47A1),
          colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF0D47A1)),
          useMaterial3: true,
        ),
        home: SplashScreen(nextScreen: firstScreen),
        routes: {
          '/onboarding': (context) => OnboardingScreen(),
          '/home': (context) => CustomerHomePage(),
          '/login': (context) => LoginScreen(),
        },
      ),
    ),
  );
}
