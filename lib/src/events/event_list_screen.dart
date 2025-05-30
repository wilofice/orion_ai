import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import 'event_provider.dart';
import 'calendar_event.dart';
import 'package:intl/intl.dart';

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
          final time =
              '${DateFormat.yMMMd().add_jm().format(e.startTime)} - ${DateFormat.jm().format(e.endTime)}';
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(time),
                  if (e.location.isNotEmpty) Text(e.location),
                ],
              ),
            ),
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
