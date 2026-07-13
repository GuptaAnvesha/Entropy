import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../widgets/components.dart';

class WeeklyReportPage extends StatelessWidget {
  const WeeklyReportPage({super.key});

  String _getIsoWeekIdentifier(DateTime dt) {
    final day = dt.weekday; // 1 (Mon) - 7 (Sun)
    final thursday = dt.add(Duration(days: 4 - day));
    final year = thursday.year;
    final firstDayOfYear = DateTime(year, 1, 1);
    final days = thursday.difference(firstDayOfYear).inDays;
    final week = (days / 7).floor() + 1;
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  String _getWeekIdForDateString(String dateStr) {
    try {
      final parsed = DateFormat('yyyy-MM-dd').parse(dateStr);
      return _getIsoWeekIdentifier(parsed);
    } catch (_) {
      return '';
    }
  }

  String _formatDuration(double minutes) {
    final hours = minutes ~/ 60;
    final remaining = (minutes % 60).toInt();
    if (hours > 0) {
      return '${hours}h ${remaining}m';
    }
    return '${remaining}m';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.currentUser?.uid ?? '';
    final now = DateTime.now();
    final currentWeekId = _getIsoWeekIdentifier(now);
    final lastWeekId = _getIsoWeekIdentifier(
      now.subtract(const Duration(days: 7)),
    );

    final startRange = now.subtract(const Duration(days: 14));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('sessions')
              .where(
                'startTime',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startRange),
              )
              .snapshots(),
          builder: (context, sessionSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('appUsage')
                  .snapshots(), // Load recent app usages
              builder: (context, usageSnapshot) {
                // Focus time calculations
                double currentWeekFocus = 0.0;
                double lastWeekFocus = 0.0;

                // Track daily focus for current week
                final Map<int, double> dailyFocusCurrentWeek =
                    {}; // 1 (Mon) - 7 (Sun)

                if (sessionSnapshot.hasData) {
                  for (var doc in sessionSnapshot.data!.docs) {
                    final session = Session.fromJson(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    );
                    if (session.status == 'completed') {
                      final weekId = _getIsoWeekIdentifier(session.startTime);
                      if (weekId == currentWeekId) {
                        currentWeekFocus += session.durationMinutes;
                        final day = session.startTime.weekday;
                        dailyFocusCurrentWeek[day] =
                            (dailyFocusCurrentWeek[day] ?? 0.0) +
                            session.durationMinutes;
                      } else if (weekId == lastWeekId) {
                        lastWeekFocus += session.durationMinutes;
                      }
                    }
                  }
                }

                // App usage calculations
                double currentWeekScreen = 0.0;
                double lastWeekScreen = 0.0;

                if (usageSnapshot.hasData) {
                  for (var doc in usageSnapshot.data!.docs) {
                    final dateStr = doc.id;
                    final weekId = _getWeekIdForDateString(dateStr);
                    final data = doc.data() as Map<String, dynamic>;
                    final list = data['entries'] as List? ?? [];

                    double dailyMin = 0.0;
                    for (var item in list) {
                      dailyMin += (item['durationMinutes'] ?? 0.0);
                    }

                    if (weekId == currentWeekId) {
                      currentWeekScreen += dailyMin;
                    } else if (weekId == lastWeekId) {
                      lastWeekScreen += dailyMin;
                    }
                  }
                }

                // Best and Worst Day calculations
                String bestDayName = '--';
                String bestDayValue = 'No focus logged';
                String worstDayName = '--';
                String worstDayValue = 'No focus logged';

                if (dailyFocusCurrentWeek.isNotEmpty) {
                  int bestDayIdx = dailyFocusCurrentWeek.keys.first;
                  int worstDayIdx = dailyFocusCurrentWeek.keys.first;
                  double maxFocus = dailyFocusCurrentWeek[bestDayIdx]!;
                  double minFocus = dailyFocusCurrentWeek[worstDayIdx]!;

                  dailyFocusCurrentWeek.forEach((day, duration) {
                    if (duration > maxFocus) {
                      maxFocus = duration;
                      bestDayIdx = day;
                    }
                    if (duration < minFocus) {
                      minFocus = duration;
                      worstDayIdx = day;
                    }
                  });

                  final weekdays = [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                    'Saturday',
                    'Sunday',
                  ];
                  bestDayName = weekdays[bestDayIdx - 1];
                  bestDayValue = '${_formatDuration(maxFocus)} focus';

                  worstDayName = weekdays[worstDayIdx - 1];
                  worstDayValue = '${_formatDuration(minFocus)} focus';
                }

                // Arrows and colors comparison
                final focusImproved = currentWeekFocus >= lastWeekFocus;
                final screenImproved = currentWeekScreen <= lastWeekScreen;

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Report',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Reflection',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -1,
                        ),
                      ),

                      const SizedBox(height: 32),

                      EntropyCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Week Summary',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Focus Time',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(currentWeekFocus),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      focusImproved
                                          ? Icons.arrow_upward
                                          : Icons.arrow_downward,
                                      color: focusImproved
                                          ? AppColors.success
                                          : AppColors.warning,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(
                                color: AppColors.border,
                                height: 1,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Screen Time',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(currentWeekScreen),
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      screenImproved
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: screenImproved
                                          ? AppColors.success
                                          : AppColors.warning,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        'Highlights',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: EntropyCard(
                              child: StatTile(
                                title: 'Best Day',
                                value: bestDayName,
                                subtitle: Text(
                                  bestDayValue,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: EntropyCard(
                              child: StatTile(
                                title: 'Worst Day',
                                value: worstDayName,
                                subtitle: Text(
                                  worstDayValue,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text(
                        'System Insights',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pull weekly summary and plan from Firestore doc
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .collection('weeklyPlans')
                            .doc(currentWeekId)
                            .snapshots(),
                        builder: (context, planSnapshot) {
                          if (planSnapshot.hasData &&
                              planSnapshot.data!.exists) {
                            final plan = WeeklyPlan.fromJson(
                              currentWeekId,
                              planSnapshot.data!.data() as Map<String, dynamic>,
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (plan.summary.isNotEmpty) ...[
                                  EntropyCard(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(
                                                Icons.auto_awesome,
                                                color: AppColors.accent,
                                                size: 18,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Plan Summary',
                                                style: TextStyle(
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            plan.summary,
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 14,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                if (plan.recommendations.isNotEmpty)
                                  ...plan.recommendations.map(
                                    (rec) => InsightCard(
                                      icon: Icons.wb_sunny,
                                      text: rec,
                                      color: AppColors.accent,
                                    ),
                                  )
                                else
                                  const InsightCard(
                                    icon: Icons.wb_sunny,
                                    text:
                                        'No recommendations compiled yet for this week.',
                                  ),
                              ],
                            );
                          }

                          // Fallback default insights
                          return Column(
                            children: const [
                              InsightCard(
                                icon: Icons.wb_sunny,
                                text:
                                    'Your weekly performance plan is being compiled by your Focus Coach.',
                              ),
                              InsightCard(
                                icon: Icons.notifications_active,
                                text:
                                    'Ensure you log multiple sessions to generate personalized weekly insights.',
                                color: AppColors.warning,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
