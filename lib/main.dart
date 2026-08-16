import 'package:flutter/material.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/background_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('---> [1] App Started');

  // Initialize background services
  _initializeBackgroundServices();

  debugPrint('---> [2] Launching CloudBoxApp UI...');
  runApp(const CloudBoxApp());
}

/// Initialize background services
Future<void> _initializeBackgroundServices() async {
  // Wait a bit for the app to render first
  await Future.delayed(const Duration(milliseconds: 500));
  
  debugPrint('---> [3] Initializing Notification Service...');
  try {
    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermissions();
    debugPrint('---> [4] Notification Service Initialized');
  } catch (e) {
    debugPrint('---> [WARNING] Notification initialization error: $e');
  }

  debugPrint('---> [5] Initializing Background Sync Service...');
  try {
    await BackgroundSyncService.instance.initialize();
    debugPrint('---> [6] Background Sync Service Ready');
  } catch (e) {
    debugPrint('---> [WARNING] Background sync initialization error: $e');
  }
}
