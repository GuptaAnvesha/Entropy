import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_provider.dart';
import '../session_provider.dart';
import '../widgets/components.dart';
import '../pages/logging_page.dart';

class DriftOverlay extends StatefulWidget {
  final String packageName;

  const DriftOverlay({super.key, required this.packageName});

  @override
  State<DriftOverlay> createState() => _DriftOverlayState();
}

class _DriftOverlayState extends State<DriftOverlay> {
  int _secondsLeft = 10;
  Timer? _countdownTimer;
  bool _actionTaken = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        _countdownTimer?.cancel();
        _autoEndSession();
      }
    });
  }

  void _goBack() async {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    final uid = authProvider.currentUser?.uid ?? '';
    final appName = widget.packageName.split('.').last;

    await sessionProvider.logDriftEvent(uid, appName, 'warned');

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _endSession() async {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sessionProvider = Provider.of<SessionProvider>(context, listen: false);
    
    final uid = authProvider.currentUser?.uid ?? '';
    final appName = widget.packageName.split('.').last;
    
    final startTime = sessionProvider.checkInTime ?? DateTime.now();
    final sessionId = sessionProvider.currentSessionId ?? '';
    final elapsedMinutes = sessionProvider.elapsedSeconds / 60.0;

    await sessionProvider.logDriftEvent(uid, appName, 'ended');
    await sessionProvider.checkOut();

    if (mounted) {
      // Pop the overlay
      Navigator.pop(context);
      // Navigate to LoggingPage
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LoggingPage(
            durationMinutes: elapsedMinutes,
            startTime: startTime,
            sessionId: sessionId,
          ),
        ),
      );
    }
  }

  void _autoEndSession() {
    _endSession();
  }

  @override
  Widget build(BuildContext context) {
    final appName = widget.packageName.split('.').last.toUpperCase();

    return PopScope(
      canPop: false, // Prevent dismissing by back button
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.95),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 100,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 32),
                const Text(
                  'COGNITIVE DRIFT DETECTED',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'You opened $appName, which is blocked during your focus session.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                Text(
                  'Auto-terminating in $_secondsLeft seconds...',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _goBack,
                        child: const Text(
                          'Go Back',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _endSession,
                        child: const Text(
                          'End Session',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
