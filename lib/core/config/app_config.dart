/// Central place for environment-dependent configuration.
///
/// Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:5000/api
///
/// Defaults to 10.0.2.2, which is how the Android *emulator* reaches
/// "localhost" on your development machine. If you're running on a real
/// device, use your machine's LAN IP instead (e.g. http://192.168.1.50:5000/api),
/// and make sure CLIENT_ORIGIN / firewall rules on the backend allow it.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Use your computer's local IP for physical devices
    // 192.168.1.126 = your computer's IP on the local network
    defaultValue: 'http://192.168.3.170:8080/api',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
  // Uploads/downloads can legitimately take a while for large files.
  static const Duration sendTimeout = Duration(minutes: 3);

  static const int defaultPageSize = 30;
}
