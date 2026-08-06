import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/permission_service.dart';
import '../../services/smart_sync_service.dart';

class FolderSelectionScreen extends StatefulWidget {
  const FolderSelectionScreen({super.key});

  @override
  State<FolderSelectionScreen> createState() => _FolderSelectionScreenState();
}

class _FolderSelectionScreenState extends State<FolderSelectionScreen> {
  bool _syncDocuments = true;
  bool _syncDownloads = true;
  bool _syncPictures = false;
  bool _syncVideos = false;
  bool _syncMusic = false;
  bool _syncOnWifiOnly = true;
  bool _autoSync = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final syncService = context.read<SmartSyncService>();
    final settings = await syncService.getSyncSettings();
    
    if (settings != null && mounted) {
      setState(() {
        _syncDocuments = settings['syncDocuments'] ?? true;
        _syncDownloads = settings['syncDownloads'] ?? true;
        _syncPictures = settings['syncPictures'] ?? false;
        _syncVideos = settings['syncVideos'] ?? false;
        _syncMusic = settings['syncMusic'] ?? false;
        _syncOnWifiOnly = settings['syncOnWifiOnly'] ?? true;
        _autoSync = settings['autoSync'] ?? true;
      });
    }
  }

  Future<void> _saveAndStartSync() async {
    // First check/request permissions
    bool hasPermission = await PermissionService.hasStoragePermissions();
    
    if (!hasPermission) {
      if (!mounted) return;
      
      // Show rationale
      final shouldRequest = await PermissionService.showPermissionRationale(context);
      if (!shouldRequest) return;
      
      // Request permissions
      hasPermission = await PermissionService.requestStoragePermissions();
      
      if (!hasPermission) {
        if (!mounted) return;
        
        // Show settings dialog
        await PermissionService.showSettingsDialog(context);
        return;
      }
    }
    
    setState(() => _isLoading = true);

    final syncService = context.read<SmartSyncService>();
    
    final success = await syncService.updateSyncSettings(
      syncDocuments: _syncDocuments,
      syncDownloads: _syncDownloads,
      syncPictures: _syncPictures,
      syncVideos: _syncVideos,
      syncMusic: _syncMusic,
      syncOnWifiOnly: _syncOnWifiOnly,
      autoSync: _autoSync,
      syncEnabled: true,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        // Start initial sync
        await syncService.startSync();
        
        if (!mounted) return;
        
        // Show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync settings saved! Starting sync...'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save settings. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAnyFolderSelected = _syncDocuments || 
                                 _syncDownloads || 
                                 _syncPictures || 
                                 _syncVideos || 
                                 _syncMusic;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Folders to Sync'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_sync_rounded,
                        size: 32,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Smart Sync',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select which folders to automatically sync',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // Folder Selection
          Text(
            'Folders to Sync',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          _buildFolderTile(
            icon: Icons.description_rounded,
            title: 'Documents',
            subtitle: 'PDF, DOC, TXT, XLS, PPT',
            value: _syncDocuments,
            onChanged: (val) => setState(() => _syncDocuments = val),
            color: Colors.blue,
          ),
          
          _buildFolderTile(
            icon: Icons.download_rounded,
            title: 'Downloads',
            subtitle: 'All downloaded files',
            value: _syncDownloads,
            onChanged: (val) => setState(() => _syncDownloads = val),
            color: Colors.green,
          ),
          
          _buildFolderTile(
            icon: Icons.image_rounded,
            title: 'Pictures',
            subtitle: 'JPG, PNG, GIF, WEBP',
            value: _syncPictures,
            onChanged: (val) => setState(() => _syncPictures = val),
            color: Colors.orange,
          ),
          
          _buildFolderTile(
            icon: Icons.videocam_rounded,
            title: 'Videos',
            subtitle: 'MP4, AVI, MOV, MKV',
            value: _syncVideos,
            onChanged: (val) => setState(() => _syncVideos = val),
            color: Colors.purple,
          ),
          
          _buildFolderTile(
            icon: Icons.music_note_rounded,
            title: 'Music',
            subtitle: 'MP3, WAV, OGG, FLAC',
            value: _syncMusic,
            onChanged: (val) => setState(() => _syncMusic = val),
            color: Colors.pink,
          ),

          const SizedBox(height: 24),

          // Sync Options
          Text(
            'Sync Options',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            child: Column(
              children: [
                // Permission Check
                ListTile(
                  leading: const Icon(Icons.security_rounded),
                  title: const Text('Check Permissions'),
                  subtitle: const Text('Verify storage access'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final hasPermission = await PermissionService.hasStoragePermissions();
                    if (!context.mounted) return;
                    
                    if (hasPermission) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Storage permissions granted'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      final granted = await PermissionService.requestStoragePermissions();
                      if (!context.mounted) return;
                      
                      if (granted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Permissions granted!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        await PermissionService.showSettingsDialog(context);
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.wifi_rounded),
                  title: const Text('Sync on WiFi only'),
                  subtitle: const Text('Save mobile data'),
                  value: _syncOnWifiOnly,
                  onChanged: (val) => setState(() => _syncOnWifiOnly = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.sync_rounded),
                  title: const Text('Auto-sync'),
                  subtitle: const Text('Automatically sync changes'),
                  value: _autoSync,
                  onChanged: (val) => setState(() => _autoSync = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Info Box
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'How Smart Sync Works',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Only new and modified files are uploaded\n'
                    '• Files are compared using hash checksums\n'
                    '• Syncs in background without interrupting you\n'
                    '• Conflicts are detected and resolved automatically\n'
                    '• Pause/resume anytime from settings',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Start Sync Button
          FilledButton.icon(
            onPressed: (_isLoading || !hasAnyFolderSelected) 
                ? null 
                : _saveAndStartSync,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_sync_rounded),
            label: Text(_isLoading ? 'Saving...' : 'Start Sync'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),

          if (!hasAnyFolderSelected) ...[
            const SizedBox(height: 12),
            Text(
              'Please select at least one folder to sync',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFolderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Card(
      child: CheckboxListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (val) => onChanged(val ?? false),
      ),
    );
  }
}
