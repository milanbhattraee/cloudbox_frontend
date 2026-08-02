import '../core/network/api_client.dart';
import '../models/cloud_folder.dart';

class FolderService {
  final _dio = ApiClient.instance.dio;

  /// [parentFolderId] pass null for top-level.
  Future<List<CloudFolder>> listFolders({String? parentFolderId}) async {
    try {
      final response = await _dio.get('/folders', queryParameters: {
        'parentFolderId': parentFolderId ?? 'root',
      });
      final list = response.data['data']['folders'] as List<dynamic>;
      return list.map((e) => CloudFolder.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFolder> createFolder({required String name, String? parentFolderId}) async {
    try {
      final response = await _dio.post('/folders', data: {
        'name': name,
        if (parentFolderId != null) 'parentFolderId': parentFolderId,
      });
      return CloudFolder.fromJson(response.data['data']['folder'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFolder> getFolder(String id) async {
    try {
      final response = await _dio.get('/folders/$id');
      return CloudFolder.fromJson(response.data['data']['folder'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFolder> renameFolder(String id, String name) async {
    try {
      final response = await _dio.put('/folders/$id', data: {'name': name});
      return CloudFolder.fromJson(response.data['data']['folder'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<CloudFolder> moveFolder(String id, {String? parentFolderId}) async {
    try {
      final response = await _dio.put('/folders/$id', data: {
        'parentFolderId': parentFolderId,
      });
      return CloudFolder.fromJson(response.data['data']['folder'] as Map<String, dynamic>);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Returns how many files were deleted along with the folder (cascade).
  Future<int> deleteFolder(String id) async {
    try {
      final response = await _dio.delete('/folders/$id');
      return (response.data['data']['deletedFiles'] as num?)?.toInt() ?? 0;
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
