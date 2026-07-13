import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

/// Debug-only synthetic data tools so charts and the Drift Analyzer can be
/// tested without waiting days for real telemetry. Enabled with:
///   flutter run --dart-define=SEED_TOOLS=true
/// The seed menu (flask icon on the Insights page) is invisible otherwise.
const bool kSeedToolsEnabled = bool.fromEnvironment('SEED_TOOLS');

class DebugSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final Random _rng = Random();
  static final DateFormat _formatter = DateFormat('yyyy-MM-dd');

  static const _apps = [
    {'appName': 'Instagram', 'packageName': 'com.instagram.android'},
    {'appName': 'YouTube', 'packageName': 'com.google.android.youtube'},
    {'appName': 'Chrome', 'packageName': 'com.android.chrome'},
    {'appName': 'WhatsApp', 'packageName': 'com.whatsapp'},
    {'appName': 'Spotify', 'packageName': 'com.spotify.music'},
  ];

  /// Seeds [days] days of ordinary sessions + app usage ending today.
  static Future<void> seedHistory(String uid, int days) async {
    final batch = _db.batch();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    for (int i = 0; i < days; i++) {
      final day = todayStart.subtract(Duration(days: i));
      _seedUsage(batch, uid, day, drift: false);
      _seedSessions(batch, uid, day, drift: false);
    }
    await batch.commit();
  }

  /// Turns today into a synthetic drift day (usage spike, late-night usage,
  /// low-focus session with repeated drift events) and invokes the Drift
  /// Analyzer function so the warning insight lands in Firestore.
  static Future<bool> seedDriftTodayAndAnalyze(String uid) async {
    final batch = _db.batch();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    _seedUsage(batch, uid, todayStart, drift: true);
    final sessionId = _seedSessions(batch, uid, todayStart, drift: true);
    await batch.commit();

    final callable = FirebaseFunctions.instance.httpsCallable('analyzeDriftSession');
    final result = await callable.call({'uid': uid, 'sessionId': sessionId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['driftDetected'] == true;
  }

  static void _seedUsage(WriteBatch batch, String uid, DateTime day, {required bool drift}) {
    final entries = <Map<String, dynamic>>[];
    double total = 0;
    for (final app in _apps) {
      final mins = drift ? 90.0 + _rng.nextInt(60) : 20.0 + _rng.nextInt(40);
      entries.add({...app, 'durationMinutes': mins});
      total += mins;
    }

    // Spread the daily total across waking hours (plus 00:00-03:00 on a
    // drift day) with random weights.
    final hours = <int>[
      if (drift) ...[0, 1, 2, 3],
      for (int h = 9; h <= 23; h++) h,
    ];
    final weights = hours.map((_) => 0.2 + _rng.nextDouble()).toList();
    final weightSum = weights.fold<double>(0.0, (a, b) => a + b);
    final hourly = <String, double>{};
    for (int i = 0; i < hours.length; i++) {
      double mins = total * weights[i] / weightSum;
      // Guarantee heavy late-night buckets on a drift day
      if (drift && hours[i] < 4) mins = 20.0 + _rng.nextInt(15);
      hourly['${hours[i]}'] = double.parse(mins.toStringAsFixed(1));
    }

    batch.set(
      _db.collection('users').doc(uid).collection('appUsage').doc(_formatter.format(day)),
      {'entries': entries, 'hourly': hourly},
      SetOptions(merge: true),
    );
  }

  /// Seeds 1-3 sessions for [day]; returns the id of the last one.
  static String _seedSessions(WriteBatch batch, String uid, DateTime day, {required bool drift}) {
    final sessions = _db.collection('users').doc(uid).collection('sessions');
    final count = drift ? 1 : 2 + _rng.nextInt(2);
    String lastId = '';

    for (int s = 0; s < count; s++) {
      final start = day.add(Duration(hours: 9 + s * 4, minutes: _rng.nextInt(50)));
      final durationMinutes = drift ? 18.0 : 30.0 + _rng.nextInt(60);
      final end = start.add(Duration(minutes: durationMinutes.toInt()));
      final focus = drift ? 2 : 6 + _rng.nextInt(3);

      final driftEvents = <Map<String, dynamic>>[];
      final driftCount = drift ? 3 : (_rng.nextInt(3) == 0 ? 1 : 0);
      for (int d = 0; d < driftCount; d++) {
        driftEvents.add({
          'timestamp': Timestamp.fromDate(start.add(Duration(minutes: 5 + d * 4))),
          'appName': 'instagram',
          'action': 'warned',
        });
      }

      final doc = sessions.doc();
      lastId = doc.id;
      batch.set(doc, {
        'taskName': drift ? 'Deep work attempt' : 'Focus Session',
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'durationMinutes': durationMinutes,
        'focusLevel': focus,
        'energyLevel': drift ? 3 : 5 + _rng.nextInt(4),
        'mood': drift ? '😔' : '🙂',
        'stopReason': drift ? 'Distracted' : 'Done',
        'driftEvents': driftEvents,
        'appsOpenedDuringSession': drift ? ['Instagram', 'YouTube'] : <String>[],
        'status': 'completed',
      });
    }
    return lastId;
  }
}
