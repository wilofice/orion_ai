import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import 'preferences_provider.dart';
import 'user_preferences.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PreferencesProvider>().loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefsProvider = context.watch<PreferencesProvider>();
    final connectivity = context.watch<ConnectivityService>();
    final prefs = prefsProvider.preferences ?? UserPreferences(darkMode: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Orion Preferences')),
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
          if (prefsProvider.isLoading)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: prefs.darkMode,
                    onChanged: (val) {
                      final updated = prefs.copyWith(darkMode: val);
                      prefsProvider.updatePreferences(updated);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
