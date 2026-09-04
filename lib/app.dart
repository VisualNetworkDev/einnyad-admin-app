import 'dart:async';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'core/admin_api.dart';
import 'core/notification_service.dart';
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

class _EinnyadAdminAppState extends State<EinnyadAdminApp>
    with WidgetsBindingObserver {
  late final SessionStore _store;
  late final NotificationService _notifications;
  late final AdminController _controller;
  bool _notificationsStarting = false;
  bool _notificationsReady = false;
  bool _resumeSyncRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store = SessionStore();
    _notifications = NotificationService(store: _store);
    _controller = AdminController(AdminApi(), _store, UpdateService(_store));
    _controller.addListener(_handleControllerChange);
    unawaited(_controller.initialize());
  }

  void _handleControllerChange() {
    if (_controller.status != AdminStatus.ready) return;
    if (!_notificationsReady && !_notificationsStarting) {
      _notificationsStarting = true;
      unawaited(_activateNotifications());
      return;
    }
    if (_notificationsReady && !_controller.busy) {
      unawaited(
        _notifications.rememberVisibleAppointments(_controller.appointments),
      );
    }
  }

  Future<void> _activateNotifications() async {
    try {
      await _notifications.activate(
        currentAppointments: _controller.appointments,
      );
      _notificationsReady = true;
    } catch (error) {
      debugPrint('No se pudieron activar las notificaciones: $error');
    } finally {
      _notificationsStarting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _notificationsReady &&
        _controller.status == AdminStatus.ready) {
      unawaited(_syncAfterResume());
    }
  }

  Future<void> _syncAfterResume() async {
    if (_resumeSyncRunning) return;
    _resumeSyncRunning = true;
    try {
      await _notifications.checkNow();
      if (_controller.status == AdminStatus.ready && !_controller.busy) {
        await _controller.refresh(message: 'Actualizando reservaciones…');
      }
    } catch (error) {
      debugPrint('No se pudo sincronizar al volver a la app: $error');
    } finally {
      _resumeSyncRunning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_handleControllerChange);
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
