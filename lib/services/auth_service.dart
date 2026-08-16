import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/app_user.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  String? _authToken;
  String? _userId;

  /// Get current auth token
  String? get authToken => _authToken;

  /// Check if user is authenticated
  bool get isAuthenticated => _authToken != null && _userId != null;

  /// Initialize auth service by loading stored token
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString(_tokenKey);
      _userId = prefs.getString(_userIdKey);
      
      if (_authToken != null) {
        debugPrint('[AuthService] Loaded existing token');
        // Set token in API client
        ApiClient.instance.setAuthToken(_authToken!);
      }
    } catch (e) {
      debugPrint('[AuthService] Failed to load token: $e');
    }
  }

  /// Register new user with email and password
  Future<AppUser> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    // Validation
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ApiException(message: 'Email is required');
    }
    if (password.length < 6) {
      throw ApiException(message: 'Password must be at least 6 characters');
    }

    try {
      debugPrint('[AuthService] Registering user: $trimmedEmail');
      
      final response = await ApiClient.instance.dio.post(
        '/auth/register',
        data: {
          'email': trimmedEmail,
          'password': password,
          'fullName': displayName?.trim(),
        },
      );

      if (response.data?['data']?['user'] == null || 
          response.data?['data']?['token'] == null) {
        throw ApiException(message: 'Invalid server response during registration');
      }

      // Save token and user ID
      final token = response.data['data']['token'] as String;
      final userData = response.data['data']['user'] as Map<String, dynamic>;
      final user = AppUser.fromJson(userData);

      await _saveAuthData(token, user.id);
      
      debugPrint('[AuthService] Registration successful');
      return user;
    } catch (e) {
      debugPrint('[AuthService] Registration error: $e');
      throw ApiClient.toApiException(e);
    }
  }

  /// Sign in with email and password
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Validation
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ApiException(message: 'Email is required');
    }
    if (password.isEmpty) {
      throw ApiException(message: 'Password is required');
    }

    try {
      debugPrint('[AuthService] Signing in: $trimmedEmail');
      debugPrint('[AuthService] Backend URL: ${ApiClient.instance.dio.options.baseUrl}');
      
      final response = await ApiClient.instance.dio.post(
        '/auth/login',
        data: {
          'email': trimmedEmail,
          'password': password,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      debugPrint('[AuthService] Login response status: ${response.statusCode}');

      if (response.data?['data']?['user'] == null || 
          response.data?['data']?['token'] == null) {
        throw ApiException(message: 'Invalid server response during login');
      }

      // Save token and user ID
      final token = response.data['data']['token'] as String;
      final userData = response.data['data']['user'] as Map<String, dynamic>;
      final user = AppUser.fromJson(userData);

      await _saveAuthData(token, user.id);
      
      debugPrint('[AuthService] Login successful');
      return user;
    } catch (e) {
      debugPrint('[AuthService] Login error: $e');
      throw ApiClient.toApiException(e);
    }
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ApiException(message: 'Email is required');
    }

    try {
      debugPrint('[AuthService] Requesting password reset for: $trimmedEmail');
      
      await ApiClient.instance.dio.post(
        '/auth/forgot-password',
        data: {'email': trimmedEmail},
      );
      
      debugPrint('[AuthService] Password reset email sent');
    } catch (e) {
      debugPrint('[AuthService] Password reset error: $e');
      throw ApiClient.toApiException(e);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Notify backend
      await notifyBackendLogout();
    } catch (e) {
      debugPrint('[AuthService] Logout notification failed: $e');
    }

    // Clear local auth data
    await _clearAuthData();
    debugPrint('[AuthService] Signed out');
  }

  /// GET /auth/profile
  Future<AppUser> fetchProfile() async {
    try {
      final response = await ApiClient.instance.dio.get('/auth/profile');
      
      if (response.data?['data']?['user'] == null) {
        throw ApiException(message: 'Invalid profile response from server');
      }
      
      final data = response.data['data']['user'] as Map<String, dynamic>;
      return AppUser.fromJson(data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// POST /auth/logout
  Future<void> notifyBackendLogout() async {
    try {
      await ApiClient.instance.dio.post('/auth/logout');
    } catch (_) {
      // Non-fatal: local sign-out happens regardless
    }
  }

  /// Save authentication data to local storage
  Future<void> _saveAuthData(String token, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userIdKey, userId);
      
      _authToken = token;
      _userId = userId;
      
      // Set token in API client for future requests
      ApiClient.instance.setAuthToken(token);
      
      debugPrint('[AuthService] Saved auth data');
    } catch (e) {
      debugPrint('[AuthService] Failed to save auth data: $e');
    }
  }

  /// Clear authentication data from local storage
  Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      
      _authToken = null;
      _userId = null;
      
      // Clear token from API client
      ApiClient.instance.clearAuthToken();
      
      debugPrint('[AuthService] Cleared auth data');
    } catch (e) {
      debugPrint('[AuthService] Failed to clear auth data: $e');
    }
  }
}
