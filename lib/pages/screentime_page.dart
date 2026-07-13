import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../auth_provider.dart';
import '../models.dart';
import '../widgets/components.dart';

class ScreenTimePage extends StatefulWidget {
  const ScreenTimePage({super.key});

  @override
  State<ScreenTimePage> createState() => _ScreenTimePageState();
}

class _ScreenTimePageState extends State<ScreenTimePage>
    with WidgetsBindingObserver {
  static const _usageChannel = MethodChannel('entropy/usage_stats');
  static const _permissionsChannel = MethodChannel('entropy/permissions');

  // Usage telemetry channels only exist on Android.
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  bool _isRefreshing = false;
  bool? _hasUsagePermission;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionAndRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check after the user returns from the Usage Access settings screen
    if (state == AppLifecycleState.resumed && _hasUsagePermission == false) {
      _checkPermissionAndRefresh();
    }
  }

  Future<void> _checkPermissionAndRefresh() async {
    if (!_isAndroid) return;
    try {
      final bool granted = await _permissionsChannel.invokeMethod(
        'hasUsageStatsPermission',
      );
      if (!mounted) return;
      setState(() {
        _hasUsagePermission = granted;
      });
      if (granted) {
        _refreshUsageData();
      }
    } catch (e) {
      debugPrint("Error checking usage stats permission: $e");
    }
  }

  Future<void> _openUsageAccessSettings() async {
    try {
      await _permissionsChannel.invokeMethod('openUsageAccessSettings');
    } catch (e) {
      debugPrint("Error opening usage settings: $e");
    }
  }

  Future<void> _refreshUsageData() async {
    if (!_isAndroid) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final List<dynamic>? usage = await _usageChannel
          .invokeMethod('getAppUsage', {
            'startTime': todayStart.millisecondsSinceEpoch,
            'endTime': now.millisecondsSinceEpoch,
          });

      // Day x hour buckets for the trailing week (heatmap + baseline source)
      final List<dynamic>? hourly = await _usageChannel
          .invokeMethod('getHourlyAppUsage', {
            'startTime': todayStart
                .subtract(const Duration(days: 6))
                .millisecondsSinceEpoch,
            'endTime': now.millisecondsSinceEpoch,
          });

      final Map<String, Map<String, double>> hourlyByDay = {};
      if (hourly != null) {
        for (final item in hourly) {
          final map = Map<String, dynamic>.from(item);
          final dateKey = map['dateKey']?.toString() ?? '';
          final hourKey = (map['hour'] ?? 0).toString();
          final mins = (map['durationMinutes'] ?? 0.0).toDouble();
          if (dateKey.isEmpty) continue;
          final day = hourlyByDay.putIfAbsent(dateKey, () => {});
          day[hourKey] = (day[hourKey] ?? 0.0) + mins;
        }
      }

      final usageCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('appUsage');
      final batch = FirebaseFirestore.instance.batch();

      if (usage != null) {
        final entries = usage.map((item) {
          final map = Map<String, dynamic>.from(item);
          return {
            'appName': map['appName'] ?? '',
            'packageName': map['packageName'] ?? '',
            'durationMinutes': map['durationMinutes'] ?? 0.0,
          };
        }).toList();

        batch.set(usageCollection.doc(todayStr), {
          'entries': entries,
          if (hourlyByDay.containsKey(todayStr))
            'hourly': hourlyByDay[todayStr],
        }, SetOptions(merge: true));
      }

      // Backfill hourly maps for previous days without touching their entries
      hourlyByDay.forEach((dateKey, hours) {
        if (dateKey != todayStr) {
          batch.set(usageCollection.doc(dateKey), {
            'hourly': hours,
          }, SetOptions(merge: true));
        }
      });

      await batch.commit();
    } catch (e) {
      debugPrint("Error fetching app usage: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatDuration(double minutes) {
    if (minutes < 1.0) {
      return '${(minutes * 60).toInt()}s';
    } else if (minutes < 60) {
      return '${minutes.toInt()}m';
    } else {
      final hours = minutes ~/ 60;
      final remaining = (minutes % 60).toInt();
      return '${hours}h ${remaining}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final uid = authProvider.currentUser?.uid ?? '';
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (!_isAndroid) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.phonelink_lock_rounded,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Screen Time Telemetry',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Detailed screen time tracking is available on Android.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_hasUsagePermission == false) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 80,
                    color: AppColors.warning,
                  ),
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
                    'Entropy needs Usage Access to read screen time telemetry and detect behavioral drift.',
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _openUsageAccessSettings,
                    child: const Text(
                      'Grant Access',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshUsageData,
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('appUsage')
                .doc(todayStr)
                .snapshots(),
            builder: (context, usageSnapshot) {
              List<AppUsageEntry> entries = [];
              double totalMinutes = 0.0;

              if (usageSnapshot.hasData && usageSnapshot.data!.exists) {
                final data = usageSnapshot.data!.data() as Map<String, dynamic>;
                final list = data['entries'] as List? ?? [];
                entries = list
                    .map(
                      (e) =>
                          AppUsageEntry.fromJson(Map<String, dynamic>.from(e)),
                    )
                    .toList();

                // Sort by duration descending
                entries.sort(
                  (a, b) => b.durationMinutes.compareTo(a.durationMinutes),
                );
                totalMinutes = entries.fold<double>(
                  0.0,
                  (sum, e) => sum + e.durationMinutes,
                );
              }

              final topApps = entries.take(5).toList();

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 32.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Screen Time Insights',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        if (_isRefreshing)
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.accent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(totalMinutes),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1.5,
                      ),
                    ),
                    const Text(
                      'Total usage today',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 48),

                    EntropyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'App Usage Breakdown',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (topApps.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'No telemetry available for today yet.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...topApps.map((app) {
                              final pct = totalMinutes > 0
                                  ? (app.durationMinutes / totalMinutes)
                                  : 0.0;
                              return _buildAppStatRow(
                                app.appName,
                                _formatDuration(app.durationMinutes),
                                pct,
                              );
                            }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      'Correlation',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    EntropyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Screen Time vs Focus',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Fetch last 7 days of metrics and overlay the
                          // server-computed baseline so drift is visible
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('baseline')
                                .doc('current')
                                .snapshots(),
                            builder: (context, baselineSnapshot) {
                              UserBaseline? baseline;
                              if (baselineSnapshot.hasData &&
                                  baselineSnapshot.data!.exists) {
                                baseline = UserBaseline.fromJson(
                                  baselineSnapshot.data!.data()
                                      as Map<String, dynamic>,
                                );
                              }
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(uid)
                                    .collection('sessions')
                                    .orderBy('startTime', descending: true)
                                    .limit(30)
                                    .snapshots(),
                                builder: (context, sessionSnapshot) {
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(uid)
                                        .collection('appUsage')
                                        .orderBy(
                                          FieldPath.documentId,
                                          descending: true,
                                        )
                                        .limit(7)
                                        .snapshots(),
                                    builder: (context, usageHistorySnapshot) {
                                      if (sessionSnapshot.hasError ||
                                          usageHistorySnapshot.hasError) {
                                        return _chartMessage(
                                          'Could not load telemetry.',
                                        );
                                      }
                                      if (!sessionSnapshot.hasData ||
                                          !usageHistorySnapshot.hasData) {
                                        return _chartLoading();
                                      }
                                      if (sessionSnapshot.data!.docs.isEmpty &&
                                          usageHistorySnapshot
                                              .data!
                                              .docs
                                              .isEmpty) {
                                        return _chartMessage(
                                          'No data yet — first day of tracking.',
                                        );
                                      }
                                      return _buildCorrelationChart(
                                        sessionSnapshot.data!.docs,
                                        usageHistorySnapshot.data!.docs,
                                        baseline,
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                    const Text(
                      'Usage Heatmap',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    EntropyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Day × Hour Intensity',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 24),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('appUsage')
                                .orderBy(FieldPath.documentId, descending: true)
                                .limit(7)
                                .snapshots(),
                            builder: (context, heatmapSnapshot) {
                              if (heatmapSnapshot.hasError) {
                                return _chartMessage(
                                  'Could not load telemetry.',
                                );
                              }
                              if (!heatmapSnapshot.hasData) {
                                return _chartLoading();
                              }
                              return _buildUsageHeatmap(
                                heatmapSnapshot.data!.docs,
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Latest drift alert from the Drift Analyzer, if any
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .collection('insights')
                          .orderBy('createdAt', descending: true)
                          .limit(20)
                          .snapshots(),
                      builder: (context, insightSnapshot) {
                        if (insightSnapshot.hasData) {
                          for (final doc in insightSnapshot.data!.docs) {
                            final insight = Insight.fromJson(
                              doc.id,
                              doc.data() as Map<String, dynamic>,
                            );
                            if (insight.type == 'drift') {
                              return InsightCard(
                                icon: Icons.warning_amber_rounded,
                                text: insight.text,
                                color: AppColors.warning,
                              );
                            }
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              );
            },
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
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartMessage(String text) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ),
    );
  }

  Widget _chartLoading() {
    return const SizedBox(
      height: 120,
      child: Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildUsageHeatmap(List<QueryDocumentSnapshot> usageDocs) {
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();

    // hourly minutes keyed by dateKey
    final Map<String, Map<String, dynamic>> hourlyByDay = {};
    for (final doc in usageDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final hourly = data['hourly'];
      if (hourly is Map) {
        hourlyByDay[doc.id] = Map<String, dynamic>.from(hourly);
      }
    }

    // 7 rows (oldest day first) x 24 hour columns
    final List<DateTime> days = List.generate(
      7,
      (i) => now.subtract(Duration(days: 6 - i)),
    );
    final matrix = List.generate(7, (_) => List.filled(24, 0.0));
    double maxCellValue = 0.0;

    for (int d = 0; d < 7; d++) {
      final hourly = hourlyByDay[formatter.format(days[d])];
      if (hourly == null) continue;
      for (int h = 0; h < 24; h++) {
        final val = (hourly['$h'] ?? 0.0).toDouble();
        matrix[d][h] = val;
        if (val > maxCellValue) maxCellValue = val;
      }
    }

    if (maxCellValue == 0.0) {
      return _chartMessage('No data yet — first day of tracking.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(7, (d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    DateFormat('E').format(days[d]).substring(0, 1),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...List.generate(24, (h) {
                  final val = matrix[d][h];
                  double opacity = 0.04;
                  if (val > 0) {
                    opacity = 0.04 + (val / maxCellValue) * 0.96;
                  }
                  return Expanded(
                    child: Tooltip(
                      message:
                          '${DateFormat('E').format(days[d])} ${h.toString().padLeft(2, '0')}:00 — ${val.toInt()}m',
                      child: Container(
                        height: 14,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: opacity),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 20),
            ...List.generate(4, (i) {
              return Expanded(
                child: Text(
                  '${(i * 6).toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildCorrelationChart(
    List<QueryDocumentSnapshot> sessionDocs,
    List<QueryDocumentSnapshot> usageDocs,
    UserBaseline? baseline,
  ) {
    // Map dates to metrics
    final Map<String, double> focusByDate = {};
    final Map<String, double> screenByDate = {};

    final DateFormat formatter = DateFormat('yyyy-MM-dd');

    // Parse sessions
    for (var doc in sessionDocs) {
      final session = Session.fromJson(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
      if (session.status == 'completed') {
        final dateKey = formatter.format(session.startTime);
        focusByDate[dateKey] =
            (focusByDate[dateKey] ?? 0.0) + session.focusLevel;
        // Keep track of counts for averaging later
      }
    }
    // We'll average the focus level per day
    final Map<String, int> sessionCounts = {};
    for (var doc in sessionDocs) {
      final session = Session.fromJson(
        doc.id,
        doc.data() as Map<String, dynamic>,
      );
      if (session.status == 'completed') {
        final dateKey = formatter.format(session.startTime);
        sessionCounts[dateKey] = (sessionCounts[dateKey] ?? 0) + 1;
      }
    }
    focusByDate.forEach((key, val) {
      focusByDate[key] =
          (val / sessionCounts[key]!) * 10; // Convert to percentage
    });

    // Parse usage
    for (var doc in usageDocs) {
      final dateKey = doc.id;
      final data = doc.data() as Map<String, dynamic>;
      final list = data['entries'] as List? ?? [];
      double dailyMinutes = 0;
      for (var item in list) {
        dailyMinutes += (item['durationMinutes'] ?? 0.0);
      }
      screenByDate[dateKey] = dailyMinutes / 60.0; // Convert to hours
    }

    // Get last 7 days sorted
    final List<String> last7Days = [];
    for (int i = 6; i >= 0; i--) {
      last7Days.add(
        formatter.format(DateTime.now().subtract(Duration(days: i))),
      );
    }

    final List<FlSpot> focusSpots = [];
    final List<FlSpot> screenSpots = [];

    for (int i = 0; i < 7; i++) {
      final date = last7Days[i];
      final double focus = focusByDate[date] ?? 50.0; // Default 50%
      final double screen = screenByDate[date] ?? 0.0;

      focusSpots.add(FlSpot(i.toDouble(), focus));
      screenSpots.add(
        FlSpot(i.toDouble(), screen * 10),
      ); // Scale screen time (0-10 hours) to (0-100)
    }

    // Baseline overlay: flat line at the user's average daily screen time,
    // on the same 0-10h -> 0-100 scale as the actual screen-time series
    List<FlSpot>? baselineSpots;
    if (baseline != null &&
        baseline.sampleDays > 0 &&
        baseline.dailyAvgUsageMinutes > 0) {
      final scaled = ((baseline.dailyAvgUsageMinutes / 60.0) * 10).clamp(
        0.0,
        100.0,
      );
      baselineSpots = List.generate(7, (i) => FlSpot(i.toDouble(), scaled));
    }

    return SizedBox(
      height: 150,
      child: LineChart(
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
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value % 20 == 0) {
                    return Text(
                      '${value.toInt()}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 8,
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 26,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < 7) {
                    final fullDate = last7Days[idx];
                    final parsed = formatter.parse(fullDate);
                    return Text(
                      DateFormat('E').format(parsed),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 9,
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 18,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: focusSpots,
              color: AppColors.accent,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
            LineChartBarData(
              spots: screenSpots,
              color: AppColors.warning,
              barWidth: 2,
              dotData: const FlDotData(show: true),
            ),
            if (baselineSpots != null)
              LineChartBarData(
                spots: baselineSpots,
                color: AppColors.textSecondary,
                barWidth: 2,
                dashArray: [4, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}
