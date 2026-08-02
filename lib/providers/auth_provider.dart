import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _authSub = _authService.authStateChanges.listen(_onFirebaseUserChanged);
  }

  final AuthService _authService;
  late final StreamSubscription _authSub;

  AuthStatus status = AuthStatus.unknown;
  AppUser? currentUser;
  String? errorMessage;
  bool isBusy = false;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  Future<void> _onFirebaseUserChanged(dynamic user) async {
    if (user == null) {
      currentUser = null;
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    // A Firebase user exists locally; sync/create the matching backend
    // User row and pull their profile (storage quota, etc.) before we
    // consider the session fully "authenticated".
    try {
      final synced = await _authService.syncWithBackend();
      currentUser = synced;
      status = AuthStatus.authenticated;
    } catch (e) {
      errorMessage = (e is ApiException ? e.displayMessage : e.toString());
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _run(
        () => _authService.signInWithEmail(email: email, password: password));
  }

  Future<bool> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return _run(() => _authService.registerWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        ));
  }

  Future<bool> sendPasswordReset(String email) async {
    return _run(() => _authService.sendPasswordReset(email));
  }

  Future<bool> signInWithGoogle() async {
    return _run(() => _authService.signInWithGoogle());
  }

  Future<bool> registerWithGoogle() async {
    return _run(() => _authService.registerWithGoogle());
  }

  Future<void> signOut() async {
    await _authService.notifyBackendLogout();
    await _authService.signOut();
  }

  /// Re-fetches the profile (e.g. after an upload changes storageUsed).
  Future<void> refreshProfile() async {
    try {
      currentUser = await _authService.fetchProfile();
      notifyListeners();
    } catch (_) {
      // Non-fatal — keep showing the last known quota.
    }
  }

  Future<bool> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      errorMessage = (e is ApiException ? e.displayMessage : e.toString());
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
