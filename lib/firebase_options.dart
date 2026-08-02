// GENERATED PLACEHOLDER - DO NOT USE AS-IS.
//
// This file normally comes from running the FlutterFire CLI:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
// which overwrites this file with real values matching your Firebase
// project (the SAME project your backend's Firebase Admin SDK talks to),
// for every platform you select (Android, iOS, Web).
//
// The placeholder values below let the app *compile* on all three
// platforms, but every Firebase Auth call will fail until you regenerate
// this file. See README.md > "Firebase setup" for full instructions.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are only configured for Android, iOS, and '
          'Web in this project. Run `flutterfire configure` to add more.',
        );
    }
  }

  // Web app config: Firebase Console > Project settings > Your apps > Web app.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project-id',
    authDomain: 'your-firebase-project-id.firebaseapp.com',
    storageBucket: 'your-firebase-project-id.appspot.com',
  );

  // Android app config: Firebase Console > Project settings > Your apps >
  // Android app (package name com.cloudbox.app). Matches
  // android/app/google-services.json.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
  );

  // iOS app config: Firebase Console > Project settings > Your apps > iOS
  // app (bundle ID com.cloudbox.app). Matches ios/Runner/GoogleService-Info.plist.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'your-firebase-project-id',
    storageBucket: 'your-firebase-project-id.appspot.com',
    iosBundleId: 'com.cloudbox.app',
  );
}
