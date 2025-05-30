import 'calendar_event.dart';

class EventsResponse {
  final String userId;
  final List<CalendarEvent> events;
  final Map<String, DateTime> timeRange;
  final int totalEvents;

  EventsResponse({
    required this.userId,
    required this.events,
    required this.timeRange,
    required this.totalEvents,
  });

  factory EventsResponse.fromJson(Map<String, dynamic> json) {
    final range = <String, DateTime>{};
    if (json['time_range'] is Map<String, dynamic>) {
      json['time_range'].forEach((key, value) {
        if (value is String) {
          range[key] = DateTime.parse(value);
        }
      });
    }
    return EventsResponse(
      userId: json['user_id'] as String? ?? '',
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeRange: range,
      totalEvents: json['total_events'] as int? ?? 0,
    );
  }
}
