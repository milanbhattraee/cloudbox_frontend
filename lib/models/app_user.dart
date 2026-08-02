class AppUser {
  final String id;
  final String? firebaseUid;
  final String email;
  final String? fullName;
  final String? photoUrl;
  final int storageUsed;
  final int storageLimit;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    this.firebaseUid,
    required this.email,
    this.fullName,
    this.photoUrl,
    required this.storageUsed,
    required this.storageLimit,
    this.createdAt,
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
    );
  }

  AppUser copyWith({int? storageUsed, int? storageLimit}) {
    return AppUser(
      id: id,
      firebaseUid: firebaseUid,
      email: email,
      fullName: fullName,
      photoUrl: photoUrl,
      storageUsed: storageUsed ?? this.storageUsed,
      storageLimit: storageLimit ?? this.storageLimit,
      createdAt: createdAt,
    );
  }
}
