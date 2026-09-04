import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class BiometricState {
  const BiometricState({this.available = false, this.enabled = false});
  final bool available;
  final bool enabled;
}

class SavedLogin {
  const SavedLogin(this.email, this.password);
  final String email;
  final String password;
}

class BiometricAccessException implements Exception {
  const BiometricAccessException(
    this.message, {
    this.cancelled = false,
    this.requiresPassword = false,
  });
  final String message;
  final bool cancelled;
  final bool requiresPassword;
  @override
  String toString() => message;
}

/// Android encrypts the credentials with a per-use biometric Keystore key.
/// The ordinary session remains separate so background notifications can run.
class BiometricAccess {
  BiometricAccess({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('einnyad/biometric_access');

  final MethodChannel _channel;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<BiometricState> status() async {
    if (!supported) return const BiometricState();
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('status');
      return BiometricState(
        available: result?['available'] == true,
        enabled: result?['enabled'] == true,
      );
    } on PlatformException {
      // Do not bypass a previously enabled gate if the platform cannot report it.
      return const BiometricState(enabled: true);
    } on MissingPluginException {
      return const BiometricState();
    }
  }

  Future<void> save(String email, String password) =>
      _invoke<void>('save', {'email': email, 'password': password});

  Future<SavedLogin> read() async {
    final result = await _invoke<dynamic>('read');
    if (result is! Map ||
        result['email'] is! String ||
        result['password'] is! String) {
      throw const BiometricAccessException(
        'Entra con contraseña y activa el acceso rápido otra vez.',
      );
    }
    return SavedLogin(result['email'] as String, result['password'] as String);
  }

  Future<void> delete() => _invoke<void>('delete');

  Future<T?> _invoke<T>(String method, [Map<String, String>? arguments]) async {
    if (!supported) {
      throw const BiometricAccessException(
        'El acceso rápido está disponible en Android compatible.',
      );
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      throw BiometricAccessException(
        error.message ??
            'No se pudo verificar tu identidad. Usa tu contraseña.',
        cancelled: error.code == 'cancelled',
        requiresPassword:
            error.code == 'invalidated' || error.code == 'missing',
      );
    } on MissingPluginException {
      throw const BiometricAccessException(
        'Actualiza la app para usar el acceso rápido.',
      );
    }
  }
}
