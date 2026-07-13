import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../auth_provider.dart';
import '../debug_seed.dart';
import '../models.dart';
import '../widgets/components.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

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

  Future<void> _runSeedAction(BuildContext context, String action, String uid) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      String message;
      switch (action) {
        case 'seed1':
          await DebugSeeder.seedHistory(uid, 1);
          message = 'Seeded 1 day of synthetic data.';
        case 'seed7':
          await DebugSeeder.seedHistory(uid, 7);
          message = 'Seeded 7 days of synthetic data.';
        case 'seed30':
          await DebugSeeder.seedHistory(uid, 30);
          message = 'Seeded 30 days of synthetic data.';
        case 'drift':
          final detected = await DebugSeeder.seedDriftTodayAndAnalyze(uid);
          message = detected
              ? 'Drift detected — alert written to insights.'
              : 'Analyzer ran but flagged no drift (seed history first).';
        default:
          return;
      }
      messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.surface));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Seed failed: $e'), backgroundColor: AppColors.warning));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.currentUser?.uid ?? '';

    final rangeStart = DateTime.now().subtract(const Duration(days: 14));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insights', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Debug-only synthetic data menu; hidden unless the app is built
          // with --dart-define=SEED_TOOLS=true
          if (kSeedToolsEnabled)
            PopupMenuButton<String>(
              icon: const Icon(Icons.science_outlined, color: AppColors.textSecondary),
              color: AppColors.surface,
              onSelected: (value) => _runSeedAction(context, value, uid),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'seed1', child: Text('Seed 1 day', style: TextStyle(color: AppColors.textPrimary))),
                PopupMenuItem(value: 'seed7', child: Text('Seed 7 days', style: TextStyle(color: AppColors.textPrimary))),
                PopupMenuItem(value: 'seed30', child: Text('Seed 30 days', style: TextStyle(color: AppColors.textPrimary))),
                PopupMenuItem(value: 'drift', child: Text('Seed drift day + analyze', style: TextStyle(color: AppColors.textPrimary))),
              ],
            ),
        ],
      ),
      backgroundColor: theme.colorScheme.surface,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('sessions')
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart))
            .snapshots(),
        builder: (context, sessionSnapshot) {
          double driftIndex = 0.0;
          double fidelity = 100.0;
          bool hasSessions = false;
          List<Session> recentSessions = [];

          if (sessionSnapshot.hasData && sessionSnapshot.data!.docs.isNotEmpty) {
            recentSessions = sessionSnapshot.data!.docs
                .map((doc) => Session.fromJson(doc.id, doc.data() as Map<String, dynamic>))
                .where((s) => s.status == 'completed')
                .toList();

            if (recentSessions.isNotEmpty) {
              hasSessions = true;
              
              int totalDrifts = recentSessions.fold<int>(0, (sum, s) => sum + s.driftEvents.length);
              int sessionsWithDrift = recentSessions.where((s) => s.driftEvents.isNotEmpty).length;

              driftIndex = (totalDrifts / recentSessions.length) * 10;
              fidelity = ((recentSessions.length - sessionsWithDrift) / recentSessions.length) * 100;
            }
          }

          final String driftIndexStr = hasSessions ? '${driftIndex.toStringAsFixed(1)}σ' : '--σ';
          final String fidelityStr = hasSessions ? '${fidelity.toInt()}%' : '--%';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Drift Index & Entropy', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Evaluating systemic behavioral degradation over time.', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 32),
                
                // Real fl_chart Area
                Container(
                  height: 240,
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Focus vs Drift Events', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white70, fontSize: 13)),
                          Icon(Icons.stacked_line_chart, color: theme.colorScheme.primary, size: 18),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: sessionSnapshot.hasError
                            ? const Center(
                                child: Text(
                                  'Could not load telemetry.',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              )
                            : sessionSnapshot.connectionState == ConnectionState.waiting
                                ? const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                    ),
                                  )
                                : hasSessions
                                    ? _buildDualAxisChart(recentSessions)
                                    : const Center(
                                        child: Text(
                                          'Not enough session logs to plot telemetry.',
                                          style: TextStyle(color: Colors.white38),
                                        ),
                                      ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Text('Telemetry Averages', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(child: _buildMetricCard('Drift Index', driftIndexStr, Icons.radar, Colors.redAccent)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard('Protocol Fidelity', fidelityStr, Icons.security, Colors.greenAccent)),
                  ],
                ),
                
                const SizedBox(height: 32),
                Text('Recommendations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // Pull insights collection from Firestore
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('insights')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, insightsSnapshot) {
                    if (insightsSnapshot.hasData && insightsSnapshot.data!.docs.isNotEmpty) {
                      return Column(
                        children: insightsSnapshot.data!.docs.map((doc) {
                          final insight = Insight.fromJson(doc.id, doc.data() as Map<String, dynamic>);
                          return InsightCard(
                            icon: _getInsightIcon(insight.icon),
                            text: insight.text,
                            color: _getInsightColor(insight.icon),
                          );
                        }).toList(),
                      );
                    }

                    // Static Fallback
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('Entropy Synthesis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Historical data mapping will populate here. Use the app regularly so that the AI Drift Analyzer can synthesize contextual recommendations to stabilize your drift index.',
                              style: TextStyle(color: Colors.white70, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildDualAxisChart(List<Session> sessions) {
    // Group metrics by day for last 14 days
    final Map<String, double> focusByDate = {};
    final Map<String, double> driftCountsByDate = {};
    final Map<String, int> sessionCounts = {};

    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();

    for (var s in sessions) {
      final dateKey = formatter.format(s.startTime);
      focusByDate[dateKey] = (focusByDate[dateKey] ?? 0.0) + s.focusLevel;
      driftCountsByDate[dateKey] = (driftCountsByDate[dateKey] ?? 0.0) + s.driftEvents.length;
      sessionCounts[dateKey] = (sessionCounts[dateKey] ?? 0) + 1;
    }

    // Average the focus level per day
    focusByDate.forEach((key, val) {
      focusByDate[key] = val / sessionCounts[key]!;
    });

    final List<String> last14Days = [];
    for (int i = 13; i >= 0; i--) {
      last14Days.add(formatter.format(now.subtract(Duration(days: i))));
    }

    final List<FlSpot> focusSpots = [];
    final List<FlSpot> driftSpots = [];

    for (int i = 0; i < 14; i++) {
      final date = last14Days[i];
      final focus = focusByDate[date] ?? 5.0; // Default average focus 5
      final drifts = driftCountsByDate[date] ?? 0.0;

      focusSpots.add(FlSpot(i.toDouble(), focus));
      driftSpots.add(FlSpot(i.toDouble(), drifts));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.5),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 2 == 0) {
                  return Text('${value.toInt()}', style: const TextStyle(color: AppColors.warning, fontSize: 8));
                }
                return const SizedBox();
              },
              reservedSize: 18,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value % 2 == 0) {
                  return Text('${value.toInt()}', style: const TextStyle(color: AppColors.accent, fontSize: 8));
                }
                return const SizedBox();
              },
              reservedSize: 18,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < 14) {
                  // Show abbreviated date every 2 days
                  if (idx % 2 == 0) {
                    final parsed = formatter.parse(last14Days[idx]);
                    return Text(DateFormat('Md').format(parsed), style: const TextStyle(color: Colors.white38, fontSize: 8));
                  }
                }
                return const SizedBox();
              },
              reservedSize: 18,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 13,
        minY: 0,
        maxY: 10,
        lineBarsData: [
          LineChartBarData(
            spots: focusSpots,
            color: AppColors.accent,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
          LineChartBarData(
            spots: driftSpots,
            color: AppColors.warning,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
