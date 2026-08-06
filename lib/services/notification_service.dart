import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notifications with proper Android channel
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'sync_channel', // id
      'File Sync', // name
      description: 'Shows progress of file uploads and sync operations',
      importance: Importance.low,
      enableVibration: false,
      playSound: false,
      showBadge: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(androidChannel);
      debugPrint('[NotificationService] Android notification channel created');
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true; // Android doesn't need runtime permission for notifications
  }

  /// Show scanning started notification
  Future<void> showScanningStarted() async {
    const androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'File Sync',
      channelDescription: 'Background file synchronization',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1, // Notification ID
      '🔍 CloudBox - Scanning',
      'Scanning local files...',
      details,
    );
  }

  /// Update scanning progress
  Future<void> updateScanningProgress(int filesScanned) async {
    const androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'File Sync',
      channelDescription: 'Background file synchronization',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '🔍 CloudBox - Scanning',
      '$filesScanned files scanned...',
      details,
    );
  }

  /// Show sync started notification
  Future<void> showSyncStarted() async {
    const androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'File Sync',
      channelDescription: 'Background file synchronization',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      indeterminate: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1, // Notification ID
      '☁️ CloudBox - Uploading',
      'Preparing to upload files...',
      details,
    );
  }

  /// Update sync progress notification with percentage
  Future<void> updateSyncProgress(int current, int total) async {
    final percentage = total > 0 ? ((current / total) * 100).toInt() : 0;
    
    final androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'File Sync',
      channelDescription: 'Background file synchronization',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: percentage,
      icon: '@mipmap/ic_launcher',
      subText: '$percentage%',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '☁️ CloudBox - Uploading',
      'Uploading $current of $total files ($percentage%)',
      details,
    );
  }

  /// Show sync completed notification
  Future<void> showSyncCompleted(int filesUploaded) async {
    const androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'File Sync',
      channelDescription: 'Background file synchronization',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2, // Different ID for completed notification
      'Sync Complete',
      '✓ $filesUploaded files synced successfully',
      details,
    );

    // Clear the ongoing notification
    await _notifications.cancel(1);
  }

  /// Show sync error notification
  Future<void> showSyncError(String error) async {
    const androidDetails = AndroidNotificationDetails(
      'sync_channel',
      'File Sync',
      channelDescription: 'Background file synchronization',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      3,
      'Sync Failed',
      error,
      details,
    );

    // Clear the ongoing notification
    await _notifications.cancel(1);
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel sync notification
  Future<void> cancelSync() async {
    await _notifications.cancel(1);
  }
}
