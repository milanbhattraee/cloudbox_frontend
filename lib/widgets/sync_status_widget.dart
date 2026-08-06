import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/sync/folder_selection_screen.dart';
import '../services/smart_sync_service.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final syncService = context.watch<SmartSyncService>();
    final progress = syncService.progress;
    final settings = syncService.settings;

    // Don't show if sync not enabled
    if (settings?['syncEnabled'] != true) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FolderSelectionScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.cloud_off_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smart Sync Disabled',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to enable automatic file syncing',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Show sync status if enabled
    return Card(
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const FolderSelectionScreen(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildSyncIcon(context, progress.state),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSyncStateTitle(progress.state),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getSyncStateSubtitle(progress),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (syncService.isSyncing)
                    IconButton(
                      icon: const Icon(Icons.pause_rounded),
                      onPressed: syncService.pauseSync,
                      tooltip: 'Pause sync',
                    )
                  else if (progress.state == SyncState.paused)
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: syncService.resumeSync,
                      tooltip: 'Resume sync',
                    ),
                ],
              ),
              
              // Progress bar when syncing
              if (syncService.isSyncing && progress.totalFiles > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.progress,
                    minHeight: 6,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progress.currentFile ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${progress.uploadedFiles}/${progress.totalFiles}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ],

              // Stats when idle/completed
              if (progress.state == SyncState.idle ||
                  progress.state == SyncState.completed) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (settings?['totalFilesSynced'] != null)
                      _buildStatChip(
                        context,
                        icon: Icons.check_circle_outline_rounded,
                        label: '${settings!['totalFilesSynced']} synced',
                        color: Colors.green,
                      ),
                    const SizedBox(width: 8),
                    if (settings?['lastSyncAt'] != null)
                      _buildStatChip(
                        context,
                        icon: Icons.schedule_rounded,
                        label: _formatLastSync(settings!['lastSyncAt'] as String),
                        color: Colors.blue,
                      ),
                  ],
                ),
              ],

              // Error message
              if (progress.state == SyncState.error &&
                  progress.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          progress.errorMessage!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncIcon(BuildContext context, SyncState state) {
    IconData icon;
    Color color;

    switch (state) {
      case SyncState.idle:
      case SyncState.completed:
        icon = Icons.cloud_done_rounded;
        color = Colors.green;
        break;
      case SyncState.scanning:
      case SyncState.comparing:
        icon = Icons.search_rounded;
        color = Colors.blue;
        break;
      case SyncState.uploading:
        icon = Icons.cloud_upload_rounded;
        color = Colors.orange;
        break;
      case SyncState.downloading:
        icon = Icons.cloud_download_rounded;
        color = Colors.purple;
        break;
      case SyncState.paused:
        icon = Icons.pause_circle_outline_rounded;
        color = Colors.grey;
        break;
      case SyncState.error:
        icon = Icons.error_outline_rounded;
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }

  String _getSyncStateTitle(SyncState state) {
    switch (state) {
      case SyncState.idle:
        return 'Smart Sync Active';
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
        return 'Watching for changes';
      case SyncState.scanning:
        return '${progress.scannedFiles} files scanned';
      case SyncState.comparing:
        return 'Checking for changes';
      case SyncState.uploading:
        return 'Syncing your files to cloud';
      case SyncState.downloading:
        return 'Getting latest files';
      case SyncState.completed:
        return 'All files are up to date';
      case SyncState.paused:
        return 'Tap play to resume';
      case SyncState.error:
        return 'Tap to retry';
    }
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Recently';
    }
  }
}
