import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/connectivity_service.dart';

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
    // Continue anyway - connectivity service will handle server checks
  }

  // Initialize connectivity service
  debugPrint('---> [4] Initializing Connectivity Service...');
  ConnectivityService.instance;

  debugPrint('---> [5] Launching CloudBoxApp UI...');
  runApp(const CloudBoxApp());
}
