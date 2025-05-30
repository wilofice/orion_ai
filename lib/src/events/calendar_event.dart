class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final String description;
  final String location;
  final List<String> attendees;
  final bool isAllDay;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description = '',
    this.location = '',
    this.attendees = const [],
    this.isAllDay = false,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      startTime: DateTime.parse(json['start_time'] ?? json['start'] ?? ''),
      endTime: DateTime.parse(json['end_time'] ?? json['end'] ?? ''),
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      attendees: (json['attendees'] as List<dynamic>?)?.cast<String>() ?? const [],
      isAllDay: json['is_all_day'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'description': description,
        'location': location,
        'attendees': attendees,
        'is_all_day': isAllDay,
      };
}
