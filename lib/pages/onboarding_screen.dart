import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../widgets/components.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _permissionsChannel = MethodChannel('entropy/permissions');
  static const _usageChannel = MethodChannel('entropy/usage_stats');

  // Native permission/usage channels only exist on Android.
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // Permission and App selection state
  bool _usagePermissionGranted = false;
  List<Map<String, String>> _installedApps = [];
  final Set<String> _selectedBlockedApps = {};
  bool _isLoadingApps = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    if (!_isAndroid) return;
    try {
      final bool granted = await _permissionsChannel.invokeMethod('hasUsageStatsPermission');
      setState(() {
        _usagePermissionGranted = granted;
      });
      if (granted) {
        _loadInstalledApps();
      }
    } catch (e) {
      debugPrint("Error checking usage stats permission: $e");
    }
  }

  Future<void> _requestUsagePermission() async {
    if (!_isAndroid) return;
    try {
      await _permissionsChannel.invokeMethod('openUsageAccessSettings');
      // Wait for user to come back and check again
      Future.delayed(const Duration(seconds: 2), () async {
        final bool granted = await _permissionsChannel.invokeMethod('hasUsageStatsPermission');
        setState(() {
          _usagePermissionGranted = granted;
        });
        if (granted) {
          _loadInstalledApps();
        }
      });
    } catch (e) {
      debugPrint("Error opening usage settings: $e");
    }
  }

  Future<void> _loadInstalledApps() async {
    setState(() {
      _isLoadingApps = true;
    });
    try {
      final List<dynamic>? apps = await _usageChannel.invokeMethod('getInstalledApps');
      if (apps != null) {
        setState(() {
          _installedApps = apps.map((app) {
            final map = Map<String, dynamic>.from(app);
            return {
              'name': map['name']?.toString() ?? '',
              'packageName': map['packageName']?.toString() ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Error loading installed apps: $e");
    } finally {
      setState(() {
        _isLoadingApps = false;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_isAndroid) {
      try {
        await _permissionsChannel.invokeMethod('requestNotificationPermission');
      } catch (e) {
        debugPrint("Error requesting notification permission: $e");
      }
    }
  }

  void _nextPage() {
    final bool isAndroid = _isAndroid;
    final int totalPages = isAndroid ? 4 : 2;
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Save selected apps and onboarding status to Firestore
    final settings = UserSettings(
      blockedApps: _selectedBlockedApps.toList(),
      onboardingComplete: true,
      usagePermissionGranted: _usagePermissionGranted,
    );
    await authProvider.updateSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    // If iOS, skip permissions and apps selection pages by auto jumping
    final bool isAndroid = _isAndroid;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                  // Skip Screen 2 and 3 on iOS — not applicable since
                  // iOS page list only has 2 items (index 0 and 1)
                },
                children: [
                  _buildIntroScreen(),
                  if (isAndroid) _buildPermissionScreen(),
                  if (isAndroid) _buildAppSelectionScreen(),
                  _buildNotificationScreen(),
                ],
              ),
            ),
            _buildNavigationRow(isAndroid),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.blur_on_rounded, size: 100, color: AppColors.accent),
          const SizedBox(height: 40),
          const Text(
            'Entropy tracks your cognitive performance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Know when you focus, when you drift, and why.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.security_rounded, size: 80, color: AppColors.warning),
          const SizedBox(height: 40),
          const Text(
            'Usage Access Permission',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Entropy needs Usage Access to detect when distraction apps are opened during your focus sessions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          if (_usagePermissionGranted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.check_circle_outline, color: AppColors.success),
                SizedBox(width: 8),
                Text('Permission Granted', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
              ],
            )
          else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _requestUsagePermission,
              child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            const Text(
              'You can skip this, but drift detection will be disabled.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppSelectionScreen() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'Select Blocked Apps',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Which apps should trigger drift alerts during focus sessions?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: _isLoadingApps
                  ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _installedApps.isEmpty
                      ? const Center(child: Text('No apps found or usage access missing', style: TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _installedApps.length,
                          itemBuilder: (context, index) {
                            final app = _installedApps[index];
                            final name = app['name']!;
                            final pkg = app['packageName']!;
                            final isSelected = _selectedBlockedApps.contains(pkg);

                            return CheckboxListTile(
                              activeColor: AppColors.accent,
                              checkColor: AppColors.textPrimary,
                              title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
                              subtitle: Text(pkg, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedBlockedApps.add(pkg);
                                  } else {
                                    _selectedBlockedApps.remove(pkg);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationScreen() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.notifications_active_rounded, size: 80, color: AppColors.accent),
          const SizedBox(height: 40),
          const Text(
            'Notification Permission',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Focus Coach will send real-time nudges and messages during sessions to keep you on track.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await _requestNotificationPermission();
              _finishOnboarding();
            },
            child: const Text('Enable Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _finishOnboarding,
            child: const Text('Skip for now', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationRow(bool isAndroid) {
    final int totalPages = isAndroid ? 4 : 2;
    // Map current index visually
    int dotIndex = _currentPage;
    if (!isAndroid) {
      dotIndex = _currentPage == 3 ? 1 : 0;
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dots indicator
          Row(
            children: List.generate(
              totalPages,
              (index) => Container(
                margin: const EdgeInsets.only(right: 8),
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: dotIndex == index ? AppColors.accent : AppColors.border,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            onPressed: _nextPage,
            child: Text(
              dotIndex == totalPages - 1 ? 'Finish' : 'Next',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
