import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

import '../core/network/api_client.dart';
import '../models/cloud_file.dart';
import '../models/paginated_files.dart';

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
    try {
      final formData = FormData();
      if (folderId != null) {
        formData.fields.add(MapEntry('folderId', folderId));
      }
      for (final f in files) {
        final bytes = f.bytes;
        if (bytes == null) continue;
        formData.files.add(
          MapEntry('files', MultipartFile.fromBytes(bytes, filename: f.name)),
        );
      }

      final response = await _dio.post(
        '/files/upload',
        data: formData,
        onSendProgress: onProgress,
      );
      final list = response.data['data']['files'] as List<dynamic>;
      return list.map((e) => CloudFile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
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
    try {
      final response = await _dio.put('/files/$id', data: {'originalName': originalName});
      return CloudFile.fromJson(response.data['data']['file'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFile> moveFile(String id, {String? folderId}) async {
    try {
      final response = await _dio.put('/files/$id', data: {'folderId': folderId});
      return CloudFile.fromJson(response.data['data']['file'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> deleteFile(String id) async {
    try {
      await _dio.delete('/files/$id');
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
