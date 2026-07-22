import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'value_helpers.dart';

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.sessionExpired = false});

  final String message;
  final bool sessionExpired;

  @override
  String toString() => message;
}

class AdminApi {
  AdminApi({http.Client? client, String? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = Uri.parse(endpoint ?? AppConfig.adminApiUrl);

  final http.Client _client;
  final Uri _endpoint;
  String sessionToken = '';

  Future<JsonMap> login(String email, String password) => call(
    'login',
    payload: {'email': email.trim(), 'password': password},
    includeSession: false,
  );

  Future<void> logout() async {
    if (sessionToken.isEmpty) return;
    try {
      await call('logout');
    } finally {
      sessionToken = '';
    }
  }

  Future<JsonMap> call(
    String action, {
    JsonMap payload = const {},
    bool includeSession = true,
  }) async {
    final body = <String, dynamic>{
      ...payload,
      if (includeSession && sessionToken.isNotEmpty)
        'sessionToken': sessionToken,
      'userAgent': AppConfig.userAgent,
    };
    try {
      final response = await _client
          .post(
            _endpoint,
            headers: const {'Accept': 'application/json'},
            body: {'action': action, 'payload': jsonEncode(body)},
          )
          .timeout(const Duration(seconds: 70));
      return _decodeResponse(response);
    } on AdminApiException {
      rethrow;
    } on TimeoutException {
      throw const AdminApiException(
        'La conexión tardó demasiado. Revisa internet e inténtalo otra vez.',
      );
    } on FormatException {
      throw const AdminApiException(
        'El servidor respondió con un formato inesperado.',
      );
    } catch (error) {
      throw AdminApiException('No se pudo conectar con el servidor: $error');
    }
  }

  Future<JsonMap> uploadImage(
    Uint8List jpegBytes, {
    required String fileName,
    required String context,
  }) async {
    if (jpegBytes.lengthInBytes > 6 * 1024 * 1024) {
      throw const AdminApiException('La imagen supera el límite de 6 MB.');
    }
    final requestId =
        'mobile_${DateTime.now().millisecondsSinceEpoch}_${jpegBytes.length}';
    final payload = {
      'sessionToken': sessionToken,
      'userAgent': AppConfig.userAgent,
      'fileName': fileName,
      'context': context,
      'dataUrl': 'data:image/jpeg;base64,${base64Encode(jpegBytes)}',
    };
    try {
      final response = await _client
          .post(
            _endpoint,
            headers: const {'Accept': 'text/html,application/json'},
            body: {
              'bridge': '1',
              'requestId': requestId,
              'action': 'uploadImage',
              'payload': jsonEncode(payload),
            },
          )
          .timeout(const Duration(seconds: 130));
      final raw = utf8.decode(response.bodyBytes);
      if (raw.trimLeft().startsWith('{')) {
        return _decodeEnvelope(jsonDecode(raw));
      }
      final match = RegExp(
        r'var payload=(\{.*?\});var targets=',
        dotAll: true,
      ).firstMatch(raw);
      if (match == null) {
        throw const AdminApiException(
          'El servidor no confirmó la subida de la imagen.',
        );
      }
      return _decodeEnvelope(jsonDecode(match.group(1)!));
    } on AdminApiException {
      rethrow;
    } on TimeoutException {
      throw const AdminApiException('La subida de imagen tardó demasiado.');
    } catch (error) {
      throw AdminApiException('No se pudo subir la imagen: $error');
    }
  }

  JsonMap _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw AdminApiException(
        'El servidor respondió con estado ${response.statusCode}.',
      );
    }
    return _decodeEnvelope(jsonDecode(utf8.decode(response.bodyBytes)));
  }

  JsonMap _decodeEnvelope(Object? decoded) {
    if (decoded is! Map) {
      throw const AdminApiException('Respuesta del servidor no válida.');
    }
    final envelope = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    if (envelope['success'] != true) {
      final message = textOf(
        envelope['message'],
        'La operación no se completó.',
      );
      final lower = message.toLowerCase();
      throw AdminApiException(
        message,
        sessionExpired:
            lower.contains('session expirada') ||
            lower.contains('session invalida') ||
            lower.contains('session requerida'),
      );
    }
    final data = envelope['data'];
    if (data == null) return <String, dynamic>{};
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return {'value': data};
  }

  void close() => _client.close();
}
