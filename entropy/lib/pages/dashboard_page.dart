import 'package:flutter/material.dart';
import '../widgets/components.dart';
import 'logging_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const LoggingPage()));
        },
        label: const Text('+ Log Session', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Good Evening', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Today\'s State', style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
              const SizedBox(height: 24),

              // Today's State Cards
              Row(
                children: [
                  Expanded(
                    child: EntropyCard(
                      child: StatTile(
                        title: 'Focus Score',
                        value: '72%',
                        subtitle: Row(
                          children: const [
                            Icon(Icons.check_circle, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text('Stable drift', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: EntropyCard(
                      child: StatTile(
                        title: 'Energy Level',
                        value: 'Moderate',
                        subtitle: Row(
                          children: const [
                            Icon(Icons.battery_4_bar, size: 14, color: AppColors.textSecondary),
                            SizedBox(width: 4),
                            Text('Dipping slightly', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              const Text('Trends', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
              EntropyCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Focus Trend', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                        Text('Last 7 hours', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const MockGraph(height: 100, color: AppColors.accent),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              const Text('Quick Insights', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
              const InsightCard(
                icon: Icons.lightbulb_outline,
                text: 'You focus best between 9–11 AM.',
              ),
              const InsightCard(
                icon: Icons.warning_amber_rounded,
                text: 'High screen usage detected yesterday. Expect a 10% focus reduction today.',
                color: AppColors.warning,
              ),
              const SizedBox(height: 80), // Fab spacing
            ],
          ),
        ),
      ),
    );
  }
}
