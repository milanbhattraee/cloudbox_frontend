import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _initialize();
  }

  final AuthService _authService;

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isBusy = false;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Initialize the auth provider by checking for stored credentials
  Future<void> _initialize() async {
    await _authService.initialize();
    
    if (_authService.isAuthenticated) {
      // Try to load user profile
      try {
        currentUser = await _authService.fetchProfile();
        status = AuthStatus.authenticated;
        debugPrint('[AuthProvider] Restored authenticated session');
      } catch (e) {
        // Token might be expired, sign out
        await _authService.signOut();
        status = AuthStatus.unauthenticated;
        debugPrint('[AuthProvider] Stored token invalid, signed out');
      }
    } else {
      status = AuthStatus.unauthenticated;
      debugPrint('[AuthProvider] No stored credentials');
    }
    
    notifyListeners();
  }

  /// Sign in with email and password
  Future<bool> signIn({required String email, required String password}) async {
    return _run(() async {
      final user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      currentUser = user;
      status = AuthStatus.authenticated;
    });
  }

  /// Register new user
  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _run(() async {
      final user = await _authService.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      currentUser = user;
      status = AuthStatus.authenticated;
    });
  }

  /// Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    return _run(() => _authService.sendPasswordReset(email));
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Re-fetches the profile (e.g. after an upload changes storageUsed).
  Future<void> refreshProfile() async {
    try {
      currentUser = await _authService.fetchProfile();
      notifyListeners();
    } catch (e) {
      debugPrint('[AuthProvider] Failed to refresh profile: $e');
      // Non-fatal — keep showing the last known data
    }
  }

  /// Helper to run async actions with loading state
  Future<bool> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    
    try {
      await action();
      return true;
    } catch (e) {
      errorMessage = (e is ApiException ? e.displayMessage : e.toString());
      debugPrint('[AuthProvider] Error: $errorMessage');
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
