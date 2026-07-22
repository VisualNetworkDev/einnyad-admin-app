import 'dart:io';

import 'package:einnyad_admin_mobile/app_controller.dart';
import 'package:einnyad_admin_mobile/core/admin_api.dart';
import 'package:einnyad_admin_mobile/core/session_store.dart';
import 'package:einnyad_admin_mobile/core/update_service.dart';
import 'package:einnyad_admin_mobile/screens/admin_shell.dart';
import 'package:einnyad_admin_mobile/screens/appointments_screen.dart';
import 'package:einnyad_admin_mobile/screens/dashboard_screen.dart';
import 'package:einnyad_admin_mobile/screens/qr_screen.dart';
import 'package:einnyad_admin_mobile/screens/reviews_screen.dart';
import 'package:einnyad_admin_mobile/screens/services_screen.dart';
import 'package:einnyad_admin_mobile/screens/settings_screen.dart';
import 'package:einnyad_admin_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'EinnyadNails Admin',
      packageName: 'com.visualnetworkdev.einnyadAdminMobile',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('all primary screens fit iPhone Pro Max size', (tester) async {
    await _setSize(tester, const Size(430, 932));
    final controller = _controller();
    addTearDown(controller.dispose);
    final screens = <Widget>[
      DashboardScreen(controller: controller, openAppointments: () {}),
      AppointmentsScreen(controller: controller),
      QrScreen(controller: controller),
      ServicesScreen(controller: controller),
      ReviewsScreen(controller: controller),
      SettingsScreen(controller: controller),
      AppointmentForm(controller: controller),
      ServiceForm(controller: controller),
    ];
    for (final screen in screens) {
      await tester.pumpWidget(_app(Material(child: screen)));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: screen.runtimeType.toString(),
      );
    }
  });

  testWidgets('drawer and content fit a large Android phone', (tester) async {
    await _setSize(tester, const Size(412, 915));
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(AdminShell(controller: controller)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    if (Platform.isWindows) {
      await expectLater(
        find.byType(AdminShell),
        matchesGoldenFile('goldens/dashboard_android_large.png'),
      );
    }
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Servicios y fotos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.isWindows) {
      await expectLater(
        find.byType(AdminShell),
        matchesGoldenFile('goldens/drawer_android_large.png'),
      );
    }
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustes del negocio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (Platform.isWindows) {
      await expectLater(
        find.byType(AdminShell),
        matchesGoldenFile('goldens/settings_android_large.png'),
      );
    }
  });

  testWidgets('landscape large phone keeps menu and content separated', (
    tester,
  ) async {
    await _setSize(tester, const Size(932, 430));
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(AdminShell(controller: controller)));
    await tester.pump();
    expect(find.text('EinnyadNails'), findsOneWidget);
    expect(find.text('Estado del negocio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.light, home: home);

AdminController _controller() {
  final store = SessionStore();
  final controller = AdminController(AdminApi(), store, UpdateService(store));
  controller
    ..status = AdminStatus.ready
    ..session = const SavedSession(
      token: 'test-token',
      email: 'owner@example.com',
      name: 'Dueña',
    )
    ..data = {
      'dashboard': {
        'activeCount': 3,
        'todayCount': 1,
        'completedCount': 8,
        'cancelledCount': 1,
        'totalSold': 900,
        'monthSold': 500,
        'pendingMoney': 150,
        'averageTicket': 75,
        'topServices': [
          {'name': 'Manicure en gel', 'count': 4},
        ],
      },
      'appointments': [
        {
          'appointmentId': 'EN-TEST-1',
          'customerName': 'Clienta de prueba con nombre largo',
          'customerPhone': '+1 514 555 0101',
          'customerEmail': 'clienta@example.com',
          'customerAddress': '123 Rue de prueba, Montreal, Quebec',
          'preferredDate': '2026-07-25',
          'preferredTime': '13:30',
          'status': 'Confirmed',
          'total': 80,
          'items': [
            {
              'id': 'N1',
              'name': 'Manicure en gel',
              'nameEs': 'Manicure en gel',
              'price': 80,
              'quantity': 1,
              'lineTotal': 80,
            },
          ],
        },
      ],
      'services': [
        {
          'rowNumber': 2,
          'id': 'N1',
          'category': 'Gel',
          'name': 'Manicure en gel',
          'nameFr': 'Manucure gel',
          'price': 45,
          'durationMinutes': 60,
          'available': 'Yes',
          'image': '',
        },
      ],
      'reviews': [
        {
          'rowNumber': 2,
          'name': 'Mariela',
          'rating': 5,
          'text': 'Excelente servicio y atención.',
          'status': 'Pending',
        },
      ],
      'promotions': [
        {
          'code': 'BIENVENIDA',
          'title': 'Primera cita',
          'type': 'percent',
          'value': 10,
          'active': 'Yes',
        },
      ],
      'config': {
        'name': 'EinnyadNails',
        'ownerName': 'Dueña',
        'phone': '+1 514 555 0101',
        'ownerEmail': 'owner@example.com',
        'serviceArea': 'Montreal, QC',
        'travelFee': 0,
        'qrEnabled': 'Yes',
        'remindersEnabled': 'Yes',
      },
      'payments': {
        'enabled': 'Yes',
        'provider': 'Interac e-Transfer',
        'cashEnabled': 'Yes',
      },
      'availability': {
        'hours': [
          {
            'day': 'Lunes',
            'open': '9:00 AM',
            'close': '6:00 PM',
            'active': 'Yes',
          },
        ],
        'blocks': [],
      },
      'logs': [
        {'action': 'LOGIN', 'timestamp': '2026-07-21', 'result': 'success'},
      ],
    };
  return controller;
}
