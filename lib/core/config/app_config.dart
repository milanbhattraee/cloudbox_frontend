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
    defaultValue: 'http://127.0.0.1:8080/api',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  // Uploads/downloads can legitimately take a while for large files.
  static const Duration sendTimeout = Duration(minutes: 5);

  static const int defaultPageSize = 30;
}
