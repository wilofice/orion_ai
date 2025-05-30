import 'package:flutter/material.dart';
import '../services/calendar_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import 'calendar_event.dart';
import 'events_response.dart';

class EventProvider with ChangeNotifier {
  final CalendarService _calendarService;
  final CacheService _cacheService;
  final ConnectivityService _connectivityService;

  bool _isLoading = false;
  String? _error;
  List<CalendarEvent> _events = [];

  EventProvider({
    required CalendarService calendarService,
    required CacheService cacheService,
    required ConnectivityService connectivityService,
  })  : _calendarService = calendarService,
        _cacheService = cacheService,
        _connectivityService = connectivityService;

  List<CalendarEvent> get events => List.unmodifiable(_events);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadEvents() async {
    _isLoading = true;
    notifyListeners();

    if (_connectivityService.isOnline) {
      try {
        final EventsResponse response =
            await _calendarService.fetchUpcomingEvents();
        _events = response.events;
        await _cacheService.saveList(
            'events', _events.map((e) => e.toJson()).toList());
        _error = null;
      } catch (e) {
        _error = e.toString();
      }
    } else {
      final cached = await _cacheService.getList('events');
      _events =
          cached.map((e) => CalendarEvent.fromJson(e)).toList();
    }

    _isLoading = false;
    notifyListeners();
  }
}
