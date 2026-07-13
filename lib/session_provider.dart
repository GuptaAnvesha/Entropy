import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'models.dart';

class SessionProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const _usageChannel = MethodChannel('entropy/usage_stats');
  static const _focusEventsChannel = EventChannel('entropy/focus_events');

  bool isCheckedIn = false;
  DateTime? checkInTime;
  String? currentSessionId;
  String? currentAppName; // live foreground app during a session
  int elapsedSeconds = 0;
  Timer? _timer;
  Timer? _flushTimer;
  String? _uid;

  // Flush locally-accumulated usage to Firestore at most once per interval
  // (never on the 4s poll ticks).
  static const _flushInterval = Duration(seconds: 60);

  // Stream to notify UI of drift events
  final StreamController<Map<String, dynamic>> _driftEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get driftEventsStream =>
      _driftEventController.stream;

  StreamSubscription? _eventSubscription;

  // Native channels and local notifications only exist on Android.
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  SessionProvider() {
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (!_isAndroid) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> checkIn(String uid, List<String> blockedApps) async {
    if (isCheckedIn) return;

    checkInTime = DateTime.now();
    elapsedSeconds = 0;
    isCheckedIn = true;
    _uid = uid;
    currentAppName = null;

    // Create session doc in Firestore
    final docRef = _db
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc();
    currentSessionId = docRef.id;

    final session = Session(
      id: docRef.id,
      taskName: 'Focus Session', // Pre-fill with default task name
      startTime: checkInTime!,
      durationMinutes: 0.0,
      focusLevel: 5,
      energyLevel: 5,
      mood: '😐',
      stopReason: '',
      driftEvents: [],
      appsOpenedDuringSession: [],
      status: 'active',
    );

    await docRef.set(session.toJson());

    // Start native service on Android
    if (_isAndroid) {
      try {
        await _usageChannel.invokeMethod('startFocusService', {
          'blockedApps': blockedApps,
        });
      } catch (e) {
        debugPrint("Error starting foreground service: $e");
      }

      // Start listening to the EventChannel
      _eventSubscription = _focusEventsChannel.receiveBroadcastStream().listen((
        data,
      ) {
        final map = Map<String, dynamic>.from(data);
        if (map['event'] == 'current_app') {
          currentAppName = map['appName'] ?? map['package'];
          notifyListeners();
        }
        _driftEventController.add(map);
      });

      // Periodically persist the usage accumulated natively
      _flushTimer = Timer.periodic(_flushInterval, (_) => flushSessionUsage());
    }

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });

    _showTimerNotification();
    notifyListeners();
  }

  Future<void> checkOut() async {
    if (!isCheckedIn) return;

    _timer?.cancel();
    _timer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _eventSubscription?.cancel();
    _eventSubscription = null;

    if (_isAndroid) {
      // Final flush of the session's accumulated usage before shutdown
      await flushSessionUsage();
      try {
        await _usageChannel.invokeMethod('stopFocusService');
      } catch (e) {
        debugPrint("Error stopping foreground service: $e");
      }
    }

    isCheckedIn = false;
    currentAppName = null;
    if (_isAndroid) _notificationsPlugin.cancel(9999);
    notifyListeners();
  }

  /// Reads the per-app, per-hour usage accumulated by the native service and
  /// writes it to Firestore in a single batch. Doc ids are deterministic
  /// (session + app + day + hour), so repeated flushes overwrite the same
  /// docs with the growing totals instead of duplicating them. The commit is
  /// not awaited: Firestore queues it locally when offline.
  Future<void> flushSessionUsage() async {
    if (_uid == null || currentSessionId == null || !_isAndroid) return;
    try {
      final List<dynamic>? usage = await _usageChannel.invokeMethod(
        'getSessionUsage',
      );
      if (usage == null || usage.isEmpty) return;

      final batch = _db.batch();
      final appNames = <String>{};
      for (final item in usage) {
        final map = Map<String, dynamic>.from(item);
        final pkg = map['packageName'] ?? '';
        final dateKey = map['dateKey'] ?? '';
        final hour = map['hour'] ?? 0;
        final appName = map['appName'] ?? pkg;
        appNames.add(appName);

        final ref = _db
            .collection('users')
            .doc(_uid)
            .collection('usageSessions')
            .doc('${currentSessionId}_${pkg}_${dateKey}_$hour');
        batch.set(ref, {
          'sessionId': currentSessionId,
          'packageName': pkg,
          'appName': appName,
          'dateKey': dateKey,
          'hour': hour,
          'durationMinutes': (map['durationMinutes'] ?? 0.0).toDouble(),
          'sessionStart': Timestamp.fromDate(checkInTime ?? DateTime.now()),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final sessionRef = _db
          .collection('users')
          .doc(_uid)
          .collection('sessions')
          .doc(currentSessionId);
      batch.update(sessionRef, {'appsOpenedDuringSession': appNames.toList()});

      batch.commit().catchError((e) {
        debugPrint("Usage flush commit failed (will retry next flush): $e");
      });
    } catch (e) {
      debugPrint("Error flushing session usage: $e");
    }
  }

  Future<void> logDriftEvent(String uid, String appName, String action) async {
    if (currentSessionId == null) return;
    final docRef = _db
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(currentSessionId);

    final event = DriftEvent(
      timestamp: DateTime.now(),
      appName: appName,
      action: action,
    );

    await docRef.update({
      'driftEvents': FieldValue.arrayUnion([event.toJson()]),
      if (action == 'ended') 'status': 'completed',
      if (action == 'ended') 'endTime': Timestamp.fromDate(DateTime.now()),
    });
  }

  void _tick() {
    elapsedSeconds++;
    _showTimerNotification();
    notifyListeners();
  }

  Future<void> _showTimerNotification() async {
    if (!_isAndroid) return;
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');

    final androidDetails = AndroidNotificationDetails(
      'session_timer_channel',
      'Focus Session Timer',
      channelDescription: 'Shows active focus session timer',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showWhen: false,
    );
    final platformDetails = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      9999,
      'Focus Session Running',
      'Time elapsed: $minutes:$seconds',
      platformDetails,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flushTimer?.cancel();
    _eventSubscription?.cancel();
    _driftEventController.close();
    super.dispose();
  }
}
