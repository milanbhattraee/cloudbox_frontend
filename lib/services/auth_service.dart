import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/app_user.dart';

class AuthService {
  FirebaseAuth get _firebaseAuth => FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get firebaseUser => _firebaseAuth.currentUser;

  Future<void> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    // Additional validation
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ApiException(message: 'Email is required');
    }
    if (password.length < 6) {
      throw ApiException(message: 'Password must be at least 6 characters');
    }

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      if (displayName != null && displayName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
        await credential.user?.reload();
      }
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    // Validation
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ApiException(message: 'Email is required');
    }
    if (password.isEmpty) {
      throw ApiException(message: 'Password is required');
    }

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
          email: trimmedEmail, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ApiException(message: 'Email is required');
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: trimmedEmail);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      // Configure GoogleSignIn with proper scopes
      final googleSignIn = GoogleSignIn(
        scopes: [
          'email',
          'profile',
        ],
      );

      // Sign out first to ensure account picker shows
      await googleSignIn.signOut();
      
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw ApiException(message: 'Google sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      
      // Verify we have the required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw ApiException(
          message: 'Failed to get authentication tokens from Google.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        message: 'Google sign-in failed: ${e.toString()}',
      );
    }
  }

  Future<void> registerWithGoogle() async {
    // For Google auth, register and sign-in are the same flow
    // Firebase automatically creates a new user on first sign-in
    await signInWithGoogle();
  }

  Future<void> signOut() async {
    // Sign out from both Firebase and Google
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {
      // Ignore Google sign-out errors as user might not have signed in with Google
    }
    await _firebaseAuth.signOut();
  }

  /// POST /auth/login — verifies the current Firebase ID token server-side
  /// and creates/refreshes the matching local User row. Must be called
  /// right after every successful Firebase sign-in/sign-up, since every
  /// other endpoint requires the local User row to already exist.
  Future<AppUser> syncWithBackend() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw ApiException(message: 'No authenticated Firebase user found.');
      }

      // Force token refresh to ensure it's valid
      await user.getIdToken(true);
      
      final response = await ApiClient.instance.dio.post(
        '/auth/login',
        options: Options(
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      
      if (response.data?['data']?['user'] == null) {
        throw ApiException(
          message: 'Invalid server response during login sync',
        );
      }
      
      final data = response.data['data']['user'] as Map<String, dynamic>;
      return AppUser.fromJson(data);
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
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

  /// POST /auth/logout — best-effort; local sign-out happens regardless.
  Future<void> notifyBackendLogout() async {
    try {
      await ApiClient.instance.dio.post('/auth/logout');
    } catch (_) {
      // Non-fatal: the token will simply stop being sent after signOut().
    }
  }

  ApiException _mapFirebaseError(FirebaseAuthException e) {
    final message = switch (e.code) {
      'invalid-email' => 'That email address looks invalid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found with that email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists with that email.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'network-request-failed' => 'Network error. Check your connection.',
      _ => e.message ?? 'Authentication failed.',
    };
    return ApiException(message: message, code: e.code);
  }
}
