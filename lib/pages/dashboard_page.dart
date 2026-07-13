import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth_provider.dart';
import '../session_provider.dart';
import '../models.dart';
import '../widgets/components.dart';
import 'logging_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  IconData _getInsightIcon(String iconStr) {
    switch (iconStr) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  Color _getInsightColor(String iconStr) {
    switch (iconStr) {
      case 'warning':
        return AppColors.warning;
      case 'lightbulb':
        return AppColors.accent;
      case 'info':
      default:
        return AppColors.textSecondary;
    }
  }

  String _getEnergyLabel(double energy) {
    if (energy >= 9.0) return "Peak";
    if (energy >= 7.0) return "High";
    if (energy >= 5.0) return "Moderate";
    return "Low";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final sessionProvider = Provider.of<SessionProvider>(context);
    final uid = authProvider.currentUser?.uid ?? '';

    final todayStart = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: AppColors.background,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        onPressed: () async {
          if (sessionProvider.isCheckedIn) {
            final startTime = sessionProvider.checkInTime ?? DateTime.now();
            final sessionId = sessionProvider.currentSessionId ?? '';
            final elapsedMinutes = sessionProvider.elapsedSeconds / 60.0;

            await sessionProvider.checkOut();

            if (context.mounted) {
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
          } else {
            final blockedApps = authProvider.settings?.blockedApps ?? [];
            await sessionProvider.checkIn(uid, blockedApps);
          }
        },
        label: Builder(
          builder: (context) {
            if (sessionProvider.isCheckedIn) {
              final minutes = (sessionProvider.elapsedSeconds ~/ 60)
                  .toString()
                  .padLeft(2, '0');
              final seconds = (sessionProvider.elapsedSeconds % 60)
                  .toString()
                  .padLeft(2, '0');
              return Text(
                '⏹ Check Out — $minutes:$seconds',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              );
            }
            return const Text(
              '+ Check In',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            );
          },
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('sessions')
              .where(
                'startTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
              .snapshots(),
          builder: (context, snapshot) {
            List<Session> todaySessions = [];
            double avgFocus = 0.0;
            double avgEnergy = 0.0;
            bool hasData = false;

            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              todaySessions = snapshot.data!.docs
                  .map(
                    (doc) => Session.fromJson(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    ),
                  )
                  .where((s) => s.status == 'completed')
                  .toList();

              if (todaySessions.isNotEmpty) {
                hasData = true;
                final totalFocus = todaySessions.fold<int>(
                  0,
                  (sum, s) => sum + s.focusLevel,
                );
                final totalEnergy = todaySessions.fold<int>(
                  0,
                  (sum, s) => sum + s.energyLevel,
                );
                avgFocus = (totalFocus / todaySessions.length) * 10;
                avgEnergy = totalEnergy / todaySessions.length;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getTimeGreeting(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Today\'s State',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Today's State Cards
                  Row(
                    children: [
                      Expanded(
                        child: EntropyCard(
                          child: StatTile(
                            title: 'Focus Score',
                            value: hasData ? '${avgFocus.toInt()}%' : '--%',
                            subtitle: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasData ? 'Stable flow' : 'No sessions today',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
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
                            value: hasData ? _getEnergyLabel(avgEnergy) : '--',
                            subtitle: Row(
                              children: [
                                const Icon(
                                  Icons.battery_4_bar,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasData ? 'Daily Average' : 'Pending logs',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Trends',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  EntropyCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Focus Trend',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Today\'s Timeline',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 120,
                          child: snapshot.hasError
                              ? const Center(
                                  child: Text(
                                    'Could not load telemetry.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : snapshot.connectionState ==
                                    ConnectionState.waiting
                              ? const Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                )
                              : hasData
                              ? _buildTrendChart(todaySessions)
                              : const Center(
                                  child: Text(
                                    'No sessions logged today yet.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Quick Insights',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Insights from Firestore
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('insights')
                        .orderBy('createdAt', descending: true)
                        .limit(2)
                        .snapshots(),
                    builder: (context, insightSnapshot) {
                      if (insightSnapshot.hasData &&
                          insightSnapshot.data!.docs.isNotEmpty) {
                        return Column(
                          children: insightSnapshot.data!.docs.map((doc) {
                            final insight = Insight.fromJson(
                              doc.id,
                              doc.data() as Map<String, dynamic>,
                            );
                            return InsightCard(
                              icon: _getInsightIcon(insight.icon),
                              text: insight.text,
                              color: _getInsightColor(insight.icon),
                            );
                          }).toList(),
                        );
                      }

                      // Fallback default mock insights if database has none yet
                      return Column(
                        children: const [
                          InsightCard(
                            icon: Icons.lightbulb_outline,
                            text:
                                'Your focus insights will appear here as sessions are logged.',
                          ),
                          InsightCard(
                            icon: Icons.warning_amber_rounded,
                            text: 'No drift telemetry recorded yet today.',
                            color: AppColors.warning,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 80), // FAB spacing
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildTrendChart(List<Session> sessions) {
    sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

    final List<FlSpot> spots = [];
    for (int i = 0; i < sessions.length; i++) {
      final hour =
          sessions[i].startTime.hour + (sessions[i].startTime.minute / 60.0);
      spots.add(FlSpot(hour, sessions[i].focusLevel.toDouble()));
    }

    double minX = 0;
    double maxX = 24;
    if (spots.isNotEmpty) {
      minX = spots.first.x - 1;
      maxX = spots.last.x + 1;
      if (minX < 0) minX = 0;
      if (maxX > 24) maxX = 24;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.border.withOpacity(0.5), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 22,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 4 == 0) {
                  final h = value.toInt();
                  return Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 20,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: minX,
        maxX: maxX,
        minY: 1,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.accent.withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }
}
