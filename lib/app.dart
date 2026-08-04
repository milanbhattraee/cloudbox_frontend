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
import 'services/connectivity_service.dart';
import 'widgets/server_down_screen.dart';

class CloudBoxApp extends StatelessWidget {
  const CloudBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: ConnectivityService.instance,
        ),
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
        home: const _ConnectivityGate(),
      ),
    );
  }
}

/// First checks connectivity, then swaps between splash / login / home
class _ConnectivityGate extends StatelessWidget {
  const _ConnectivityGate();

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();

    // Show server down screen if offline or server unavailable
    if (connectivity.status == ConnectivityStatus.offline ||
        connectivity.status == ConnectivityStatus.serverDown) {
      return const ServerDownScreen();
    }

    // If still checking connectivity, show splash
    if (connectivity.status == ConnectivityStatus.checking) {
      return const SplashScreen();
    }

    // Online - proceed to auth gate
    return const _AuthGate();
  }
}

/// Swaps between splash / login / home based on [AuthProvider.status].
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
