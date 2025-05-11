import 'package:flutter/material.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orion Preferences')),
      body: const Center(child: Text('Preferences Screen - Placeholder')),
    );
  }
}