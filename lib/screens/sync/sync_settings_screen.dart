import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/smart_sync_service.dart';
import '../../services/background_sync_service.dart';
import 'folder_selection_screen.dart';

class SyncSettingsScreen extends StatelessWidget {
  const SyncSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SmartSyncService>();
    final progress = syncService.progress;
    final settings = syncService.settings;
    final isSyncing = syncService.isSyncing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-Sync Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sync Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getSyncIcon(progress.state),
                        color: _getSyncColor(progress.state),
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getSyncStateTitle(progress.state),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getSyncStateSubtitle(progress),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (isSyncing && progress.totalFiles > 0) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress.progress),
                    const SizedBox(height: 8),
                    Text(
                      '${progress.uploadedFiles}/${progress.totalFiles} files',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sync Controls
          Text(
            'Sync Controls',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Card(
            child: Column(
              children: [
                if (settings?['syncEnabled'] == true) ...[
                  ListTile(
                    leading: Icon(
                      isSyncing ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(isSyncing ? 'Pause Sync' : 'Resume Sync'),
                    subtitle: Text(
                      isSyncing
                          ? 'Temporarily stop syncing'
                          : 'Start syncing your files',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      if (isSyncing) {
                        syncService.pauseSync();
                      } else {
                        syncService.resumeSync();
                      }
                    },
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: Icon(
                    Icons.sync_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Sync Now'),
                  subtitle: const Text('Manually trigger a sync with background support'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: isSyncing
                      ? null
                      : () async {
                          try {
                            debugPrint('[SyncSettings] Starting sync...');
                            
                            // Try to start foreground service (for background execution)
                            final started = await BackgroundSyncService.instance.startForegroundService();
                            
                            if (!started) {
                              debugPrint('[SyncSettings] Foreground service not started, but continuing with regular sync...');
                              // Still allow sync even if foreground service fails
                              // It just won't continue in background
                            }
                            
                            // Start the actual sync operation
                            debugPrint('[SyncSettings] Starting sync operation...');
                            await syncService.startSync();
                            
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(started 
                                    ? '✓ Background sync started' 
                                    : '✓ Sync started (foreground only)'),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: started ? Colors.green : Colors.orange,
                                ),
                              );
                            }
                          } catch (e, stackTrace) {
                            debugPrint('[SyncSettings] Error starting sync: $e');
                            debugPrint('[SyncSettings] Stack trace: $stackTrace');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  duration: const Duration(seconds: 4),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.folder_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Choose Folders'),
                  subtitle: const Text('Select which folders to sync'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FolderSelectionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics
          if (settings != null) ...[
            Text(
              'Statistics',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatRow(
                      context,
                      icon: Icons.check_circle_rounded,
                      label: 'Files Synced',
                      value: '${settings['totalFilesSynced'] ?? 0}',
                      color: Colors.green,
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      context,
                      icon: Icons.cloud_upload_rounded,
                      label: 'Uploads Pending',
                      value: '${settings['uploadsPending'] ?? 0}',
                      color: Colors.orange,
                    ),
                    const Divider(height: 24),
                    _buildStatRow(
                      context,
                      icon: Icons.schedule_rounded,
                      label: 'Last Sync',
                      value: _formatLastSync(settings['lastSyncAt']),
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Active Folders
          if (settings != null) ...[
            Text(
              'Active Folders',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  if (settings['syncDocuments'] == true)
                    _buildFolderChip(context, 'Documents', Icons.description_rounded),
                  if (settings['syncDownloads'] == true)
                    _buildFolderChip(context, 'Downloads', Icons.download_rounded),
                  if (settings['syncPictures'] == true)
                    _buildFolderChip(context, 'Pictures', Icons.image_rounded),
                  if (settings['syncVideos'] == true)
                    _buildFolderChip(context, 'Videos', Icons.videocam_rounded),
                  if (settings['syncMusic'] == true)
                    _buildFolderChip(context, 'Music', Icons.music_note_rounded),
                  if (!(settings['syncDocuments'] == true ||
                      settings['syncDownloads'] == true ||
                      settings['syncPictures'] == true ||
                      settings['syncVideos'] == true ||
                      settings['syncMusic'] == true))
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No folders selected'),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildFolderChip(BuildContext context, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      trailing: Icon(
        Icons.check_circle_rounded,
        color: Colors.green,
      ),
    );
  }

  IconData _getSyncIcon(SyncState state) {
    switch (state) {
      case SyncState.idle:
      case SyncState.completed:
        return Icons.cloud_done_rounded;
      case SyncState.scanning:
      case SyncState.comparing:
        return Icons.search_rounded;
      case SyncState.uploading:
        return Icons.cloud_upload_rounded;
      case SyncState.downloading:
        return Icons.cloud_download_rounded;
      case SyncState.paused:
        return Icons.pause_circle_rounded;
      case SyncState.error:
        return Icons.error_rounded;
    }
  }

  Color _getSyncColor(SyncState state) {
    switch (state) {
      case SyncState.idle:
      case SyncState.completed:
        return Colors.green;
      case SyncState.scanning:
      case SyncState.comparing:
        return Colors.blue;
      case SyncState.uploading:
        return Colors.orange;
      case SyncState.downloading:
        return Colors.purple;
      case SyncState.paused:
        return Colors.grey;
      case SyncState.error:
        return Colors.red;
    }
  }

  String _getSyncStateTitle(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return 'Ready to Sync';
      case SyncState.scanning:
        return 'Scanning Files...';
      case SyncState.comparing:
        return 'Comparing...';
      case SyncState.uploading:
        return 'Uploading...';
      case SyncState.downloading:
        return 'Downloading...';
      case SyncState.completed:
        return 'Sync Complete';
      case SyncState.paused:
        return 'Sync Paused';
      case SyncState.error:
        return 'Sync Error';
    }
  }

  String _getSyncStateSubtitle(SyncProgress progress) {
    switch (progress.state) {
      case SyncState.idle:
        return 'Your files are up to date';
      case SyncState.scanning:
        return '${progress.scannedFiles} files scanned';
      case SyncState.comparing:
        return 'Checking for changes';
      case SyncState.uploading:
        return 'Syncing files to cloud';
      case SyncState.downloading:
        return 'Getting latest files';
      case SyncState.completed:
        return 'All files synced successfully';
      case SyncState.paused:
        return 'Sync is temporarily paused';
      case SyncState.error:
        return progress.errorMessage ?? 'An error occurred';
    }
  }

  String _formatLastSync(dynamic lastSyncAt) {
    if (lastSyncAt == null) return 'Never';
    
    try {
      final date = lastSyncAt is DateTime 
          ? lastSyncAt 
          : DateTime.parse(lastSyncAt.toString());
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
