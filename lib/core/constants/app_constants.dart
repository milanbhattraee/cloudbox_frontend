class AppConstants {
  AppConstants._();

  static const String appName = 'CloudBox';

  /// Value used to mean "top-level" for both folders and files, matching
  /// the backend's convention (folderId=root <=> null in the DB).
  static const String rootFolderId = 'root';
}
