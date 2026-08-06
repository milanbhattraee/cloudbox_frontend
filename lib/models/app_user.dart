class AppUser {
  final String id;
  final String? firebaseUid;
  final String email;
  final String? fullName;
  final String? photoUrl;
  final int storageUsed;
  final int storageLimit;
  final DateTime? createdAt;
  final FileStats? fileStats;

  AppUser({
    required this.id,
    this.firebaseUid,
    required this.email,
    this.fullName,
    this.photoUrl,
    required this.storageUsed,
    required this.storageLimit,
    this.createdAt,
    this.fileStats,
  });

  double get usageFraction => storageLimit <= 0 ? 0 : (storageUsed / storageLimit).clamp(0, 1);

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      firebaseUid: json['firebaseUid'] as String?,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      photoUrl: json['photoUrl'] as String?,
      // BigInt fields are serialized as strings by the backend.
      storageUsed: int.tryParse(json['storageUsed']?.toString() ?? '0') ?? 0,
      storageLimit: int.tryParse(json['storageLimit']?.toString() ?? '0') ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      fileStats: json['fileStats'] != null 
          ? FileStats.fromJson(json['fileStats'] as Map<String, dynamic>)
          : null,
    );
  }

  AppUser copyWith({int? storageUsed, int? storageLimit, FileStats? fileStats}) {
    return AppUser(
      id: id,
      firebaseUid: firebaseUid,
      email: email,
      fullName: fullName,
      photoUrl: photoUrl,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
      createdAt: createdAt,
      fileStats: fileStats ?? this.fileStats,
    );
  }
}

class FileStats {
  final int images;
  final int videos;
  final int documents;
  final int audio;
  final int others;
  final int total;

  FileStats({
    required this.images,
    required this.videos,
    required this.documents,
    required this.audio,
    required this.others,
    required this.total,
  });

  factory FileStats.fromJson(Map<String, dynamic> json) {
    return FileStats(
      images: json['images'] as int? ?? 0,
      videos: json['videos'] as int? ?? 0,
      documents: json['documents'] as int? ?? 0,
      audio: json['audio'] as int? ?? 0,
      others: json['others'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}
