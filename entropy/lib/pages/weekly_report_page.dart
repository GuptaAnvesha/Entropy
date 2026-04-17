import 'package:flutter/material.dart';
import '../widgets/components.dart';

class WeeklyReportPage extends StatelessWidget {
  const WeeklyReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Report', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('Reflection', style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
              
              const SizedBox(height: 32),
              
              EntropyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Week Summary', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Focus Time', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                        Row(
                          children: const [
                            Text('14h 20m', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_upward, color: AppColors.accent, size: 16),
                          ],
                        )
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: AppColors.border, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Screen Time', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                        Row(
                          children: const [
                            Text('22h 10m', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_downward, color: AppColors.success, size: 16),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text('Highlights', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
              Row(
                children: const [
                  Expanded(
                    child: EntropyCard(
                      child: StatTile(
                        title: 'Best Day',
                        value: 'Tuesday',
                        subtitle: Text('4h 10m focus', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: EntropyCard(
                      child: StatTile(
                        title: 'Worst Day',
                        value: 'Friday',
                        subtitle: Text('50m focus', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              const Text('System Insights', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
              const InsightCard(
                icon: Icons.wb_sunny,
                text: 'Most productive time: Mornings. You output 65% of your work before 12 PM.',
              ),
              const InsightCard(
                icon: Icons.notifications_active,
                text: 'Biggest distraction: Social Media. Accounting for 40% of all session terminations.',
                color: AppColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
