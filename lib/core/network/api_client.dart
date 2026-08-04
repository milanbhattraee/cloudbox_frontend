import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Thin wrapper around a configured [Dio] instance shared by every service.
///
/// Responsibilities:
///  - attach `Authorization: Bearer <Firebase ID token>` to every request
///  - transparently refresh the token and retry once on a 401
///  - convert any failure into an [ApiException] with a friendly message
///    (see [ApiClient.toApiException], used by every service method)
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
          final token = await _currentIdToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // One retry after a forced token refresh, in case the token
          // expired between requests (Firebase ID tokens last ~1 hour but
          // can be invalidated earlier, e.g. after revokeRefreshTokens).
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          if (error.response?.statusCode == 401 && !alreadyRetried) {
            final refreshed = await _currentIdToken(forceRefresh: true);
            if (refreshed != null) {
              final retryOptions = error.requestOptions;
              retryOptions.extra['retried'] = true;
              retryOptions.headers['Authorization'] = 'Bearer $refreshed';
              try {
                final response = await _dio.fetch(retryOptions);
                handler.resolve(response);
                return;
              } catch (_) {
                // fall through to normal error handling below
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;

  static Future<String?> _currentIdToken({bool forceRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
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
