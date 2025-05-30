import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import 'event_provider.dart';
import 'calendar_event.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final connectivity = context.watch<ConnectivityService>();

    Widget body;
    if (eventProvider.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (eventProvider.error != null) {
      body = Center(child: Text('Error: ${eventProvider.error}'));
    } else if (eventProvider.events.isEmpty) {
      body = const Center(child: Text('No events'));
    } else {
      body = ListView.builder(
        itemCount: eventProvider.events.length,
        itemBuilder: (context, index) {
          final CalendarEvent e = eventProvider.events[index];
          return ListTile(
            title: Text(e.title),
            subtitle: Text(
                '${e.startTime} - ${e.endTime}\n${e.location.isNotEmpty ? e.location : ''}'),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Orion Events')),
      body: Column(
        children: [
          if (!connectivity.isOnline)
            Container(
              width: double.infinity,
              color: Colors.orange,
              padding: const EdgeInsets.all(8),
              child: const Text('Offline mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: eventProvider.loadEvents,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}
