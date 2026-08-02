import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/save_file/save_file.dart';
import '../../models/cloud_file.dart';
import '../../models/cloud_folder.dart';
import '../../providers/auth_provider.dart';
import '../../providers/browser_provider.dart';
import '../../providers/upload_provider.dart';
import '../../services/file_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/prompt_dialog.dart';
import '../preview/image_preview_screen.dart';
import '../profile/profile_screen.dart';
import 'folder_picker_screen.dart';
import 'widgets/category_filter_row.dart';
import 'widgets/file_tile.dart';
import 'widgets/folder_tile.dart';
import 'widgets/storage_usage_bar.dart';
import 'widgets/upload_progress_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<BrowserProvider>().startFreshSession());
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      context.read<BrowserProvider>().loadMoreFiles();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop(BrowserProvider browser) async {
    if (_isSearching) {
      setState(() => _isSearching = false);
      _searchController.clear();
      browser.setSearch(null);
      return false;
    }
    if (!browser.isAtRoot) {
      browser.goUp();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final auth = context.watch<AuthProvider>();
    final upload = context.watch<UploadProvider>();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop(browser);
        if (shouldPop && context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search files...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) => browser.setSearch(value),
                )
              : Text(browser.currentFolderName),
          actions: [
            IconButton(
              icon: Icon(
                  _isSearching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () {
                setState(() => _isSearching = !_isSearching);
                if (!_isSearching) {
                  _searchController.clear();
                  browser.setSearch(null);
                }
              },
            ),
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  (auth.currentUser?.email.isNotEmpty ?? false)
                      ? auth.currentUser!.email[0].toUpperCase()
                      : '?',
                ),
              ),
              onSelected: (value) async {
                if (value == 'profile') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                } else if (value == 'logout') {
                  final confirmed = await showConfirmDialog(
                    context,
                    title: 'Sign out?',
                    message: 'You can sign back in any time.',
                    confirmLabel: 'Sign out',
                  );
                  if (confirmed) await context.read<AuthProvider>().signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: const Text('Profile'),
                    subtitle: Text(auth.currentUser?.email ?? ''),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout_rounded),
                    title: Text('Sign out'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            if (auth.currentUser != null)
              StorageUsageBar(user: auth.currentUser!),
            if (!browser.isAtRoot || browser.breadcrumbNames.length > 1)
              _buildBreadcrumbs(browser),
            const SizedBox(height: 4),
            CategoryFilterRow(
              selected: browser.categoryFilter,
              onSelected: (category) => browser.setCategoryFilter(category),
            ),
            const SizedBox(height: 8),
            UploadProgressBanner(uploadProvider: upload),
            Expanded(child: _buildBody(browser)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddSheet(context, browser),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(BrowserProvider browser) {
    final names = browser.breadcrumbNames;
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: names.length,
        separatorBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.chevron_right_rounded, size: 16),
        ),
        itemBuilder: (context, index) {
          final isLast = index == names.length - 1;
          return Center(
            child: InkWell(
              onTap: isLast ? null : () => browser.goToBreadcrumb(index),
              child: Text(
                names[index],
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
    );
  }

  Widget _buildBody(BrowserProvider browser) {
    if (browser.isLoading && browser.folders.isEmpty && browser.files.isEmpty) {
      return const LoadingView();
    }
    if (browser.errorMessage != null &&
        browser.folders.isEmpty &&
        browser.files.isEmpty) {
      return ErrorState(
          message: browser.errorMessage!, onRetry: browser.refresh);
    }
    if (browser.folders.isEmpty && browser.files.isEmpty) {
      return EmptyState(
        icon: browser.hasActiveFilters
            ? Icons.search_off_rounded
            : Icons.cloud_outlined,
        title:
            browser.hasActiveFilters ? 'No matching files' : 'Nothing here yet',
        message: browser.hasActiveFilters
            ? 'Try a different search or filter.'
            : 'Tap "Add" to upload a file or create a folder.',
      );
    }

    return RefreshIndicator(
      onRefresh: browser.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          if (browser.folders.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Folders',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 108,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: browser.folders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final folder = browser.folders[index];
                    return FolderTile(
                      folder: folder,
                      onTap: () => browser.openFolder(folder),
                      onMenuTap: () =>
                          _showFolderActions(context, browser, folder),
                    );
                  },
                ),
              ),
            ),
          ],
          if (browser.files.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text('Files',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            SliverList.builder(
              itemCount: browser.files.length + (browser.hasMoreFiles ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= browser.files.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final file = browser.files[index];
                return FileTile(
                  file: file,
                  onTap: () => _onFileTap(context, file),
                  onAction: (action) =>
                      _onFileAction(context, browser, file, action),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  // ---- Folder actions ----

  void _showFolderActions(
      BuildContext context, BrowserProvider browser, CloudFolder folder) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Rename'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final newName = await showTextInputDialog(
                  context,
                  title: 'Rename folder',
                  initialValue: folder.name,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                );
                if (newName != null && newName.isNotEmpty && context.mounted) {
                  final ok = await browser.renameFolder(folder, newName);
                  if (!ok && context.mounted)
                    _showError(context, browser.errorMessage);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Move'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final destination = await Navigator.of(context).push<String?>(
                  MaterialPageRoute(
                    builder: (_) =>
                        FolderPickerScreen(excludeFolderId: folder.id),
                  ),
                );
                if (destination != null && context.mounted) {
                  final ok = await browser.moveFolder(
                      folder, destination == 'root' ? null : destination);
                  if (!ok && context.mounted)
                    _showError(context, browser.errorMessage);
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete "${folder.name}"?',
                  message: folder.isEmpty
                      ? 'This folder is empty and will be deleted.'
                      : 'This will permanently delete the folder and everything inside it '
                          '(${folder.subFolderCount} subfolder(s), ${folder.fileCount} file(s)).',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (confirmed && context.mounted) {
                  final ok = await browser.deleteFolder(folder);
                  if (!ok && context.mounted)
                    _showError(context, browser.errorMessage);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- File actions ----

  void _onFileTap(BuildContext context, CloudFile file) {
    if (file.isImage) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ImagePreviewScreen(file: file)),
      );
    } else {
      _downloadAndOpen(context, file);
    }
  }

  Future<void> _onFileAction(
    BuildContext context,
    BrowserProvider browser,
    CloudFile file,
    FileTileAction action,
  ) async {
    switch (action) {
      case FileTileAction.open:
        _onFileTap(context, file);
        break;
      case FileTileAction.download:
        await _downloadAndOpen(context, file);
        break;
      case FileTileAction.rename:
        final newName = await showTextInputDialog(
          context,
          title: 'Rename file',
          initialValue: file.originalName,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        );
        if (newName != null && newName.isNotEmpty && context.mounted) {
          final ok = await browser.renameFile(file, newName);
          if (!ok && context.mounted) _showError(context, browser.errorMessage);
        }
        break;
      case FileTileAction.move:
        final destination = await Navigator.of(context).push<String?>(
          MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
        );
        if (destination != null && context.mounted) {
          final ok = await browser.moveFile(
              file, destination == 'root' ? null : destination);
          if (!ok && context.mounted) _showError(context, browser.errorMessage);
        }
        break;
      case FileTileAction.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Delete "${file.originalName}"?',
          message: 'This cannot be undone.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (confirmed && context.mounted) {
          final ok = await browser.deleteFile(file);
          if (!ok && context.mounted) _showError(context, browser.errorMessage);
        }
        break;
    }
  }

  Future<void> _downloadAndOpen(BuildContext context, CloudFile file) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Downloading ${file.originalName}...'),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      final bytes = await FileService().downloadBytes(file.id);
      if (!context.mounted) return;
      messenger.hideCurrentSnackBar();
      await saveAndOpenBytes(bytes, file.originalName, mimeType: file.mimeType);
    } catch (e) {
      if (context.mounted) _showError(context, e.toString());
    }
  }

  void _showError(BuildContext context, String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Something went wrong')),
    );
  }

  // ---- Add sheet (new folder / upload) ----

  void _showAddSheet(BuildContext context, BrowserProvider browser) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final name = await showTextInputDialog(
                  context,
                  title: 'New folder',
                  confirmLabel: 'Create',
                  hintText: 'Folder name',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                );
                if (name != null && name.isNotEmpty && context.mounted) {
                  final ok = await browser.createFolder(name);
                  if (!ok && context.mounted)
                    _showError(context, browser.errorMessage);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Upload files'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final uploadProvider = context.read<UploadProvider>();
                final uploaded = await uploadProvider.pickAndUpload(
                  folderId: browser.currentFolderId,
                );
                if (uploaded != null && context.mounted) {
                  browser.refresh();
                  context.read<AuthProvider>().refreshProfile();
                } else if (uploadProvider.errorMessage != null &&
                    context.mounted) {
                  _showError(context, uploadProvider.errorMessage);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
