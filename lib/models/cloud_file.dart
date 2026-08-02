import 'file_category.dart';

class CloudFile {
  final String id;
  final String originalName;
  final String storedName;
  final String extension;
  final String mimeType;
  final int size;
  final String path;
  final FileCategory category;
  final String? folderId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CloudFile({
    required this.id,
    required this.originalName,
    required this.storedName,
    required this.extension,
    required this.mimeType,
    required this.size,
    required this.path,
    required this.category,
    this.folderId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isImage => category == FileCategory.image;

  factory CloudFile.fromJson(Map<String, dynamic> json) {
    return CloudFile(
      id: json['id'] as String,
      originalName: json['originalName'] as String,
      storedName: json['storedName'] as String,
      extension: (json['extension'] as String?) ?? '',
      mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
      // BigInt field, serialized as a string by the backend.
      size: int.tryParse(json['size']?.toString() ?? '0') ?? 0,
      path: (json['path'] as String?) ?? '',
      category: FileCategoryX.fromApiValue(json['category'] as String?),
      folderId: json['folderId'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}
