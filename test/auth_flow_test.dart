import 'package:cloudbox_app/firebase_options.dart';
import 'package:cloudbox_app/providers/auth_provider.dart' as app_auth;
import 'package:cloudbox_app/screens/auth/login_screen.dart';
import 'package:cloudbox_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeAuthService extends AuthService {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  });

  testWidgets('login screen exposes a Google sign-in action', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => app_auth.AuthProvider(authService: FakeAuthService()),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
