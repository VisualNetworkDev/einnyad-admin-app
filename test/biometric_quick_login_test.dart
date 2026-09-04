import 'package:einnyad_admin_mobile/app_controller.dart';
import 'package:einnyad_admin_mobile/core/admin_api.dart';
import 'package:einnyad_admin_mobile/core/biometric_access.dart';
import 'package:einnyad_admin_mobile/core/session_store.dart';
import 'package:einnyad_admin_mobile/core/update_service.dart';
import 'package:einnyad_admin_mobile/core/value_helpers.dart';
import 'package:einnyad_admin_mobile/screens/login_screen.dart';
import 'package:einnyad_admin_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApi extends AdminApi {
  int loginCalls = 0;

  @override
  Future<JsonMap> login(String email, String password) async {
    loginCalls += 1;
    expect(email, 'owner@example.com');
    expect(password, 'test-only-password');
    return {'sessionToken': 'session-token', 'email': email, 'name': 'Dueña'};
  }

  @override
  Future<JsonMap> call(
    String action, {
    JsonMap payload = const {},
    bool includeSession = true,
  }) async => {
    'dashboard': {'active': 7},
    'appointments': [
      {'id': 'appointment-1'},
    ],
    'services': [
      {'id': 'service-1'},
    ],
    'config': {'businessName': 'EinnyadNails'},
  };
}

class _FakeBiometrics extends BiometricAccess {
  bool enabled = false;
  bool cancelled = false;
  int reads = 0;
  int saves = 0;

  @override
  Future<BiometricState> status() async =>
      BiometricState(available: true, enabled: enabled);

  @override
  Future<void> save(String email, String password) async {
    saves += 1;
    enabled = true;
  }

  @override
  Future<SavedLogin> read() async {
    reads += 1;
    if (cancelled) {
      throw const BiometricAccessException(
        'Verificación cancelada.',
        cancelled: true,
      );
    }
    return const SavedLogin('owner@example.com', 'test-only-password');
  }

  @override
  Future<void> delete() async => enabled = false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionStore store;
  late _FakeApi api;
  late _FakeBiometrics biometrics;
  late AdminController controller;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = SessionStore();
    api = _FakeApi();
    biometrics = _FakeBiometrics();
    controller = AdminController(
      api,
      store,
      UpdateService(store),
      biometrics: biometrics,
    );
  });

  tearDown(() => controller.dispose());

  test('restores the original 1.0.3 saved-session behavior', () async {
    await store.save(
      const SavedSession(
        token: 'existing-token',
        email: 'owner@example.com',
        name: 'Dueña',
      ),
    );
    await controller.initialize();
    expect(controller.status, AdminStatus.ready);
    expect(controller.appointments, hasLength(1));
    expect(controller.services, hasLength(1));
    expect(controller.config['businessName'], 'EinnyadNails');
    expect(biometrics.reads, 0);
  });

  test('enrolls biometrics only after a complete valid login', () async {
    await controller.initialize();
    await controller.login(
      'owner@example.com',
      'test-only-password',
      enableBiometrics: true,
    );
    expect(api.loginCalls, 1);
    expect(biometrics.saves, 1);
    expect(biometrics.enabled, isTrue);
    expect(controller.status, AdminStatus.ready);
    expect(controller.appointments, hasLength(1));
  });

  test(
    'quick login uses biometrics and then the original backend login',
    () async {
      biometrics.enabled = true;
      await controller.initialize();
      await controller.loginWithBiometrics();
      expect(biometrics.reads, 1);
      expect(api.loginCalls, 1);
      expect(controller.status, AdminStatus.ready);
      expect(controller.services, hasLength(1));
    },
  );

  test('cancelled biometric prompt never calls the backend', () async {
    biometrics.enabled = true;
    biometrics.cancelled = true;
    await controller.initialize();
    await expectLater(
      controller.loginWithBiometrics(),
      throwsA(isA<BiometricAccessException>()),
    );
    expect(api.loginCalls, 0);
    expect(controller.busy, isFalse);
  });

  testWidgets('quick-login form fits a narrow Android screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    biometrics.enabled = true;
    controller.biometricState = const BiometricState(
      available: true,
      enabled: true,
    );
    controller.rememberedEmail = 'owner@example.com';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: LoginScreen(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text('Entrar con huella o rostro'), findsOneWidget);
    expect(find.text('Entrar al panel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
