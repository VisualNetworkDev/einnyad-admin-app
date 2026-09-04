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
      final response = await _postForm({
        'mobile': '1',
        'action': action,
        'payload': jsonEncode(body),
      }, timeout: const Duration(seconds: 70));
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
    final payload = {
      'sessionToken': sessionToken,
      'userAgent': AppConfig.userAgent,
      'fileName': fileName,
      'context': context,
      'dataUrl': 'data:image/jpeg;base64,${base64Encode(jpegBytes)}',
    };
    try {
      final response = await _postForm({
        'mobile': '1',
        'action': 'uploadImage',
        'payload': jsonEncode(payload),
      }, timeout: const Duration(seconds: 130));
      return _decodeResponse(response);
    } on AdminApiException {
      rethrow;
    } on TimeoutException {
      throw const AdminApiException('La subida de imagen tardó demasiado.');
    } on FormatException {
      throw const AdminApiException(
        'El servidor no confirmó la subida de la imagen.',
      );
    } catch (error) {
      throw AdminApiException('No se pudo subir la imagen: $error');
    }
  }

  Future<http.Response> _postForm(
    Map<String, String> fields, {
    required Duration timeout,
  }) async {
    var uri = _endpoint;
    var method = 'POST';
    for (var redirects = 0; redirects <= 5; redirects += 1) {
      final request = http.Request(method, uri)
        ..followRedirects = false
        ..maxRedirects = 0
        ..headers['Accept'] = 'application/json';
      if (method == 'POST') request.bodyFields = fields;

      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      if (!_isRedirect(response.statusCode)) return response;

      if (redirects == 5) {
        throw const AdminApiException(
          'El servidor realizó demasiadas redirecciones.',
        );
      }
      final location = response.headers['location'];
      final redirect = location == null ? null : uri.resolve(location);
      if (redirect == null || !_isAllowedRedirect(redirect)) {
        throw const AdminApiException(
          'El servidor devolvió una redirección no válida.',
        );
      }
      uri = redirect;
      if (response.statusCode == 301 ||
          response.statusCode == 302 ||
          response.statusCode == 303) {
        method = 'GET';
      }
    }
    throw const AdminApiException('No se pudo completar la solicitud.');
  }

  bool _isAllowedRedirect(Uri redirect) {
    if (redirect.scheme != 'https' || !redirect.hasAuthority) return false;
    if (redirect.host == _endpoint.host) return true;
    if (_endpoint.host != 'script.google.com') return false;
    return redirect.host == 'script.googleusercontent.com' ||
        redirect.host.endsWith('.script.googleusercontent.com') ||
        redirect.host.endsWith('-script.googleusercontent.com');
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  JsonMap _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw AdminApiException(
        'El servidor respondió con estado ${response.statusCode}.',
      );
    }
    final raw = utf8.decode(response.bodyBytes);
    try {
      return _decodeEnvelope(jsonDecode(raw));
    } on FormatException {
      throw const AdminApiException(
        'El servidor no devolvió JSON. Actualiza la app o revisa el deployment del Admin API.',
      );
    }
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
