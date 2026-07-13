import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../widgets/components.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  int _getTimeBlockIndex(DateTime dt) {
    final hour = dt.hour;
    if (hour >= 6 && hour < 9) return 0; // Morning
    if (hour >= 9 && hour < 12) return 1; // Late Morning
    if (hour >= 12 && hour < 17) return 2; // Afternoon
    if (hour >= 17 && hour < 21) return 3; // Evening
    return 4; // Night (21:00 - 5:59)
  }

  String _getDriftFreqLabel(double ratio) {
    if (ratio < 0.20) return "Low";
    if (ratio <= 0.50) return "Medium";
    return "High";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('sessions')
              .snapshots(),
          builder: (context, snapshot) {
            List<Session> allSessions = [];
            double avgDuration = 0.0;
            double driftFreq = 0.0;
            String driftLabel = "--";

            // Heatmap matrix
            final matrix = List.generate(5, (_) => List.filled(7, 0.0));
            double maxCellValue = 0.0;

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              allSessions = snapshot.data!.docs
                  .map((doc) => Session.fromJson(doc.id, doc.data() as Map<String, dynamic>))
                  .where((s) => s.status == 'completed')
                  .toList();

              if (allSessions.isNotEmpty) {
                // Compute Avg Duration
                final totalDuration = allSessions.fold<double>(0.0, (sum, s) => sum + s.durationMinutes);
                avgDuration = totalDuration / allSessions.length;

                // Compute Drift Frequency
                final driftSessionsCount = allSessions.where((s) => s.driftEvents.isNotEmpty).length;
                driftFreq = driftSessionsCount / allSessions.length;
                driftLabel = _getDriftFreqLabel(driftFreq);

                // Compute Heatmap
                for (var s in allSessions) {
                  final col = s.startTime.weekday - 1; // 0 (Mon) to 6 (Sun)
                  final row = _getTimeBlockIndex(s.startTime);
                  matrix[row][col] += s.focusLevel.toDouble();
                }

                // Find max
                for (int r = 0; r < 5; r++) {
                  for (int c = 0; c < 7; c++) {
                    if (matrix[r][c] > maxCellValue) {
                      maxCellValue = matrix[r][c];
                    }
                  }
                }
              }
            }

            final String durationVal = avgDuration > 0
                ? avgDuration < 60
                    ? '${avgDuration.toInt()}m'
                    : '${(avgDuration / 60).floor()}h ${(avgDuration % 60).toInt()}m'
                : '0m';

            return SingleChildScrollView(
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
                        if (snapshot.hasError)
                          const SizedBox(
                            height: 100,
                            child: Center(
                              child: Text('Could not load telemetry.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ),
                          )
                        else if (snapshot.connectionState == ConnectionState.waiting)
                          const SizedBox(
                            height: 100,
                            child: Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                              ),
                            ),
                          )
                        else
                          _buildHeatmapGrid(matrix, maxCellValue),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            Text('M', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('T', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('W', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('T', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('F', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('S', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text('S', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('Key Metrics', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                       Expanded(child: EntropyCard(child: StatTile(title: 'Avg Duration', value: durationVal))),
                       const SizedBox(width: 16),
                       Expanded(child: EntropyCard(child: StatTile(title: 'Drift Freq', value: driftLabel))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  EntropyCard(child: const StatTile(title: 'Avg Recovery Time', value: 'Tracking...', subtitle: Text('Time to regain flow after drift', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))),

                  const SizedBox(height: 32),
                  const Text('Your Patterns', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
                  const SizedBox(height: 16),
                  
                  // Insights section from the sessions data or static advice as fallback
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid(List<List<double>> matrix, double maxCellValue) {
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
        final row = index ~/ 7;
        final col = index % 7;
        final val = matrix[row][col];
        
        double opacity = 0.04;
        if (maxCellValue > 0 && val > 0) {
          opacity = 0.04 + (val / maxCellValue) * 0.96;
        }

        return Tooltip(
          message: 'Total focus level: ${val.toInt()}',
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(opacity),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
    );
  }
}
