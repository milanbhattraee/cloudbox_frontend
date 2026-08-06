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
    Map<String, dynamic>? metadata,
    void Function(int sent, int total)? onProgress,
    int maxRetries = 3,
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

    int attempt = 0;
    Exception? lastError;

    while (attempt < maxRetries) {
      attempt++;
      
      try {
        final formData = FormData();
        if (folderId != null && folderId.isNotEmpty) {
          formData.fields.add(MapEntry('folderId', folderId));
        }
        
        // Add sync metadata if provided
        if (metadata != null) {
          metadata.forEach((key, value) {
            if (value != null) {
              formData.fields.add(MapEntry(key, value.toString()));
            }
          });
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

        debugPrint('[FileService] Uploading $totalFilesAdded file(s), attempt $attempt/$maxRetries');

        final response = await _dio.post(
          '/files/upload',
          data: formData,
          onSendProgress: onProgress,
          options: Options(
            sendTimeout: const Duration(minutes: 5), // Allow time for large files
            receiveTimeout: const Duration(minutes: 5),
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
        lastError = e as Exception;
        debugPrint('[FileService] Upload attempt $attempt failed: $e');
        
        // Don't retry on client errors (400-499)
        if (e is DioException && 
            e.response?.statusCode != null && 
            e.response!.statusCode! >= 400 && 
            e.response!.statusCode! < 500) {
          debugPrint('[FileService] Client error, not retrying');
          throw ApiClient.toApiException(e);
        }
        
        // Wait before retry (exponential backoff)
        if (attempt < maxRetries) {
          final delayMs = 1000 * attempt; // 1s, 2s, 3s
          debugPrint('[FileService] Retrying in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      }
    }
    
    debugPrint('[FileService] All upload attempts failed');
    throw ApiClient.toApiException(lastError ?? Exception('Upload failed after $maxRetries attempts'));
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
