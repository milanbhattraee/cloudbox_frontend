import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:cloudbox_app/services/notification_service.dart';

/// Service that handles background sync using Foreground Task
/// This ensures sync continues even when app is backgrounded or screen is locked
class BackgroundSyncService {
  static final BackgroundSyncService instance = BackgroundSyncService._internal();
  BackgroundSyncService._internal();

  bool _isRunning = false;
  final StreamController<Map<String, dynamic>> _progressController = 
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream to monitor sync progress from UI
  Stream<Map<String, dynamic>> get progressStream => _progressController.stream;
  
  /// Initialize foreground task service
  Future<void> initialize() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cloudbox_sync',
        channelName: 'CloudBox Sync',
        channelDescription: 'Background file synchronization with progress',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(2000), // Update every 2 seconds
        autoRunOnBoot: false,
        allowWakeLock: true, // Keep CPU awake during sync
        allowWifiLock: false,
      ),
    );
    
    debugPrint('[BackgroundSyncService] Initialized');
  }

  /// Start foreground service to protect sync operations
  /// Returns true if service started successfully
  Future<bool> startForegroundService() async {
    if (_isRunning) {
      debugPrint('[BackgroundSyncService] Foreground service already running');
      return true;
    }

    try {
      // Request notification permission first
      await NotificationService.instance.initialize();
      await NotificationService.instance.requestPermissions();

      // Check if foreground service can start
      final isRunning = await FlutterForegroundTask.isRunningService;
      debugPrint('[BackgroundSyncService] Current service status: isRunning=$isRunning');
      
      if (!isRunning) {
        // Start foreground service
        debugPrint('[BackgroundSyncService] Starting foreground service...');
        final result = await FlutterForegroundTask.startService(
          serviceId: 256,
          notificationTitle: '☁️ CloudBox Sync',
          notificationText: 'Preparing to sync files...',
          callback: startCallback,
        );

        debugPrint('[BackgroundSyncService] Start result: ${result.runtimeType}');
        
        if (result is ServiceRequestFailure) {
          debugPrint('[BackgroundSyncService] Failed to start: ${result.error}');
          return false;
        }
        
        if (result is! ServiceRequestSuccess) {
          debugPrint('[BackgroundSyncService] Unexpected result type');
          return false;
        }
        
        debugPrint('[BackgroundSyncService] Service started successfully');
      }

      _isRunning = true;
      debugPrint('[BackgroundSyncService] Foreground service started');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[BackgroundSyncService] Exception starting service: $e');
      debugPrint('[BackgroundSyncService] Stack trace: $stackTrace');
      return false;
    }
  }

  /// Stop foreground service
  Future<void> stopForegroundService() async {
    if (!_isRunning) return;

    await FlutterForegroundTask.stopService();
    await NotificationService.instance.cancelSync();
    
    _isRunning = false;
    debugPrint('[BackgroundSyncService] Foreground service stopped');
  }

  /// Check if foreground service is running
  bool get isRunning => _isRunning;

  /// Update foreground service notification
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// Update progress (called from SmartSyncService)
  void updateProgress(Map<String, dynamic> progress) {
    _progressController.add(progress);
  }

  void dispose() {
    _progressController.close();
  }
}

/// Entry point for foreground task callback
/// This keeps the service alive but doesn't do heavy work
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(SyncTaskHandler());
}

/// Minimal task handler that just keeps the service alive
/// The actual sync work happens in the main isolate
class SyncTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('[SyncTaskHandler] Started at $timestamp');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // Periodic heartbeat to keep service alive
    // The actual progress updates come from SmartSyncService
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('[SyncTaskHandler] Destroyed at $timestamp');
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'cancel') {
      debugPrint('[SyncTaskHandler] Cancel button pressed');
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationPressed() {
    debugPrint('[SyncTaskHandler] Notification pressed');
    // Bring app to foreground
    FlutterForegroundTask.launchApp('/');
  }
}

