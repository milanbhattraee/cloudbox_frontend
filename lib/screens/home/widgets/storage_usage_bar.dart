import 'package:flutter/material.dart';

import '../../../core/utils/byte_formatter.dart';
import '../../../models/app_user.dart';

class StorageUsageBar extends StatelessWidget {
  final AppUser user;
  const StorageUsageBar({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = user.usageFraction;
    final isNearLimit = fraction > 0.9;
    final stats = user.fileStats;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatBytes(user.storageUsed)} of ${formatBytes(user.storageLimit)} used',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              Text(
                _formatPercentage(fraction),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isNearLimit ? theme.colorScheme.error : theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: isNearLimit ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
          ),
          if (stats != null && stats.total > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (stats.images > 0)
                  _buildStatChip(
                    context,
                    icon: Icons.image_rounded,
                    label: 'Images',
                    count: stats.images,
                    color: Colors.blue,
                  ),
                if (stats.videos > 0)
                  _buildStatChip(
                    context,
                    icon: Icons.videocam_rounded,
                    label: 'Videos',
                    count: stats.videos,
                    color: Colors.purple,
                  ),
                if (stats.documents > 0)
                  _buildStatChip(
                    context,
                    icon: Icons.description_rounded,
                    label: 'Docs',
                    count: stats.documents,
                    color: Colors.orange,
                  ),
                if (stats.audio > 0)
                  _buildStatChip(
                    context,
                    icon: Icons.music_note_rounded,
                    label: 'Audio',
                    count: stats.audio,
                    color: Colors.green,
                  ),
                if (stats.others > 0)
                  _buildStatChip(
                    context,
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Others',
                    count: stats.others,
                    color: Colors.grey,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _formatPercentage(double fraction) {
    final percentage = fraction * 100;
    if (percentage < 1 && percentage > 0) {
      // Show 1 decimal place for very small percentages
      return '${percentage.toStringAsFixed(1)}%';
    } else {
      // Show whole number for larger percentages
      return '${percentage.toStringAsFixed(0)}%';
    }
  }
}
