import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/background_sync_service.dart';
import 'file_service.dart';
import 'notification_service.dart';

enum SyncState {
  idle,
  scanning,
  comparing,
  uploading,
  downloading,
  completed,
  paused,
  error,
}

class SyncProgress {
  final int totalFiles;
  final int scannedFiles;
  final int uploadedFiles;
  final int downloadedFiles;
  final int conflictFiles;
  final int failedFiles;
  final SyncState state;
  final String? currentFile;
  final String? errorMessage;

  SyncProgress({
    this.totalFiles = 0,
    this.scannedFiles = 0,
    this.uploadedFiles = 0,
    this.downloadedFiles = 0,
    this.conflictFiles = 0,
    this.failedFiles = 0,
    this.state = SyncState.idle,
    this.currentFile,
    this.errorMessage,
  });

  SyncProgress copyWith({
    int? totalFiles,
    int? scannedFiles,
    int? uploadedFiles,
    int? downloadedFiles,
    int? conflictFiles,
    int? failedFiles,
    SyncState? state,
    String? currentFile,
    String? errorMessage,
  }) {
    return SyncProgress(
      totalFiles: totalFiles ?? this.totalFiles,
      scannedFiles: scannedFiles ?? this.scannedFiles,
      uploadedFiles: uploadedFiles ?? this.uploadedFiles,
      downloadedFiles: downloadedFiles ?? this.downloadedFiles,
      conflictFiles: conflictFiles ?? this.conflictFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      state: state ?? this.state,
      currentFile: currentFile ?? this.currentFile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  double get progress {
    if (totalFiles == 0) return 0;
    return (uploadedFiles + downloadedFiles) / totalFiles;
  }
}

class SmartSyncService extends ChangeNotifier {
  SmartSyncService._internal();
  static final SmartSyncService instance = SmartSyncService._internal();

  final FileService _fileService = FileService();
  Timer? _syncTimer;
  bool _isInitialized = false;
  String? _deviceId;
  
  SyncProgress _progress = SyncProgress();
  Map<String, dynamic>? _settings;
  Map<String, String> _localFileHashes = {}; // path -> hash
  Map<String, dynamic> _serverFiles = {}; // hash -> file metadata

  SyncProgress get progress => _progress;
  Map<String, dynamic>? get settings => _settings;
  bool get isSyncing => _progress.state != SyncState.idle && 
                        _progress.state != SyncState.completed &&
                        _progress.state != SyncState.paused;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    debugPrint('[SmartSync] Initializing...');
    
    // Generate or load device ID
    _deviceId = await _getDeviceId();
    
    await getSyncSettings();
    
    // Start auto-sync only if both enabled AND autoSync are true
    // Disabled by default to prevent freezing
    if (_settings?['syncEnabled'] == true && _settings?['autoSync'] == true) {
      debugPrint('[SmartSync] Auto-sync is enabled, starting timer...');
      _startAutoSync();
    } else {
      debugPrint('[SmartSync] Auto-sync is disabled (enable in settings)');
    }
    
    _isInitialized = true;
  }
  
  /// Manually enable/disable auto-sync
  void setAutoSync(bool enabled) {
    if (enabled) {
      _startAutoSync();
    } else {
      _stopAutoSync();
    }
  }

  /// Get or generate a unique device ID (persisted across app restarts)
  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('cloudbox_device_id');
    
    if (_deviceId == null) {
      // Generate new device ID
      _deviceId = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('cloudbox_device_id', _deviceId!);
      debugPrint('[SmartSync] Generated new device ID: $_deviceId');
    } else {
      debugPrint('[SmartSync] Loaded existing device ID: $_deviceId');
    }
    
    return _deviceId!;
  }

  /// Get sync settings from server
  Future<Map<String, dynamic>?> getSyncSettings() async {
    try {
      final response = await ApiClient.instance.dio.get('/sync/settings');
      _settings = response.data['data']['settings'] as Map<String, dynamic>;
      notifyListeners();
      return _settings;
    } catch (e) {
      debugPrint('[SmartSync] Failed to get settings: $e');
      return null;
    }
  }

  /// Update sync settings on server
  Future<bool> updateSyncSettings({
    bool? syncEnabled,
    bool? syncDocuments,
    bool? syncDownloads,
    bool? syncPictures,
    bool? syncVideos,
    bool? syncMusic,
    bool? syncOnWifiOnly,
    bool? autoSync,
  }) async {
    try {
      final response = await ApiClient.instance.dio.post(
        '/sync/settings',
        data: {
          if (syncEnabled != null) 'syncEnabled': syncEnabled,
          if (syncDocuments != null) 'syncDocuments': syncDocuments,
          if (syncDownloads != null) 'syncDownloads': syncDownloads,
          if (syncPictures != null) 'syncPictures': syncPictures,
          if (syncVideos != null) 'syncVideos': syncVideos,
          if (syncMusic != null) 'syncMusic': syncMusic,
          if (syncOnWifiOnly != null) 'syncOnWifiOnly': syncOnWifiOnly,
          if (autoSync != null) 'autoSync': autoSync,
        },
      );
      
      _settings = response.data['data']['settings'] as Map<String, dynamic>;
      
      // Start/stop auto-sync based on settings
      if (_settings?['autoSync'] == true && _settings?['syncEnabled'] == true) {
        _startAutoSync();
      } else {
        _stopAutoSync();
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[SmartSync] Failed to update settings: $e');
      return false;
    }
  }

  /// Start automatic sync timer
  void _startAutoSync() {
    _stopAutoSync();
    
    // Increased to 30 minutes to prevent freezing, max 1 hour
    int interval = _settings?['syncInterval'] ?? 1800; // 30 minutes default
    if (interval < 1800) interval = 1800; // Minimum 30 minutes
    if (interval > 3600) interval = 3600; // Maximum 1 hour
    
    _syncTimer = Timer.periodic(
      Duration(seconds: interval),
      (_) {
        // Only sync if app has been idle for a bit to avoid freezing during use
        if (!isSyncing) {
          startSync();
        }
      },
    );
    
    debugPrint('[SmartSync] Auto-sync started (interval: ${interval}s = ${(interval / 60).toStringAsFixed(1)} min)');
  }

  /// Stop automatic sync timer
  void _stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
    debugPrint('[SmartSync] Auto-sync stopped');
  }
  
  /// Pause ongoing sync
  void pauseSync() {
    if (isSyncing) {
      _updateProgress(state: SyncState.paused);
      debugPrint('[SmartSync] Sync paused');
    }
  }
  
  /// Resume paused sync
  void resumeSync() {
    if (_progress.state == SyncState.paused) {
      _updateProgress(state: SyncState.uploading);
      debugPrint('[SmartSync] Sync resumed');
    }
  }

  /// Start the sync process (non-blocking)
  Future<void> startSync() async {
    if (isSyncing) {
      debugPrint('[SmartSync] Sync already in progress');
      return;
    }

    debugPrint('[SmartSync] Starting sync...');
    _updateProgress(state: SyncState.scanning);
    
    // Show notification
    await NotificationService.instance.showSyncStarted();

    // Check connectivity before syncing
    await ConnectivityService.instance.forceCheck();
    
    // Check connectivity
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('[SmartSync] No internet connection');
      _updateProgress(
        state: SyncState.error,
        errorMessage: 'No internet connection',
      );
      await NotificationService.instance.showSyncError('No internet connection');
      return;
    }

    // Check WiFi requirement
    if (_settings?['syncOnWifiOnly'] == true) {
      // TODO: Check if on WiFi (requires connectivity_plus package)
      // For now, we'll proceed
    }

    // Run sync in background to avoid blocking UI
    _runSyncInBackground();
  }

  /// Run sync operations in background
  void _runSyncInBackground() async {
    try {
      // Step 1: Scan local files (this is the heavy operation)
      await _scanLocalFiles();
      
      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Step 2: Get server files
      await _getServerFiles();
      
      // Yield to UI thread
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Step 3: Compare and sync
      await _compareAndSync();
      
      // Step 4: Update sync status on server
      await _updateServerSyncStatus();
      
      // Step 5: Complete
      _updateProgress(state: SyncState.completed);
      debugPrint('[SmartSync] Sync completed successfully');
      
      // Show success notification
      await NotificationService.instance.showSyncCompleted(_progress.uploadedFiles);
      
      // Stop foreground service
      await BackgroundSyncService.instance.stopForegroundService();
      
    } catch (e) {
      debugPrint('[SmartSync] Sync failed: $e');
      _updateProgress(
        state: SyncState.error,
        errorMessage: e.toString(),
      );
      
      // Show error notification
      await NotificationService.instance.showSyncError(e.toString());
      
      // Stop foreground service
      await BackgroundSyncService.instance.stopForegroundService();
    }
  }

  /// Scan local device folders for files (optimized with batching)
  Future<void> _scanLocalFiles() async {
    _updateProgress(state: SyncState.scanning);
    debugPrint('[SmartSync] Scanning local files...');
    
    // Show scanning notification
    await NotificationService.instance.showScanningStarted();

    final folders = await _getSyncFolders();
    _localFileHashes.clear();
    int scanned = 0;
    int batchCount = 0;

    for (final folder in folders) {
      if (!folder.existsSync()) continue;

      try {
        final entities = folder.listSync(recursive: true);
        
        for (final entity in entities) {
          if (entity is File) {
            if (await _shouldSyncFile(entity)) {
              final hash = await _calculateFileHash(entity);
              _localFileHashes[entity.path] = hash;
              scanned++;
              batchCount++;
              
              // Update progress every 10 files
              if (batchCount >= 10) {
                _updateProgress(
                  scannedFiles: scanned,
                  currentFile: entity.uri.pathSegments.last,
                );
                
                // Update notification every 10 files
                await NotificationService.instance.updateScanningProgress(scanned);
                
                batchCount = 0;
                
                // Yield to UI thread every 10 files to prevent freezing
                await Future.delayed(const Duration(milliseconds: 50));
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[SmartSync] Error scanning ${folder.path}: $e');
      }
    }

    // Final progress update
    _updateProgress(scannedFiles: scanned);
    debugPrint('[SmartSync] Scanned $scanned local files');
  }

  /// Get list of folders to sync based on settings
  Future<List<Directory>> _getSyncFolders() async {
    final folders = <Directory>[];

    try {
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final basePath = externalDir.parent.parent.parent.parent.path;

          if (_settings?['syncDocuments'] == true) {
            folders.add(Directory('$basePath/Documents'));
          }
          if (_settings?['syncDownloads'] == true) {
            folders.add(Directory('$basePath/Download'));
          }
          if (_settings?['syncPictures'] == true) {
            folders.add(Directory('$basePath/DCIM'));
            folders.add(Directory('$basePath/Pictures'));
          }
          if (_settings?['syncVideos'] == true) {
            folders.add(Directory('$basePath/Movies'));
          }
          if (_settings?['syncMusic'] == true) {
            folders.add(Directory('$basePath/Music'));
          }
        }
      } else if (Platform.isIOS) {
        // iOS uses app sandbox - can only access app's document directory
        final appDocDir = await getApplicationDocumentsDirectory();
        
        if (_settings?['syncDocuments'] == true) {
          folders.add(appDocDir);
        }
        
        // Note: iOS restricts access to other folders due to sandboxing
        debugPrint('[SmartSync] iOS detected - using app documents directory');
      }
    } catch (e) {
      debugPrint('[SmartSync] Error getting sync folders: $e');
    }

    return folders;
  }

  /// Check if file should be synced
  Future<bool> _shouldSyncFile(File file) async {
    try {
      final stat = await file.stat();
      
      // Skip files > 100MB
      if (stat.size > 100 * 1024 * 1024) return false;
      
      // Skip system files
      final name = file.uri.pathSegments.last;
      if (name.startsWith('.')) return false;
      
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Calculate SHA-256 hash of file using streaming to avoid OOM
  Future<String> _calculateFileHash(File file) async {
    try {
      // Read file in chunks to avoid loading entire file in memory
      final reader = file.openRead();
      final hash = await sha256.bind(reader).first;
      return hash.toString();
    } catch (e) {
      debugPrint('[SmartSync] Failed to hash ${file.path}: $e');
      return '';
    }
  }

  /// Get files from server with their hashes
  Future<void> _getServerFiles() async {
    _updateProgress(state: SyncState.comparing);
    debugPrint('[SmartSync] Getting server files...');

    try {
      final response = await ApiClient.instance.dio.get('/sync/files');
      final files = response.data['data']['files'] as List<dynamic>;
      
      _serverFiles.clear();
      for (final file in files) {
        final hash = file['sha256Hash'];
        if (hash != null) {
          _serverFiles[hash] = file;
        }
      }
      
      debugPrint('[SmartSync] Found ${_serverFiles.length} server files');
    } catch (e) {
      debugPrint('[SmartSync] Failed to get server files: $e');
      throw Exception('Failed to get server files');
    }
  }

  /// Compare local and server files, then sync
  Future<void> _compareAndSync() async {
    debugPrint('[SmartSync] Comparing and syncing...');
    
    final toUpload = <String, String>{}; // path -> hash
    final conflicts = <String, Map<String, dynamic>>{}; // path -> conflict info
    int uploaded = 0;

    // Find files to upload (new or modified) and detect conflicts
    for (final entry in _localFileHashes.entries) {
      final localPath = entry.key;
      final localHash = entry.value;

      // Check if file exists on server with different hash (conflict)
      final conflictingFile = _serverFiles.values.firstWhere(
        (serverFile) =>
            serverFile['localPath'] == localPath &&
            serverFile['sha256Hash'] != localHash,
        orElse: () => <String, dynamic>{},
      );

      if (conflictingFile.isNotEmpty) {
        // Conflict detected - same path, different content
        final localFile = File(localPath);
        final localStat = await localFile.stat();
        
        final serverModified = conflictingFile['modifiedAt'] != null
            ? DateTime.parse(conflictingFile['modifiedAt'] as String)
            : DateTime.parse(conflictingFile['updatedAt'] as String);
        
        conflicts[localPath] = {
          'localHash': localHash,
          'serverHash': conflictingFile['sha256Hash'],
          'localModified': localStat.modified,
          'serverModified': serverModified,
          'serverFile': conflictingFile,
        };
        
        debugPrint('[SmartSync] Conflict detected: $localPath');
      } else if (!_serverFiles.containsKey(localHash)) {
        // New or modified file, no conflict
        toUpload[localPath] = localHash;
      }
    }

    // Resolve conflicts automatically
    await _resolveConflicts(conflicts, toUpload);

    _updateProgress(
      totalFiles: toUpload.length,
      conflictFiles: conflicts.length,
      state: SyncState.uploading,
    );

    debugPrint('[SmartSync] ${toUpload.length} files to upload, ${conflicts.length} conflicts resolved');

    // Limit uploads to prevent freezing (max 20 files per sync)
    const maxFilesPerSync = 20;
    final filesToUpload = toUpload.entries.take(maxFilesPerSync).toList();
    
    if (toUpload.length > maxFilesPerSync) {
      debugPrint('[SmartSync] Limiting upload to $maxFilesPerSync files (${toUpload.length} total). Remaining files will sync in next cycle.');
    }

    // Show uploading notification
    if (filesToUpload.isNotEmpty) {
      await NotificationService.instance.showSyncStarted();
    }

    // Upload files with batching
    for (final entry in filesToUpload) {
      if (_progress.state == SyncState.paused) break;

      try {
        final file = File(entry.key);
        final fileName = file.uri.pathSegments.last;
        
        _updateProgress(currentFile: fileName);

        await _uploadFile(file, entry.value);
        
        uploaded++;
        _updateProgress(uploadedFiles: uploaded);
        
        // Update notification with progress every file
        await NotificationService.instance.updateSyncProgress(
          uploaded,
          filesToUpload.length,
        );
        
        debugPrint('[SmartSync] Uploaded ($uploaded/${filesToUpload.length}): $fileName');
        
        // Increased delay to prevent overwhelming the server and reduce battery drain
        await Future.delayed(const Duration(milliseconds: 200));
        
      } catch (e) {
        debugPrint('[SmartSync] Failed to upload ${entry.key}: $e');
        _updateProgress(
          failedFiles: _progress.failedFiles + 1,
        );
      }
    }

    debugPrint('[SmartSync] Upload complete: $uploaded/${filesToUpload.length}');
  }

  /// Resolve conflicts between local and server files
  /// Strategy: Newer file wins (based on modification time)
  Future<void> _resolveConflicts(
    Map<String, Map<String, dynamic>> conflicts,
    Map<String, String> toUpload,
  ) async {
    for (final entry in conflicts.entries) {
      final localPath = entry.key;
      final conflict = entry.value;
      
      final localModified = conflict['localModified'] as DateTime;
      final serverModified = conflict['serverModified'] as DateTime;
      
      // Compare modification times
      if (localModified.isAfter(serverModified)) {
        // Local is newer - upload it (will create new version)
        toUpload[localPath] = conflict['localHash'] as String;
        debugPrint('[SmartSync] Conflict resolved: uploading newer local file $localPath');
      } else {
        // Server is newer - keep server version, skip upload
        debugPrint('[SmartSync] Conflict resolved: keeping newer server file $localPath');
        // Optionally: download server version to update local file
        // await _downloadFile(conflict['serverFile']);
      }
    }
  }

  /// Upload a single file with metadata
  Future<void> _uploadFile(File file, String hash) async {
    final bytes = await file.readAsBytes();
    final fileName = file.uri.pathSegments.last;
    final stat = await file.stat();

    await _fileService.uploadFiles(
      files: [
        PlatformFile(
          name: fileName,
          size: stat.size,
          bytes: bytes,
          path: file.path,
        ),
      ],
      folderId: null,
      metadata: {
        'sha256Hash': hash,
        'localPath': file.path,
        'modifiedAt': stat.modified.toIso8601String(),
        'deviceId': _deviceId,
        'syncStatus': 'synced',
      },
    );
  }

  /// Update sync status on server after sync completion
  Future<void> _updateServerSyncStatus() async {
    try {
      await ApiClient.instance.dio.post(
        '/sync/status',
        data: {
          'lastSyncAt': DateTime.now().toIso8601String(),
          'totalFilesSynced': _progress.uploadedFiles + _progress.downloadedFiles,
          'uploadsPending': 0,
          'downloadsPending': 0,
          'syncInProgress': false,
        },
      );
      
      // Refresh settings to get updated stats
      await getSyncSettings();
    } catch (e) {
      debugPrint('[SmartSync] Failed to update server sync status: $e');
    }
  }

  /// Cancel and reset sync
  void cancelSync() {
    _updateProgress(
      state: SyncState.idle,
      totalFiles: 0,
      scannedFiles: 0,
      uploadedFiles: 0,
      downloadedFiles: 0,
      conflictFiles: 0,
      failedFiles: 0,
      currentFile: null,
      errorMessage: null,
    );
    debugPrint('[SmartSync] Sync cancelled');
  }

  /// Update progress and notify listeners
  void _updateProgress({
    int? totalFiles,
    int? scannedFiles,
    int? uploadedFiles,
    int? downloadedFiles,
    int? conflictFiles,
    int? failedFiles,
    SyncState? state,
    String? currentFile,
    String? errorMessage,
  }) {
    _progress = _progress.copyWith(
      totalFiles: totalFiles,
      scannedFiles: scannedFiles,
      uploadedFiles: uploadedFiles,
      downloadedFiles: downloadedFiles,
      conflictFiles: conflictFiles,
      failedFiles: failedFiles,
      state: state,
      currentFile: currentFile,
      errorMessage: errorMessage,
    );
    notifyListeners();
    
    // Update background sync service with progress
    BackgroundSyncService.instance.updateProgress({
      'totalFiles': _progress.totalFiles,
      'uploadedFiles': _progress.uploadedFiles,
      'state': _progress.state.toString(),
      'percentage': (_progress.progress * 100).toInt(),
    });
    
    // Update foreground notification if background service is running
    if (BackgroundSyncService.instance.isRunning) {
      final uploaded = _progress.uploadedFiles;
      final total = _progress.totalFiles;
      final percentage = total > 0 ? ((uploaded / total) * 100).toInt() : 0;
      
      if (_progress.state == SyncState.scanning) {
        BackgroundSyncService.instance.updateNotification(
          title: '🔍 CloudBox - Scanning',
          text: '${_progress.scannedFiles} files scanned...',
        );
      } else if (_progress.state == SyncState.uploading) {
        BackgroundSyncService.instance.updateNotification(
          title: '☁️ CloudBox - Uploading',
          text: 'Uploading $uploaded of $total files ($percentage%)',
        );
      } else if (_progress.state == SyncState.completed) {
        BackgroundSyncService.instance.updateNotification(
          title: '✓ CloudBox - Complete',
          text: '$uploaded files synced successfully',
        );
      }
    }
  }

  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }
}
