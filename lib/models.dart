import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String displayName;
  final String email;
  final DateTime createdAt;
  final String? fcmToken;

  UserProfile({
    required this.displayName,
    required this.email,
    required this.createdAt,
    this.fcmToken,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: json['fcmToken'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }
}

class UserSettings {
  final List<String> blockedApps;
  final bool onboardingComplete;
  final bool usagePermissionGranted;

  UserSettings({
    required this.blockedApps,
    required this.onboardingComplete,
    required this.usagePermissionGranted,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      blockedApps: List<String>.from(json['blockedApps'] ?? []),
      onboardingComplete: json['onboardingComplete'] ?? false,
      usagePermissionGranted: json['usagePermissionGranted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blockedApps': blockedApps,
      'onboardingComplete': onboardingComplete,
      'usagePermissionGranted': usagePermissionGranted,
    };
  }
}

class DriftEvent {
  final DateTime timestamp;
  final String appName;
  final String action; // "warned" | "ended"

  DriftEvent({
    required this.timestamp,
    required this.appName,
    required this.action,
  });

  factory DriftEvent.fromJson(Map<String, dynamic> json) {
    return DriftEvent(
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appName: json['appName'] ?? '',
      action: json['action'] ?? 'warned',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'appName': appName,
      'action': action,
    };
  }
}

class Session {
  final String id;
  final String taskName;
  final DateTime startTime;
  final DateTime? endTime;
  final double durationMinutes;
  final int focusLevel; // 1-10
  final int energyLevel; // 1-10
  final String mood; // emoji
  final String stopReason;
  final List<DriftEvent> driftEvents;
  final List<String> appsOpenedDuringSession;
  final String status; // "active" | "completed"

  Session({
    required this.id,
    required this.taskName,
    required this.startTime,
    this.endTime,
    required this.durationMinutes,
    required this.focusLevel,
    required this.energyLevel,
    required this.mood,
    required this.stopReason,
    required this.driftEvents,
    required this.appsOpenedDuringSession,
    required this.status,
  });

  factory Session.fromJson(String id, Map<String, dynamic> json) {
    return Session(
      id: id,
      taskName: json['taskName'] ?? '',
      startTime: (json['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (json['endTime'] as Timestamp?)?.toDate(),
      durationMinutes: (json['durationMinutes'] ?? 0.0).toDouble(),
      focusLevel: json['focusLevel'] ?? 5,
      energyLevel: json['energyLevel'] ?? 5,
      mood: json['mood'] ?? '😐',
      stopReason: json['stopReason'] ?? '',
      driftEvents: (json['driftEvents'] as List?)
              ?.map((e) => DriftEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      appsOpenedDuringSession: List<String>.from(json['appsOpenedDuringSession'] ?? []),
      status: json['status'] ?? 'completed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskName': taskName,
      'startTime': Timestamp.fromDate(startTime),
      if (endTime != null) 'endTime': Timestamp.fromDate(endTime!),
      'durationMinutes': durationMinutes,
      'focusLevel': focusLevel,
      'energyLevel': energyLevel,
      'mood': mood,
      'stopReason': stopReason,
      'driftEvents': driftEvents.map((e) => e.toJson()).toList(),
      'appsOpenedDuringSession': appsOpenedDuringSession,
      'status': status,
    };
  }
}

class AppUsageEntry {
  final String appName;
  final String packageName;
  final double durationMinutes;

  AppUsageEntry({
    required this.appName,
    required this.packageName,
    required this.durationMinutes,
  });

  factory AppUsageEntry.fromJson(Map<String, dynamic> json) {
    return AppUsageEntry(
      appName: json['appName'] ?? '',
      packageName: json['packageName'] ?? '',
      durationMinutes: (json['durationMinutes'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'appName': appName,
      'packageName': packageName,
      'durationMinutes': durationMinutes,
    };
  }
}

class UserBaseline {
  final double dailyAvgUsageMinutes;
  final List<double> hourlyAvgUsageMinutes; // 24 entries, index = hour of day
  final double avgFocusLevel;
  final double avgSessionMinutes;
  final double avgDriftEventsPerSession;
  final int sampleDays;
  final DateTime computedAt;

  UserBaseline({
    required this.dailyAvgUsageMinutes,
    required this.hourlyAvgUsageMinutes,
    required this.avgFocusLevel,
    required this.avgSessionMinutes,
    required this.avgDriftEventsPerSession,
    required this.sampleDays,
    required this.computedAt,
  });

  factory UserBaseline.fromJson(Map<String, dynamic> json) {
    final hourly = (json['hourlyAvgUsageMinutes'] as List?)
            ?.map((e) => (e ?? 0.0).toDouble() as double)
            .toList() ??
        List.filled(24, 0.0);
    return UserBaseline(
      dailyAvgUsageMinutes: (json['dailyAvgUsageMinutes'] ?? 0.0).toDouble(),
      hourlyAvgUsageMinutes: hourly.length == 24 ? hourly : List.filled(24, 0.0),
      avgFocusLevel: (json['avgFocusLevel'] ?? 0.0).toDouble(),
      avgSessionMinutes: (json['avgSessionMinutes'] ?? 0.0).toDouble(),
      avgDriftEventsPerSession: (json['avgDriftEventsPerSession'] ?? 0.0).toDouble(),
      sampleDays: json['sampleDays'] ?? 0,
      computedAt: (json['computedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dailyAvgUsageMinutes': dailyAvgUsageMinutes,
      'hourlyAvgUsageMinutes': hourlyAvgUsageMinutes,
      'avgFocusLevel': avgFocusLevel,
      'avgSessionMinutes': avgSessionMinutes,
      'avgDriftEventsPerSession': avgDriftEventsPerSession,
      'sampleDays': sampleDays,
      'computedAt': Timestamp.fromDate(computedAt),
    };
  }
}

class Insight {
  final String id;
  final String icon; // "warning" | "lightbulb" | "info"
  final String text;
  final DateTime createdAt;
  final String type; // "post_session" | "weekly"

  Insight({
    required this.id,
    required this.icon,
    required this.text,
    required this.createdAt,
    required this.type,
  });

  factory Insight.fromJson(String id, Map<String, dynamic> json) {
    return Insight(
      id: id,
      icon: json['icon'] ?? 'info',
      text: json['text'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: json['type'] ?? 'post_session',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'icon': icon,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'type': type,
    };
  }
}

class WeeklyPlan {
  final String weekId; // ISO week e.g. "2024-W03"
  final DateTime generatedAt;
  final String summary;
  final List<String> recommendations;

  WeeklyPlan({
    required this.weekId,
    required this.generatedAt,
    required this.summary,
    required this.recommendations,
  });

  factory WeeklyPlan.fromJson(String weekId, Map<String, dynamic> json) {
    return WeeklyPlan(
      weekId: weekId,
      generatedAt: (json['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      summary: json['summary'] ?? '',
      recommendations: List<String>.from(json['recommendations'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generatedAt': Timestamp.fromDate(generatedAt),
      'summary': summary,
      'recommendations': recommendations,
    };
  }
}
