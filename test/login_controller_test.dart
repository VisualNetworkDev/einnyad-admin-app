import 'package:einnyad_admin_mobile/app_controller.dart';
import 'package:einnyad_admin_mobile/core/admin_api.dart';
import 'package:einnyad_admin_mobile/core/biometric_access.dart';
import 'package:einnyad_admin_mobile/core/session_store.dart';
import 'package:einnyad_admin_mobile/core/update_service.dart';
import 'package:einnyad_admin_mobile/core/value_helpers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApi extends AdminApi {
  AdminApiException? dataError;
  bool rejectLogin = false;
  int loginCalls = 0;
  int dataCalls = 0;
  @override
  Future<JsonMap> login(String email, String password) async {
    loginCalls++;
    if (rejectLogin) throw const AdminApiException('Acceso incorrecto.');
    expect(email, 'owner@example.com');
    expect(password, 'test-only-password');
    return {'sessionToken': 'valid-token', 'email': email, 'name': 'Owner'};
  }

  @override
  Future<JsonMap> call(
    String action, {
    JsonMap payload = const {},
    bool includeSession = true,
  }) async {
    if (action == 'getAdminData') {
      dataCalls++;
      if (dataError != null) throw dataError!;
    }
    return {};
  }
}

class FakeBiometrics extends BiometricAccess {
  bool enabled = false;
  bool cancel = false;
  int saves = 0;
  int reads = 0;
  @override
  Future<BiometricState> status() async =>
      BiometricState(available: true, enabled: enabled);
  @override
  Future<void> save(String email, String password) async {
    saves++;
    if (cancel) {
      throw const BiometricAccessException('Cancelado', cancelled: true);
    }
    enabled = true;
  }

  @override
  Future<SavedLogin> read() async {
    reads++;
    if (cancel) {
      throw const BiometricAccessException('Cancelado', cancelled: true);
    }
    return const SavedLogin('owner@example.com', 'test-only-password');
  }

  @override
  Future<void> delete() async {
    enabled = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionStore store;
  late FakeApi api;
  late FakeBiometrics biometrics;
  late AdminController controller;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = SessionStore();
    api = FakeApi();
    biometrics = FakeBiometrics();
    controller = AdminController(
      api,
      store,
      UpdateService(store),
      biometrics: biometrics,
    );
  });
  tearDown(() => controller.dispose());
  const saved = SavedSession(
    token: 'existing-token',
    email: 'owner@example.com',
    name: 'Owner',
  );

  test(
    'temporary 404 keeps saved session and retry needs no password',
    () async {
      await store.save(saved);
      api.dataError = const AdminApiException('404', httpStatus: 404);
      await controller.initialize();
      expect(controller.status, AdminStatus.connectionError);
      expect((await store.read())?.token, saved.token);
      api.dataError = null;
      await controller.retryConnection();
      expect(controller.status, AdminStatus.ready);
      expect(api.loginCalls, 0);
    },
  );

  test('expired session alone clears stored login session', () async {
    await store.save(saved);
    api.dataError = const AdminApiException(
      'Session expirada',
      sessionExpired: true,
    );
    await controller.initialize();
    expect(controller.status, AdminStatus.signedOut);
    expect(await store.read(), isNull);
    expect(controller.rememberedEmail, saved.email);
  });

  test('enabled biometrics prevent cold-start saved-session bypass', () async {
    await store.save(saved);
    biometrics.enabled = true;
    await controller.initialize();
    expect(controller.status, AdminStatus.signedOut);
    expect(api.dataCalls, 0);
    expect(api.sessionToken, isEmpty);
    expect(
      (await store.read())?.token,
      saved.token,
    ); // Background notifications.
    await controller.loginWithBiometrics();
    expect(biometrics.reads, 1);
    expect(api.loginCalls, 1);
    expect(controller.status, AdminStatus.ready);
  });

  test('cancelled quick login never calls backend', () async {
    biometrics.enabled = true;
    biometrics.cancel = true;
    await controller.initialize();
    await expectLater(
      controller.loginWithBiometrics(),
      throwsA(isA<BiometricAccessException>()),
    );
    expect(api.loginCalls, 0);
    expect(controller.status, AdminStatus.signedOut);
    expect(controller.busy, isFalse);
  });

  test('only verified credentials are enrolled', () async {
    await controller.initialize();
    api.rejectLogin = true;
    await expectLater(
      controller.login(
        'owner@example.com',
        'test-only-password',
        enableBiometrics: true,
      ),
      throwsA(isA<AdminApiException>()),
    );
    expect(biometrics.saves, 0);
    expect(await store.read(), isNull);
    api.rejectLogin = false;
    await controller.login(
      'owner@example.com',
      'test-only-password',
      enableBiometrics: true,
    );
    expect(biometrics.saves, 1);
    expect(controller.biometricState.enabled, isTrue);
    expect(controller.status, AdminStatus.ready);
  });

  test('cancelled enrollment does not reject a valid manual login', () async {
    await controller.initialize();
    biometrics.cancel = true;
    await controller.login(
      'owner@example.com',
      'test-only-password',
      enableBiometrics: true,
    );
    expect(controller.status, AdminStatus.ready);
    expect(controller.biometricState.enabled, isFalse);
    expect(controller.accessNotice, contains('no se activó'));
  });

  test(
    'data-load failure after valid login preserves verified session',
    () async {
      await controller.initialize();
      api.dataError = const AdminApiException('404', httpStatus: 404);
      await controller.login('owner@example.com', 'test-only-password');
      expect(controller.status, AdminStatus.connectionError);
      expect((await store.read())?.token, 'valid-token');
    },
  );

  test('logout retains quick login; forgetting removes it', () async {
    biometrics.enabled = true;
    await controller.initialize();
    await controller.loginWithBiometrics();
    await controller.logout();
    expect(await store.read(), isNull);
    expect(api.sessionToken, isEmpty);
    expect(controller.biometricState.enabled, isTrue);
    await controller.forgetBiometrics();
    expect(controller.biometricState.enabled, isFalse);
  });

  test(
    'forgetting quick access cannot expose a saved background session',
    () async {
      await store.save(saved);
      biometrics.enabled = true;
      await controller.initialize();
      await controller.forgetBiometrics();
      expect(await store.read(), isNull);
      expect(controller.status, AdminStatus.signedOut);
      expect(api.sessionToken, isEmpty);
      expect(api.dataCalls, 0);
    },
  );
}
