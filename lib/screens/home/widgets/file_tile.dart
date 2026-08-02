import 'package:flutter/material.dart';

import '../../../core/utils/byte_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/cloud_file.dart';
import '../../../models/file_category.dart';

enum FileTileAction { open, download, rename, move, delete }

class FileTile extends StatelessWidget {
  final CloudFile file;
  final VoidCallback onTap;
  final void Function(FileTileAction action) onAction;

  const FileTile({
    super.key,
    required this.file,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = file.category;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: category.color.withValues(alpha: 0.15),
        child: Icon(category.icon, color: category.color),
      ),
      title: Text(
        file.originalName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${formatBytes(file.size)} • ${file.createdAt != null ? formatFriendlyDate(file.createdAt!) : ''}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      ),
      trailing: PopupMenuButton<FileTileAction>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: onAction,
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: FileTileAction.download,
            child: ListTile(
              leading: Icon(Icons.download_rounded),
              title: Text('Download'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: FileTileAction.rename,
            child: ListTile(
              leading: Icon(Icons.edit_rounded),
              title: Text('Rename'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: FileTileAction.move,
            child: ListTile(
              leading: Icon(Icons.drive_file_move_rounded),
              title: Text('Move'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: FileTileAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Delete'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
