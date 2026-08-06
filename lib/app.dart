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
import 'services/smart_sync_service.dart';
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
        ChangeNotifierProvider.value(
          value: SmartSyncService.instance,
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
        // Performance optimizations
        builder: (context, child) {
          // Prevent font scaling from affecting layout
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

/// First checks authentication, connectivity is checked only when needed
class _ConnectivityGate extends StatelessWidget {
  const _ConnectivityGate();

  @override
  Widget build(BuildContext context) {
    // App works offline - no need to block based on connectivity
    // Connectivity is only checked when syncing
    return const _AuthGate();
  }
}

/// Swaps between splash / login / home based on [AuthProvider.status].
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Show error snackbar if backend sync failed
    if (auth.status == AuthStatus.unauthenticated && auth.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backend Error: ${auth.errorMessage}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });
    }

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
