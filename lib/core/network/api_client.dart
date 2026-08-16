import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin wrapper around a configured [Dio] instance shared by every service.
///
/// Responsibilities:
///  - attach `Authorization: Bearer <token>` to every request
///  - convert any failure into an [ApiException] with a friendly message
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        // Default validateStatus (only 2xx is a "success") is what we want:
        // any 4xx/5xx throws a DioException we can normalize below.
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  String? _authToken;

  Dio get dio => _dio;

  /// Set authentication token for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clear authentication token
  void clearAuthToken() {
    _authToken = null;
  }

  /// Converts any error thrown while awaiting a Dio call into an
  /// [ApiException]. Wrap service-layer calls with this, e.g.:
  ///   try { ... } catch (e) { throw ApiClient.toApiException(e); }
  static ApiException toApiException(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      if (error.response != null) {
        // Server responded with an error status code
        return ApiException.fromResponseData(
          error.response!.data,
          statusCode: error.response!.statusCode,
        );
      }
      // No response received - connection issue
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return ApiException(
            message: 'Connection timed out. The server may be busy or down.',
            code: 'TIMEOUT',
          );
        case DioExceptionType.connectionError:
          return ApiException(
            message: 'Could not reach the server. Please check your internet connection.',
            code: 'CONNECTION_ERROR',
          );
        case DioExceptionType.cancel:
          return ApiException(
            message: 'Request cancelled.',
            code: 'CANCELLED',
          );
        case DioExceptionType.badCertificate:
          return ApiException(
            message: 'Security certificate error. Cannot connect securely.',
            code: 'BAD_CERTIFICATE',
          );
        case DioExceptionType.badResponse:
          return ApiException(
            message: 'Server returned an invalid response.',
            code: 'BAD_RESPONSE',
          );
        case DioExceptionType.unknown:
        default:
          return ApiException(
            message: error.message ?? 'Network error occurred.',
            code: 'UNKNOWN',
          );
      }
    }
    return ApiException(message: error.toString());
  }
}
