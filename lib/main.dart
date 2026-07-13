import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'widgets/components.dart';
import 'widgets/drift_overlay.dart';
import 'pages/dashboard_page.dart';
import 'pages/screentime_page.dart';
import 'pages/profile_page.dart';
import 'pages/weekly_report_page.dart';
import 'pages/insights_page.dart';
import 'pages/auth_screen.dart';
import 'pages/onboarding_screen.dart';
import 'pages/splash_screen.dart';
import 'auth_provider.dart';
import 'session_provider.dart';
import 'fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (kIsWeb) {
      // No real web Firebase app is configured; web runs against the local
      // emulator suite (see firebase.json) under a demo-* project id, which
      // the emulators accept without real credentials.
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: '1:123456789012:web:demo',
          messagingSenderId: '123456789012',
          projectId: 'demo-entropy',
          authDomain: '127.0.0.1',
        ),
      );
      if (kDebugMode) {
        await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
        FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8082);
        FirebaseFunctions.instance.useFunctionsEmulator('127.0.0.1', 5001);
      }
    } else {
      await Firebase.initializeApp();
      await FcmService.initialize();
    }
  } catch (e) {
    debugPrint("Firebase/FCM initialization failed: $e");
  }
  runApp(const EntropyApp());
}

class EntropyApp extends StatelessWidget {
  const EntropyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'Entropy',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'Inter',
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border, width: 1),
            ),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const SplashScreen();
    }

    if (authProvider.currentUser == null) {
      return const AuthScreen();
    }

    if (authProvider.settings == null || !authProvider.settings!.onboardingComplete) {
      return const OnboardingScreen();
    }

    return const MainNavigation();
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  StreamSubscription? _driftSubscription;

  final List<Widget> _pages = [
    const DashboardPage(),
    const ScreenTimePage(),
    const ProfilePage(),
    const WeeklyReportPage(),
    const InsightsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
      _driftSubscription = sessionProvider.driftEventsStream.listen((event) {
        if (event['event'] == 'blocked_app_detected') {
          final String packageName = event['package'] ?? '';
          _showDriftOverlay(packageName);
        }
      });
    });
  }

  @override
  void dispose() {
    _driftSubscription?.cancel();
    super.dispose();
  }

  void _showDriftOverlay(String packageName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DriftOverlay(packageName: packageName),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: AppColors.background,
          elevation: 0,
          indicatorColor: AppColors.surface,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.grid_view_rounded, color: AppColors.textPrimary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.timer, color: AppColors.textPrimary),
              label: 'Screen Time',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person, color: AppColors.textPrimary),
              label: 'Profile',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_view_week, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.calendar_view_week_rounded, color: AppColors.textPrimary),
              label: 'Weekly',
            ),
            NavigationDestination(
              icon: Icon(Icons.analytics_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.analytics, color: AppColors.textPrimary),
              label: 'Insights',
            ),
          ],
        ),
      ),
    );
  }
}
