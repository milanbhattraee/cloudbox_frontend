import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../models/cloud_file.dart';
import '../models/cloud_folder.dart';
import '../models/file_category.dart';
import '../services/file_service.dart';
import '../services/folder_service.dart';

/// One entry in the breadcrumb trail. The root of the trail (index -1, not
/// stored) is implicitly "My Files" / folderId == null.
class _BreadcrumbEntry {
  final String id;
  final String name;
  _BreadcrumbEntry(this.id, this.name);
}

class BrowserProvider extends ChangeNotifier {
  BrowserProvider({FolderService? folderService, FileService? fileService})
      : _folderService = folderService ?? FolderService(),
        _fileService = fileService ?? FileService();

  final FolderService _folderService;
  final FileService _fileService;

  final List<_BreadcrumbEntry> _trail = [];
  Timer? _searchDebounce;
  
  // Simple cache for folder contents
  final Map<String, List<CloudFolder>> _folderCache = {};
  final Map<String, DateTime> _folderCacheTime = {};
  static const _cacheDuration = Duration(minutes: 5);

  List<CloudFolder> folders = [];
  List<CloudFile> files = [];
  int _page = 1;
  int _totalPages = 1;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;

  String? searchQuery;
  FileCategory? categoryFilter;

  /// null means "My Files" (root).
  String? get currentFolderId => _trail.isEmpty ? null : _trail.last.id;
  String get currentFolderName =>
      _trail.isEmpty ? 'My Files' : _trail.last.name;
  List<String> get breadcrumbNames =>
      ['My Files', ..._trail.map((e) => e.name)];
  bool get isAtRoot => _trail.isEmpty;
  bool get hasMoreFiles => _page < _totalPages;
  bool get hasActiveFilters =>
      (searchQuery?.isNotEmpty ?? false) || categoryFilter != null;

  Future<void> init() => refresh();

  Future<void> startFreshSession() async {
    _trail.clear();
    folders = [];
    files = [];
    _page = 1;
    _totalPages = 1;
    searchQuery = null;
    categoryFilter = null;
    errorMessage = null;
    isLoading = false;
    isLoadingMore = false;
    notifyListeners();
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      // Check cache for folders first
      final cacheKey = currentFolderId ?? 'root';
      final cachedTime = _folderCacheTime[cacheKey];
      final isCacheValid = cachedTime != null && 
          DateTime.now().difference(cachedTime) < _cacheDuration;
      
      List<CloudFolder> foldersList;
      if (isCacheValid && _folderCache.containsKey(cacheKey)) {
        foldersList = _folderCache[cacheKey]!;
      } else {
        foldersList = await _folderService.listFolders(parentFolderId: currentFolderId);
        _folderCache[cacheKey] = foldersList;
        _folderCacheTime[cacheKey] = DateTime.now();
      }
      
      final paginated = await _fileService.listFiles(
        folderId: currentFolderId,
        search: searchQuery,
        category: categoryFilter?.apiValue,
        page: 1,
        limit: AppConfig.defaultPageSize,
      );
      
      folders = foldersList;
      files = paginated.items;
      _page = paginated.meta.page;
      _totalPages = paginated.meta.totalPages;
    } catch (e) {
      errorMessage = e is ApiException ? e.displayMessage : e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreFiles() async {
    if (!hasMoreFiles || isLoadingMore) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      final paginated = await _fileService.listFiles(
        folderId: currentFolderId,
        search: searchQuery,
        category: categoryFilter?.apiValue,
        page: _page + 1,
        limit: AppConfig.defaultPageSize,
      );
      files = [...files, ...paginated.items];
      _page = paginated.meta.page;
      _totalPages = paginated.meta.totalPages;
    } catch (e) {
      errorMessage = e is ApiException ? e.displayMessage : e.toString();
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> openFolder(CloudFolder folder) async {
    _trail.add(_BreadcrumbEntry(folder.id, folder.name));
    notifyListeners(); // Immediate UI update
    await refresh();
  }

  Future<void> goToBreadcrumb(int index) async {
    // index 0 == "My Files" (root); index i>0 == _trail[i-1]
    if (index <= 0) {
      _trail.clear();
    } else {
      _trail.removeRange(index, _trail.length);
    }
    notifyListeners(); // Immediate UI update
    await refresh();
  }

  Future<void> goUp() async {
    if (_trail.isNotEmpty) {
      _trail.removeLast();
      notifyListeners(); // Immediate UI update
      await refresh();
    }
  }

  /// Navigate to root folder
  Future<void> goToRoot() async {
    if (_trail.isNotEmpty) {
      _trail.clear();
      notifyListeners();
      await refresh();
    }
  }

  Future<void> setSearch(String? query) async {
    final trimmedQuery = query?.trim();
    if (searchQuery == trimmedQuery) return; // No change
    
    searchQuery = trimmedQuery?.isEmpty ?? true ? null : trimmedQuery;
    
    // Debounce search - wait 500ms before actual search
    _searchDebounce?.cancel();
    
    // If query is null/empty, refresh immediately (no debounce for clearing search)
    if (searchQuery == null) {
      notifyListeners();
      await refresh();
    } else {
      // Debounce for actual search queries
      notifyListeners();
      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
        refresh();
      });
    }
  }

  Future<void> setCategoryFilter(FileCategory? category) async {
    if (categoryFilter == category) return; // No change
    categoryFilter = category;
    notifyListeners();
    await refresh();
  }

  Future<void> clearFilters() async {
    if (searchQuery == null && categoryFilter == null) return;
    searchQuery = null;
    categoryFilter = null;
    notifyListeners();
    await refresh();
  }

  // ---- Folder mutations ----

  Future<bool> createFolder(String name) => _runMutation(() async {
        await _folderService.createFolder(
            name: name, parentFolderId: currentFolderId);
        _invalidateCache(currentFolderId);
        await refresh();
      });

  Future<bool> renameFolder(CloudFolder folder, String newName) =>
      _runMutation(() async {
        await _folderService.renameFolder(folder.id, newName);
        _invalidateCache(currentFolderId);
        await refresh();
      });

  Future<bool> moveFolder(CloudFolder folder, String? destinationFolderId) =>
      _runMutation(() async {
        await _folderService.moveFolder(folder.id,
            parentFolderId: destinationFolderId);
        _invalidateCache(currentFolderId);
        _invalidateCache(destinationFolderId);
        await refresh();
      });

  Future<bool> deleteFolder(CloudFolder folder) => _runMutation(() async {
        await _folderService.deleteFolder(folder.id);
        _invalidateCache(currentFolderId);
        await refresh();
      });
  
  void _invalidateCache(String? folderId) {
    final key = folderId ?? 'root';
    _folderCache.remove(key);
    _folderCacheTime.remove(key);
  }
  
  @override
  void dispose() {
    _searchDebounce?.cancel();
    _folderCache.clear();
    _folderCacheTime.clear();
    super.dispose();
  }

  // ---- File mutations ----

  Future<bool> renameFile(CloudFile file, String newName) =>
      _runMutation(() async {
        await _fileService.renameFile(file.id, newName);
        await refresh();
      });

  Future<bool> moveFile(CloudFile file, String? destinationFolderId) =>
      _runMutation(() async {
        await _fileService.moveFile(file.id, folderId: destinationFolderId);
        await refresh();
      });

  Future<bool> deleteFile(CloudFile file) => _runMutation(() async {
        await _fileService.deleteFile(file.id);
        await refresh();
      });

  Future<bool> _runMutation(Future<void> Function() action) async {
    errorMessage = null;
    try {
      await action();
      return true;
    } catch (e) {
      errorMessage = e is ApiException ? e.displayMessage : e.toString();
      notifyListeners();
      return false;
    }
  }
}
