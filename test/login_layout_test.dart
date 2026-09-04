import 'package:einnyad_admin_mobile/app_controller.dart';
import 'package:einnyad_admin_mobile/core/admin_api.dart';
import 'package:einnyad_admin_mobile/core/biometric_access.dart';
import 'package:einnyad_admin_mobile/core/session_store.dart';
import 'package:einnyad_admin_mobile/core/update_service.dart';
import 'package:einnyad_admin_mobile/screens/login_screen.dart';
import 'package:einnyad_admin_mobile/screens/connection_screen.dart';
import 'package:einnyad_admin_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(412, 915),
    const Size(915, 412),
  ]) {
    testWidgets('quick login and recovery fit $size at enlarged text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = SessionStore();
      final controller =
          AdminController(AdminApi(), store, UpdateService(store))
            ..biometricState = const BiometricState(
              available: true,
              enabled: true,
            )
            ..rememberedEmail = 'owner@example.com';
      addTearDown(controller.dispose);
      for (final screen in [
        LoginScreen(controller: controller),
        ConnectionScreen(controller: controller),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
