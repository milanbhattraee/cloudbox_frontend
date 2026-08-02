import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('---> [1] App Started');

  try {
    debugPrint('---> [2] Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('---> [WARNING] Firebase initialization timed out!');
        throw Exception('Firebase initialization timed out after 5 seconds');
      },
    );
    debugPrint('---> [3] Firebase Initialized Successfully');
  } catch (e) {
    debugPrint('---> [ERROR] Firebase initialization error: $e');
  }

  debugPrint('---> [4] Launching CloudBoxApp UI...');
  runApp(const CloudBoxApp());
}
