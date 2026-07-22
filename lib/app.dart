import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'core/admin_api.dart';
import 'core/session_store.dart';
import 'core/update_service.dart';
import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';

class EinnyadAdminApp extends StatefulWidget {
  const EinnyadAdminApp({super.key});

  @override
  State<EinnyadAdminApp> createState() => _EinnyadAdminAppState();
}

class _EinnyadAdminAppState extends State<EinnyadAdminApp> {
  late final SessionStore _store;
  late final AdminController _controller;

  @override
  void initState() {
    super.initState();
    _store = SessionStore();
    _controller = AdminController(AdminApi(), _store, UpdateService(_store))
      ..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'EinnyadNails Admin',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return switch (_controller.status) {
          AdminStatus.initializing => const _SplashScreen(),
          AdminStatus.signedOut => LoginScreen(controller: _controller),
          AdminStatus.ready => AdminShell(controller: _controller),
        };
      },
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 104),
            const SizedBox(height: 24),
            Text(
              'EinnyadNails Admin',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}
