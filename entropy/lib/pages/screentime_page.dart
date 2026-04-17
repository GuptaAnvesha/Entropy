import 'package:flutter/material.dart';
import '../widgets/components.dart';

class ScreenTimePage extends StatelessWidget {
  const ScreenTimePage({super.key});

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
              const Text('Screen Time Insights', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('5h 24m', style: TextStyle(color: AppColors.textPrimary, fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -1.5)),
              const Text('Total usage today', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              
              const SizedBox(height: 48),
              
              EntropyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('App Usage Breakdown', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    _buildAppStatRow('Instagram', '1h 45m', 0.8),
                    _buildAppStatRow('YouTube', '1h 10m', 0.5),
                    _buildAppStatRow('Slack', '45m', 0.3),
                    _buildAppStatRow('Chrome', '20m', 0.1),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text('Correlation', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
              EntropyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Screen Time vs Focus', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    const MockGraph(height: 120, color: AppColors.warning),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const InsightCard(
                icon: Icons.search_off,
                text: 'High screen usage strongly correlates with lower focus the subsequent day.',
                color: AppColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppStatRow(String name, String time, double percent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(time, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(2)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
