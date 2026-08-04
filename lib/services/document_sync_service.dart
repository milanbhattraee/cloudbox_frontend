import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../services/file_service.dart';
import 'connectivity_service.dart';

enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}

class SyncQueueItem {
  final String filePath;
  final String fileName;
  final int fileSize;
  final DateTime addedAt;
  bool isSyncing;
  String? error;

  SyncQueueItem({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.addedAt,
    this.isSyncing = false,
    this.error,
  });
}

/// Service that monitors document directories and automatically syncs files
/// to Cloudinary via the backend API
class DocumentSyncService extends ChangeNotifier {
  DocumentSyncService._internal();

  static final DocumentSyncService instance = DocumentSyncService._internal();

  final FileService _fileService = FileService();
  final List<SyncQueueItem> _syncQueue = [];
  final Set<String> _syncedFiles = {}; // Track already synced files
  
  SyncStatus _status = SyncStatus.idle;
  Timer? _syncTimer;
  bool _isEnabled = false;
  String? _lastError;
  DateTime? _lastSyncTime;
  int _totalSyncedCount = 0;

  SyncStatus get status => _status;
  bool get isEnabled => _isEnabled;
  List<SyncQueueItem> get syncQueue => List.unmodifiable(_syncQueue);
  int get queueLength => _syncQueue.length;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get totalSyncedCount => _totalSyncedCount;

  /// Enable automatic document syncing
  Future<void> enable() async {
    if (_isEnabled) return;
    
    debugPrint('[DocumentSyncService] Enabling automatic sync...');
    _isEnabled = true;
    _startPeriodicSync();
    notifyListeners();
    
    // Perform initial scan
    await scanForNewDocuments();
  }

  /// Disable automatic document syncing
  void disable() {
    debugPrint('[DocumentSyncService] Disabling automatic sync...');
    _isEnabled = false;
    _syncTimer?.cancel();
    _syncTimer = null;
    notifyListeners();
  }

  /// Start periodic syncing (every 5 minutes)
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _performSync(),
    );
  }

  /// Scan device storage for documents to sync
  Future<void> scanForNewDocuments() async {
    if (!_isEnabled) return;

    try {
      debugPrint('[DocumentSyncService] Scanning for new documents...');
      
      // Get common document directories
      final directories = await _getDocumentDirectories();
      
      for (final directory in directories) {
        if (!directory.existsSync()) continue;
        
        await _scanDirectory(directory);
      }
      
      debugPrint('[DocumentSyncService] Scan complete. Queue size: ${_syncQueue.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('[DocumentSyncService] Scan error: $e');
      _lastError = e.toString();
      notifyListeners();
    }
  }

  /// Get list of document directories to monitor
  Future<List<Directory>> _getDocumentDirectories() async {
    final directories = <Directory>[];
    
    try {
      // Get external storage directory (Android)
      if (Platform.isAndroid) {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Common document folders
          directories.addAll([
            Directory('${externalDir.parent.parent.parent.parent.path}/Documents'),
            Directory('${externalDir.parent.parent.parent.parent.path}/Download'),
            externalDir, // App's external storage
          ]);
        }
      }
      
      // Get documents directory (iOS)
      if (Platform.isIOS) {
        final docsDir = await getApplicationDocumentsDirectory();
        directories.add(docsDir);
      }
      
      // Application support directory
      final appSupportDir = await getApplicationSupportDirectory();
      directories.add(appSupportDir);
      
    } catch (e) {
      debugPrint('[DocumentSyncService] Error getting directories: $e');
    }
    
    return directories;
  }

  /// Scan a directory for documents
  Future<void> _scanDirectory(Directory directory) async {
    try {
      final entities = directory.listSync(recursive: false, followLinks: false);
      
      for (final entity in entities) {
        if (entity is File) {
          await _checkAndQueueFile(entity);
        }
      }
    } catch (e) {
      debugPrint('[DocumentSyncService] Error scanning ${directory.path}: $e');
    }
  }

  /// Check if file should be synced and add to queue
  Future<void> _checkAndQueueFile(File file) async {
    try {
      // Skip if already synced
      if (_syncedFiles.contains(file.path)) return;
      
      // Skip if already in queue
      if (_syncQueue.any((item) => item.filePath == file.path)) return;
      
      // Check if it's a document file
      if (!_isDocumentFile(file.path)) return;
      
      // Check file size (skip very large files > 100MB)
      final stat = await file.stat();
      if (stat.size > 100 * 1024 * 1024) return;
      
      // Add to queue
      final queueItem = SyncQueueItem(
        filePath: file.path,
        fileName: file.uri.pathSegments.last,
        fileSize: stat.size,
        addedAt: DateTime.now(),
      );
      
      _syncQueue.add(queueItem);
      debugPrint('[DocumentSyncService] Queued: ${queueItem.fileName}');
    } catch (e) {
      debugPrint('[DocumentSyncService] Error checking file ${file.path}: $e');
    }
  }

  /// Check if file is a document based on extension
  bool _isDocumentFile(String path) {
    final extension = path.toLowerCase().split('.').last;
    const documentExtensions = [
      'pdf', 'doc', 'docx', 'txt', 'rtf',
      'xls', 'xlsx', 'csv',
      'ppt', 'pptx',
      'odt', 'ods', 'odp',
    ];
    return documentExtensions.contains(extension);
  }

  /// Perform the sync operation
  Future<void> _performSync() async {
    if (!_isEnabled) return;
    if (_status == SyncStatus.syncing) return; // Already syncing
    if (_syncQueue.isEmpty) return;
    
    // Check connectivity
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('[DocumentSyncService] Skipping sync - offline');
      return;
    }
    
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();
    
    debugPrint('[DocumentSyncService] Starting sync of ${_syncQueue.length} files...');
    
    final itemsToSync = List<SyncQueueItem>.from(_syncQueue);
    
    for (final item in itemsToSync) {
      if (!_isEnabled) break; // Stop if disabled during sync
      
      try {
        item.isSyncing = true;
        notifyListeners();
        
        await _syncFile(item);
        
        // Remove from queue and mark as synced
        _syncQueue.remove(item);
        _syncedFiles.add(item.filePath);
        _totalSyncedCount++;
        _lastSyncTime = DateTime.now();
        
        debugPrint('[DocumentSyncService] Synced: ${item.fileName}');
      } catch (e) {
        debugPrint('[DocumentSyncService] Failed to sync ${item.fileName}: $e');
        item.error = e.toString();
        item.isSyncing = false;
      }
      
      notifyListeners();
      
      // Small delay between uploads to avoid overwhelming the server
      await Future.delayed(const Duration(seconds: 2));
    }
    
    _status = _syncQueue.isEmpty ? SyncStatus.completed : SyncStatus.failed;
    notifyListeners();
    
    debugPrint('[DocumentSyncService] Sync complete. Remaining: ${_syncQueue.length}');
  }

  /// Sync a single file to Cloudinary via backend
  Future<void> _syncFile(SyncQueueItem item) async {
    final file = File(item.filePath);
    
    if (!file.existsSync()) {
      throw Exception('File no longer exists');
    }
    
    final bytes = await file.readAsBytes();
    
    // Upload using the file service
    await _fileService.uploadFiles(
      files: [
        PlatformFile(
          name: item.fileName,
          size: item.fileSize,
          bytes: bytes,
          path: item.filePath,
        ),
      ],
      folderId: null, // Upload to root or create a "Synced Documents" folder
    );
  }

  /// Manually trigger sync now
  Future<void> syncNow() async {
    debugPrint('[DocumentSyncService] Manual sync triggered');
    await scanForNewDocuments();
    await _performSync();
  }

  /// Clear sync queue
  void clearQueue() {
    _syncQueue.clear();
    notifyListeners();
  }

  /// Remove specific item from queue
  void removeFromQueue(SyncQueueItem item) {
    _syncQueue.remove(item);
    notifyListeners();
  }

  /// Clear synced files history (for re-syncing)
  void clearSyncHistory() {
    _syncedFiles.clear();
    _totalSyncedCount = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
