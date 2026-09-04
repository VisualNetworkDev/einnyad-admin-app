import 'package:flutter/foundation.dart';

import 'core/admin_api.dart';
import 'core/biometric_access.dart';
import 'core/session_store.dart';
import 'core/update_service.dart';
import 'core/value_helpers.dart';

enum AdminStatus { initializing, signedOut, ready }

class AdminController extends ChangeNotifier {
  AdminController(
    this._api,
    this._store,
    this._updates, {
    BiometricAccess? biometrics,
  }) : _biometrics = biometrics ?? BiometricAccess();

  final AdminApi _api;
  final SessionStore _store;
  final UpdateService _updates;
  final BiometricAccess _biometrics;

  BiometricState biometricState = const BiometricState();
  String rememberedEmail = '';

  AdminStatus status = AdminStatus.initializing;
  JsonMap data = {};
  SavedSession? session;
  bool busy = false;
  String busyMessage = 'Sincronizando…';
  String lastError = '';
  AppUpdate? availableUpdate;
  double updateProgress = 0;

  List<JsonMap> get appointments => mapsOf(data['appointments']);
  List<JsonMap> get services => mapsOf(data['services']);
  List<JsonMap> get promotions => mapsOf(data['promotions']);
  List<JsonMap> get reviews => mapsOf(data['reviews']);
  List<JsonMap> get logs => mapsOf(data['logs']);
  JsonMap get dashboard => mapOf(data['dashboard']);
  JsonMap get config => mapOf(data['config']);
  JsonMap get payments => mapOf(data['payments']);
  JsonMap get availability => mapOf(data['availability']);

  Future<void> initialize() async {
    rememberedEmail = await _store.readEmail();
    biometricState = await _biometrics.status();
    final saved = await _store.read();
    if (saved == null) {
      status = AdminStatus.signedOut;
      notifyListeners();
      return;
    }
    session = saved;
    _api.sessionToken = saved.token;
    try {
      data = await _api.call('getAdminData');
      status = AdminStatus.ready;
    } on AdminApiException {
      await _store.clear();
      session = null;
      _api.sessionToken = '';
      status = AdminStatus.signedOut;
    }
    notifyListeners();
  }

  Future<void> login(
    String email,
    String password, {
    bool enableBiometrics = false,
    bool fromBiometrics = false,
  }) async {
    if (busy) return;
    _setBusy(true, 'Verificando acceso…');
    try {
      final result = await _api.login(email, password);
      final saved = SavedSession(
        token: textOf(result['sessionToken']),
        email: textOf(result['email'], email.trim()),
        name: textOf(result['name'], 'Dueña'),
      );
      if (saved.token.isEmpty) {
        throw const AdminApiException('No se recibió una sesión válida.');
      }
      session = saved;
      _api.sessionToken = saved.token;
      await _store.save(saved);
      data = await _api.call('getAdminData');

      if (!fromBiometrics && biometricState.available) {
        try {
          if (enableBiometrics) {
            await _biometrics.save(saved.email, password);
          } else if (biometricState.enabled) {
            await _biometrics.delete();
          }
        } on BiometricAccessException {
          // A cancelled/unavailable biometric prompt must not reject a valid login.
        }
        biometricState = await _biometrics.status();
      }

      status = AdminStatus.ready;
      lastError = '';
    } catch (error) {
      lastError = error.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> loginWithBiometrics() async {
    if (busy) return;
    _setBusy(true, 'Verificando tu identidad…');
    try {
      final credentials = await _biometrics.read();
      _setBusy(false);
      await login(
        credentials.email,
        credentials.password,
        fromBiometrics: true,
      );
    } catch (_) {
      _setBusy(false);
      rethrow;
    }
  }

  Future<void> forgetBiometrics() async {
    if (busy) return;
    await _biometrics.delete();
    biometricState = await _biometrics.status();
    notifyListeners();
  }

  Future<void> logout() async {
    _setBusy(true, 'Cerrando sesión…');
    try {
      await _api.logout();
    } catch (_) {
      // The local session is still removed if the network is unavailable.
    } finally {
      await _store.clear();
      session = null;
      data = {};
      status = AdminStatus.signedOut;
      _setBusy(false);
    }
  }

  Future<void> refresh({String message = 'Actualizando datos…'}) async {
    _setBusy(true, message);
    try {
      data = await _api.call('getAdminData');
      lastError = '';
    } on AdminApiException catch (error) {
      if (error.sessionExpired) await _expireSession();
      lastError = error.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<JsonMap> action(
    String action, {
    JsonMap payload = const {},
    String message = 'Guardando cambios…',
    bool refreshAfter = true,
  }) async {
    _setBusy(true, message);
    try {
      final result = await _api.call(action, payload: payload);
      if (refreshAfter) data = await _api.call('getAdminData');
      lastError = '';
      return result;
    } on AdminApiException catch (error) {
      if (error.sessionExpired) await _expireSession();
      lastError = error.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<JsonMap> uploadImage(
    Uint8List bytes, {
    required String fileName,
    required String context,
  }) async {
    _setBusy(true, 'Subiendo imagen…');
    try {
      return await _api.uploadImage(
        bytes,
        fileName: fileName,
        context: context,
      );
    } on AdminApiException catch (error) {
      if (error.sessionExpired) await _expireSession();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<String> updateManifestUrl() => _updates.manifestUrl();

  Future<void> saveUpdateManifestUrl(String value) async {
    await _updates.saveManifestUrl(value);
    availableUpdate = null;
    notifyListeners();
  }

  Future<AppUpdate?> checkForUpdate() async {
    _setBusy(true, 'Buscando actualización…');
    try {
      availableUpdate = await _updates.check();
      return availableUpdate;
    } finally {
      _setBusy(false);
    }
  }

  Future<String> installUpdate(AppUpdate update) async {
    updateProgress = 0;
    _setBusy(true, 'Preparando actualización…');
    try {
      return await _updates.install(
        update,
        onProgress: (progress) {
          updateProgress = progress;
          busyMessage = 'Descargando ${(progress * 100).round()}%…';
          notifyListeners();
        },
      );
    } finally {
      updateProgress = 0;
      _setBusy(false);
    }
  }

  Future<void> _expireSession() async {
    await _store.clear();
    session = null;
    data = {};
    _api.sessionToken = '';
    status = AdminStatus.signedOut;
    notifyListeners();
  }

  void _setBusy(bool value, [String? message]) {
    busy = value;
    if (message != null) busyMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.close();
    _updates.close();
    super.dispose();
  }
}
