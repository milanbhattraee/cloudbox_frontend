import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Firebase is initialized from Dart (Firebase.initializeApp in main.dart)
    // using firebase_options.dart, so no native FirebaseApp.configure() call
    // is needed here - just make sure GoogleService-Info.plist is added to
    // the Runner target in Xcode (see README > "iOS setup").
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
