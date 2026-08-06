import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request storage permissions for Android
  static Future<bool> requestStoragePermissions() async {
    try {
      // For Android 13+ (API 33+)
      if (await _isAndroid13OrHigher()) {
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio = await Permission.audio.request();
        
        return photos.isGranted && videos.isGranted && audio.isGranted;
      } 
      // For Android 11-12 (API 30-32)
      else if (await _isAndroid11OrHigher()) {
        final storage = await Permission.storage.request();
        
        if (storage.isDenied) {
          final manageStorage = await Permission.manageExternalStorage.request();
          return manageStorage.isGranted;
        }
        
        return storage.isGranted;
      }
      // For Android 10 and below
      else {
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    } catch (e) {
      debugPrint('[PermissionService] Error requesting permissions: $e');
      return false;
    }
  }

  /// Check if storage permissions are granted
  static Future<bool> hasStoragePermissions() async {
    try {
      if (await _isAndroid13OrHigher()) {
        final photos = await Permission.photos.status;
        final videos = await Permission.videos.status;
        final audio = await Permission.audio.status;
        
        return photos.isGranted && videos.isGranted && audio.isGranted;
      } else if (await _isAndroid11OrHigher()) {
        final storage = await Permission.storage.status;
        final manageStorage = await Permission.manageExternalStorage.status;
        
        return storage.isGranted || manageStorage.isGranted;
      } else {
        final storage = await Permission.storage.status;
        return storage.isGranted;
      }
    } catch (e) {
      debugPrint('[PermissionService] Error checking permissions: $e');
      return false;
    }
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Show permission rationale dialog
  static Future<bool> showPermissionRationale(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'CloudBox needs access to your photos, videos, and documents to sync them to the cloud.\n\n'
          'Please grant storage permissions in the next screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Show settings dialog when permission is permanently denied
  static Future<void> showSettingsDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
          'Storage permission is required for CloudBox to work.\n\n'
          'Please enable it in Settings → Apps → CloudBox → Permissions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  static Future<bool> _isAndroid13OrHigher() async {
    // Android 13 is API level 33
    return false; // This will be determined by the permission_handler package
  }

  static Future<bool> _isAndroid11OrHigher() async {
    // Android 11 is API level 30
    return true; // Assume modern Android for now
  }
}
