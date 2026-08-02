/// Mirrors the backend's error response shape:
/// { success: false, message, code, details? }
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;
  final List<dynamic>? details;

  ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  factory ApiException.fromResponseData(dynamic data, {int? statusCode}) {
    if (data is Map<String, dynamic>) {
      return ApiException(
        message: (data['message'] as String?) ?? 'Something went wrong',
        statusCode: statusCode,
        code: data['code'] as String?,
        details: data['details'] as List<dynamic>?,
      );
    }
    return ApiException(
      message: 'Something went wrong',
      statusCode: statusCode,
    );
  }

  /// A friendlier version for showing in a SnackBar, folding in the first
  /// field-level validation error if there is one.
  String get displayMessage {
    if (details != null && details!.isNotEmpty) {
      final first = details!.first;
      if (first is Map && first['message'] != null) {
        return first['message'].toString();
      }
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
