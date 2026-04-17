import 'package:flutter/material.dart';
import 'package:entropy/widgets/components.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
              const Text('Cognitive Profile', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('Analytics', style: TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
              
              const SizedBox(height: 32),
              
              EntropyCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Focus Heatmap', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 24),
                    _buildHeatmapMock(),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              const Text('Key Metrics', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),

              Row(
                children: [
                   Expanded(child: EntropyCard(child: const StatTile(title: 'Avg Duration', value: '45m'))),
                   const SizedBox(width: 16),
                   Expanded(child: EntropyCard(child: const StatTile(title: 'Drift Freq', value: 'High'))),
                ],
              ),
              const SizedBox(height: 16),
              EntropyCard(child: const StatTile(title: 'Avg Recovery Time', value: '22m', subtitle: Text('Time to regain flow after drift', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))),

              const SizedBox(height: 32),
              const Text('Your Patterns', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
              const SizedBox(height: 16),
              
              const InsightCard(
                icon: Icons.nightlight_round,
                text: 'You lose focus drastically after 6 PM. Shift intensive tasks earlier.',
              ),
              const InsightCard(
                icon: Icons.compress,
                text: 'Short sprint sessions (25m) yield 40% higher adherence for you.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapMock() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7 * 5, // 7 days, 5 time blocks
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        // Pseudo-random opacity to mock a heatmap
        double opacity = (index % 3 == 0) ? 0.8 : (index % 2 == 0) ? 0.3 : 0.05;
        // Peak hours in the middle
        if (index > 10 && index < 25) opacity = 1.0;
        
        return Container(
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(opacity),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}
