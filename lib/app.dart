import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/browser_provider.dart';
import 'providers/upload_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/splash/splash_screen.dart';

class CloudBoxApp extends StatelessWidget {
  const CloudBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BrowserProvider()),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Swaps between splash / login / home based on [AuthProvider.status].
/// Also resets the browser to the root folder whenever a new session
/// starts, so a freshly-signed-in user never sees a stale browse state
/// left over from a previous account.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  AuthStatus? _lastStatus;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.authenticated && _lastStatus != AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<BrowserProvider>().init();
      });
    }
    _lastStatus = auth.status;

    switch (auth.status) {
      case AuthStatus.unknown:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
        return const HomeScreen();
    }
  }
}
