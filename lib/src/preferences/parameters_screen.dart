import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import 'preferences_provider.dart';
import 'user_preferences.dart';
import '../auth/auth_provider.dart';
import 'package:go_router/go_router.dart';

const List<String> _timeZones = [
  'UTC',
  'America/New_York',
  'Europe/London',
  'Europe/Berlin',
  'Asia/Tokyo'
];

class ParametersScreen extends StatefulWidget {
  const ParametersScreen({super.key});

  @override
  State<ParametersScreen> createState() => _ParametersScreenState();
}

class _ParametersScreenState extends State<ParametersScreen> {
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
    final prefs = prefsProvider.preferences;

    return Scaffold(
      appBar: AppBar(title: const Text('Orion Parameters')),
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
          else if (prefs == null)
            const Expanded(child: Center(child: Text('No preferences')))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: prefs.darkMode,
                    onChanged: (val) {
                      final updated = prefs.copyWith(darkMode: val);
                      prefsProvider.updatePreferences(updated);
                    },
                  ),
                  ListTile(
                    title: const Text('Input Mode'),
                    subtitle: Text(prefs.inputMode.name),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final selected = await showDialog<InputMode>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Select Input Mode'),
                          children: InputMode.values
                              .map((m) => SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, m),
                                    child: Text(m.name),
                                  ))
                              .toList(),
                        ),
                      );
                      if (selected != null) {
                        prefsProvider.updatePreferences(
                          prefs.copyWith(inputMode: selected),
                        );
                      }
                    },
                  ),
                  if (prefs.inputMode == InputMode.both)
                    ListTile(
                      title: const Text('Voice Button Position'),
                      subtitle: Text(prefs.voiceButtonPosition.name),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final selected = await showDialog<VoiceButtonPosition>(
                          context: context,
                          builder: (context) => SimpleDialog(
                            title: const Text('Select Button Position'),
                            children: VoiceButtonPosition.values
                                .map((p) => SimpleDialogOption(
                                      onPressed: () => Navigator.pop(context, p),
                                      child: Text(p.name),
                                    ))
                                .toList(),
                          ),
                        );
                        if (selected != null) {
                          prefsProvider.updatePreferences(
                            prefs.copyWith(voiceButtonPosition: selected),
                          );
                        }
                      },
                    ),
                  ListTile(
                    title: const Text('Time Zone'),
                    subtitle: Text(prefs.timeZone.isEmpty ? 'Select' : prefs.timeZone),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      final selected = await showDialog<String>(
                        context: context,
                        builder: (context) => SimpleDialog(
                          title: const Text('Select Time Zone'),
                          children: _timeZones
                              .map((tz) => SimpleDialogOption(
                                    onPressed: () => Navigator.pop(context, tz),
                                    child: Text(tz),
                                  ))
                              .toList(),
                        ),
                      );
                      if (selected != null && selected.isNotEmpty) {
                        prefsProvider.updatePreferences(
                          prefs.copyWith(timeZone: selected),
                        );
                      }
                    },
                  ),
                  ...prefs.workingHours.entries.map(
                    (e) => ListTile(
                      title: Text('Working Hours ${e.key}'),
                      subtitle: Text('${e.value.start} - ${e.value.end}'),
                    ),
                  ),
                  if (prefs.daysOff.isNotEmpty)
                    ListTile(
                      title: const Text('Days Off'),
                      subtitle: Text(prefs.daysOff.join(', ')),
                    ),
                  const SizedBox(height: 20),
                  if (!context.watch<AuthProvider>().isAuthenticated)
                    ElevatedButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Login'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
