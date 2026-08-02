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
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
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
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw ApiException(message: 'Google sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException(message: 'Google sign-in failed. Please try again.');
    }
  }

  Future<void> registerWithGoogle() async {
    await signInWithGoogle();
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  /// POST /auth/login — verifies the current Firebase ID token server-side
  /// and creates/refreshes the matching local User row. Must be called
  /// right after every successful Firebase sign-in/sign-up, since every
  /// other endpoint requires the local User row to already exist.
  Future<AppUser> syncWithBackend() async {
    try {
      final response = await ApiClient.instance.dio.post('/auth/login');
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
