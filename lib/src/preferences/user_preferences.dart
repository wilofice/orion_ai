class TimeWindow {
  final String start;
  final String end;

  TimeWindow({required this.start, required this.end});

  factory TimeWindow.fromJson(Map<String, dynamic> json) {
    return TimeWindow(
      start: json['start'] as String? ?? '',
      end: json['end'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
      };
}

class UserPreferences {
  final String userId;
  final String timeZone;
  final Map<String, TimeWindow> workingHours;
  final List<TimeWindow> preferredMeetingTimes;
  final List<String> daysOff;
  final int preferredBreakDurationMinutes;
  final int workBlockMaxDurationMinutes;
  final int createdAt;
  final int updatedAt;
  final bool darkMode;

  UserPreferences({
    required this.userId,
    required this.timeZone,
    required this.workingHours,
    required this.preferredMeetingTimes,
    required this.daysOff,
    required this.preferredBreakDurationMinutes,
    required this.workBlockMaxDurationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.darkMode = false,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    final wh = <String, TimeWindow>{};
    if (json['working_hours'] is Map<String, dynamic>) {
      (json['working_hours'] as Map<String, dynamic>).forEach((k, v) {
        if (v is Map<String, dynamic>) {
          wh[k] = TimeWindow.fromJson(v);
        }
      });
    }
    return UserPreferences(
      userId: json['user_id'] as String? ?? '',
      timeZone: json['time_zone'] as String? ?? '',
      workingHours: wh,
      preferredMeetingTimes:
          (json['preferred_meeting_times'] as List<dynamic>? ?? [])
              .map((e) => TimeWindow.fromJson(e as Map<String, dynamic>))
              .toList(),
      daysOff: (json['days_off'] as List<dynamic>? ?? []).cast<String>(),
      preferredBreakDurationMinutes:
          json['preferred_break_duration_minutes'] as int? ?? 0,
      workBlockMaxDurationMinutes:
          json['work_block_max_duration_minutes'] as int? ?? 0,
      createdAt: json['created_at'] as int? ?? 0,
      updatedAt: json['updated_at'] as int? ?? 0,
      darkMode: json['darkMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toBackendJson() => {
        'user_id': userId,
        'time_zone': timeZone,
        'working_hours':
            workingHours.map((k, v) => MapEntry(k, v.toJson())),
        'preferred_meeting_times':
            preferredMeetingTimes.map((e) => e.toJson()).toList(),
        'days_off': daysOff,
        'preferred_break_duration_minutes': preferredBreakDurationMinutes,
        'work_block_max_duration_minutes': workBlockMaxDurationMinutes,
      };

  Map<String, dynamic> toJson() => {
        ...toBackendJson(),
        'created_at': createdAt,
        'updated_at': updatedAt,
        'darkMode': darkMode,
      };

  UserPreferences copyWith({bool? darkMode, String? timeZone}) {
    return UserPreferences(
      userId: userId,
      timeZone: timeZone ?? this.timeZone,
      workingHours: workingHours,
      preferredMeetingTimes: preferredMeetingTimes,
      daysOff: daysOff,
      preferredBreakDurationMinutes: preferredBreakDurationMinutes,
      workBlockMaxDurationMinutes: workBlockMaxDurationMinutes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
