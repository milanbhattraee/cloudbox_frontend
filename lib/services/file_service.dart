import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../models/cloud_file.dart';
import '../models/paginated_files.dart';

// Re-export PlatformFile for convenience
export 'package:file_picker/file_picker.dart' show PlatformFile;

class FileService {
  final _dio = ApiClient.instance.dio;

  /// Uploads one or more files already picked via [FilePicker] with
  /// `withData: true` (so `.bytes` is populated on every platform,
  /// including web where `.path` is always null). [onProgress] receives
  /// (sentBytes, totalBytes) for the whole batch.
  Future<List<CloudFile>> uploadFiles({
    required List<PlatformFile> files,
    String? folderId,
    void Function(int sent, int total)? onProgress,
  }) async {
    // Validation
    if (files.isEmpty) {
      throw ApiClient.toApiException(
        Exception('No files selected for upload'),
      );
    }

    // Validate file sizes
    const maxFileSize = 100 * 1024 * 1024; // 100MB
    for (final file in files) {
      if (file.size > maxFileSize) {
        throw ApiClient.toApiException(
          Exception('File "${file.name}" exceeds maximum size of 100MB'),
        );
      }
      if (file.size == 0) {
        throw ApiClient.toApiException(
          Exception('File "${file.name}" is empty'),
        );
      }
    }

    try {
      final formData = FormData();
      if (folderId != null && folderId.isNotEmpty) {
        formData.fields.add(MapEntry('folderId', folderId));
      }
      
      int totalFilesAdded = 0;
      for (final f in files) {
        final bytes = f.bytes;
        if (bytes == null || bytes.isEmpty) {
          debugPrint('[FileService] Skipping ${f.name} - no bytes available');
          continue;
        }
        formData.files.add(
          MapEntry(
            'files',
            MultipartFile.fromBytes(bytes, filename: f.name),
          ),
        );
        totalFilesAdded++;
      }

      if (totalFilesAdded == 0) {
        throw ApiClient.toApiException(
          Exception('No valid files to upload'),
        );
      }

      debugPrint('[FileService] Uploading $totalFilesAdded file(s)...');

      final response = await _dio.post(
        '/files/upload',
        data: formData,
        onSendProgress: onProgress,
        options: Options(
          sendTimeout: const Duration(minutes: 5), // Allow time for large files
        ),
      );
      
      if (response.data?['data']?['files'] == null) {
        throw ApiClient.toApiException(
          Exception('Invalid server response: missing files data'),
        );
      }

      final list = response.data['data']['files'] as List<dynamic>;
      debugPrint('[FileService] Successfully uploaded ${list.length} file(s)');
      
      return list
          .map((e) => CloudFile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[FileService] Upload error: $e');
      throw ApiClient.toApiException(e);
    }
  }

  /// [folderId] null/omitted lists the root folder's files; pass 'root'
  /// explicitly if you need to be unambiguous (the backend treats them
  /// the same way).
  Future<PaginatedFiles> listFiles({
    String? folderId,
    String? search,
    String? category,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get('/files', queryParameters: {
        'folderId': folderId ?? 'root',
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (category != null) 'category': category,
        'page': page,
        'limit': limit,
      });
      final list = response.data['data']['files'] as List<dynamic>;
      final items = list.map((e) => CloudFile.fromJson(e as Map<String, dynamic>)).toList();
      final meta = PageMeta.fromJson(response.data['meta'] as Map<String, dynamic>);
      return PaginatedFiles(items: items, meta: meta);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFile> getFile(String id) async {
    try {
      final response = await _dio.get('/files/$id');
      return CloudFile.fromJson(response.data['data']['file'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Downloads the file into memory. Works on every platform (web
  /// included) and whether the backend is on the local-disk driver
  /// (streams the bytes directly) or the S3 driver (302-redirects to a
  /// presigned URL) — Dio follows redirects transparently either way. Pair
  /// with `saveAndOpenBytes()` (see core/utils/save_file) to hand the
  /// result to the user.
  Future<List<int>> downloadBytes(String id) async {
    try {
      final response = await _dio.get<List<int>>(
        '/files/download/$id',
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data ?? <int>[];
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFile> renameFile(String id, String originalName) async {
    // Validation
    if (id.trim().isEmpty) {
      throw ApiClient.toApiException(Exception('File ID is required'));
    }
    if (originalName.trim().isEmpty) {
      throw ApiClient.toApiException(Exception('File name cannot be empty'));
    }
    if (originalName.length > 255) {
      throw ApiClient.toApiException(
        Exception('File name is too long (max 255 characters)'),
      );
    }

    try {
      final response = await _dio.put(
        '/files/$id',
        data: {'originalName': originalName.trim()},
      );
      return CloudFile.fromJson(
          response.data['data']['file'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFile> moveFile(String id, {String? folderId}) async {
    // Validation
    if (id.trim().isEmpty) {
      throw ApiClient.toApiException(Exception('File ID is required'));
    }

    try {
      final response = await _dio.put('/files/$id', data: {'folderId': folderId});
      return CloudFile.fromJson(
          response.data['data']['file'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteFile(String id) async {
    // Validation
    if (id.trim().isEmpty) {
      throw ApiClient.toApiException(Exception('File ID is required'));
    }

    try {
      await _dio.delete('/files/$id');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
