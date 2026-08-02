class CloudFolder {
  final String id;
  final String name;
  final String? parentFolderId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int subFolderCount;
  final int fileCount;

  CloudFolder({
    required this.id,
    required this.name,
    this.parentFolderId,
    this.createdAt,
    this.updatedAt,
    this.subFolderCount = 0,
    this.fileCount = 0,
  });

  factory CloudFolder.fromJson(Map<String, dynamic> json) {
    final count = json['_count'] as Map<String, dynamic>?;
    return CloudFolder(
      id: json['id'] as String,
      name: json['name'] as String,
      parentFolderId: json['parentFolderId'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      subFolderCount: (count?['subFolders'] as num?)?.toInt() ?? 0,
      fileCount: (count?['files'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isEmpty => subFolderCount == 0 && fileCount == 0;
}
