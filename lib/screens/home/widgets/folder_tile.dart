import 'package:flutter/material.dart';

import '../../../models/cloud_folder.dart';

class FolderTile extends StatelessWidget {
  final CloudFolder folder;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = folder.subFolderCount + folder.fileCount;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      onLongPress: onMenuTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B), size: 30),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onMenuTap,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.more_vert_rounded, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              itemCount == 0 ? 'Empty' : '$itemCount item${itemCount == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
