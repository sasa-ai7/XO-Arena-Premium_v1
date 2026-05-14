import 'package:flutter/material.dart';

import '../core/app_l10n.dart';
import '../services/local_store.dart';

/// Simple maintenance screen shown when app encounters an error.
class MaintenanceScreen extends StatelessWidget {
  const MaintenanceScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n(LocalStore.localeNotifier.value.languageCode);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.build,
                    size: 80,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.underMaintenance,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.underMaintenanceDesc,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool shouldShowMaintenanceScreen(Object error) {
  final msg = error.toString().toLowerCase();
  if (msg.contains('missingpluginexception') ||
      msg.contains('platformexception')) {
    return false;
  }
  if (msg.contains('socket') ||
      msg.contains('network') ||
      msg.contains('timeout') ||
      msg.contains('host lookup') ||
      msg.contains('connection')) {
    return false;
  }
  if (msg.contains('permission') ||
      msg.contains('firestore') ||
      msg.contains('firebase') ||
      msg.contains('auth') ||
      msg.contains('500') ||
      msg.contains('502') ||
      msg.contains('503')) {
    return false;
  }
  if (msg.contains('parsing') ||
      msg.contains('parse') ||
      msg.contains('malformed')) {
    return false;
  }
  if (msg.contains('binding') ||
      msg.contains('flutter error') ||
      msg.contains('assertion')) {
    return true;
  }
  return false;
}

