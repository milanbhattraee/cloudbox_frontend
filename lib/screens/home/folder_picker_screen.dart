import 'package:flutter/material.dart';

import '../../models/cloud_folder.dart';
import '../../services/folder_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';

class _Crumb {
  final String? id;
  final String name;
  _Crumb(this.id, this.name);
}

/// Pushed via Navigator; pops with the chosen folder id (null == root), or
/// nothing at all if the user backs out without choosing.
class FolderPickerScreen extends StatefulWidget {
  /// If moving a folder, pass its id so it (and implicitly its subtree,
  /// enforced server-side) can't be chosen as its own destination.
  final String? excludeFolderId;

  const FolderPickerScreen({super.key, this.excludeFolderId});

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  final _folderService = FolderService();
  final List<_Crumb> _trail = [_Crumb(null, 'My Files')];

  List<CloudFolder> _folders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final folders = await _folderService.listFolders(parentFolderId: _trail.last.id);
      setState(() {
        _folders = folders.where((f) => f.id != widget.excludeFolderId).toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openFolder(CloudFolder folder) {
    setState(() => _trail.add(_Crumb(folder.id, folder.name)));
    _load();
  }

  void _goToCrumb(int index) {
    setState(() => _trail.removeRange(index + 1, _trail.length));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Move to...'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _trail.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.chevron_right_rounded, size: 18),
                ),
                itemBuilder: (context, index) {
                  final isLast = index == _trail.length - 1;
                  return Center(
                    child: InkWell(
                      onTap: isLast ? null : () => _goToCrumb(index),
                      child: Text(
                        _trail[index].name,
                        style: TextStyle(
                          fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                          color: isLast
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const LoadingView()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : _folders.isEmpty
                        ? const EmptyState(
                            icon: Icons.folder_open_rounded,
                            title: 'No subfolders here',
                          )
                        : ListView.builder(
                            itemCount: _folders.length,
                            itemBuilder: (context, index) {
                              final folder = _folders[index];
                              return ListTile(
                                leading: const Icon(Icons.folder_rounded, color: Color(0xFFF59E0B)),
                                title: Text(folder.name),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => _openFolder(folder),
                              );
                            },
                          ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_trail.last.id),
                  child: Text('Move here (${_trail.last.name})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
