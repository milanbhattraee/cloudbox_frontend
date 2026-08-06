import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('---> [1] App Started');

  try {
    debugPrint('---> [2] Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('---> [WARNING] Firebase initialization timed out!');
        throw Exception('Firebase initialization timed out after 10 seconds');
      },
    );
    debugPrint('---> [3] Firebase Initialized Successfully');
  } catch (e) {
    debugPrint('---> [ERROR] Firebase initialization error: $e');
    // Continue anyway - app works offline
  }

  debugPrint('---> [4] Launching CloudBoxApp UI...');
  runApp(const CloudBoxApp());
  
  // Defer non-critical initialization to after app starts
  _initializeBackgroundServices();
}

/// Initialize background services after app launches to improve startup time
Future<void> _initializeBackgroundServices() async {
  // Wait a bit for the app to render first
  await Future.delayed(const Duration(milliseconds: 500));
  
  debugPrint('---> [5] Initializing Notification Service (deferred)...');
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();
    debugPrint('---> [6] Notification Service Initialized');
  } catch (e) {
    debugPrint('---> [WARNING] Notification initialization error: $e');
  }

  debugPrint('---> [7] Initializing Background Sync Service (deferred)...');
  try {
    await BackgroundSyncService.instance.initialize();
    // Only schedule periodic sync if auto-sync is enabled in settings
    // This will be managed by the sync settings screen
    debugPrint('---> [8] Background Sync Service Ready');
  } catch (e) {
    debugPrint('---> [WARNING] Background sync initialization error: $e');
  }
}
