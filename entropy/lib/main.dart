import 'package:flutter/material.dart';
import 'widgets/components.dart';
import 'pages/dashboard_page.dart';
import 'pages/screentime_page.dart';
import 'pages/profile_page.dart';
import 'pages/weekly_report_page.dart';

void main() {
  runApp(const EntropyApp());
}

class EntropyApp extends StatelessWidget {
  const EntropyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entropy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Inter', // Defaulting to clean sans-serif
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const ScreenTimePage(),
    const ProfilePage(),
    const WeeklyReportPage(),
  ];

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
          ],
        ),
      ),
    );
  }
}
