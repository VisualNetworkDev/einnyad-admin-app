import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedSession {
  const SavedSession({
    required this.token,
    required this.email,
    required this.name,
  });

  final String token;
  final String email;
  final String name;
}

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _tokenKey = 'einnyad_admin_session_token';
  static const _emailKey = 'einnyad_admin_email';
  static const _nameKey = 'einnyad_admin_name';
  static const updateUrlKey = 'einnyad_update_manifest_url';
  static const _seenAppointmentIdsKey =
      'einnyad_notification_seen_appointment_ids';
  static const _lastNotifiedUpdateKey = 'einnyad_notification_last_update';

  final FlutterSecureStorage _storage;

  Future<String> readEmail() async =>
      (await _storage.read(key: _emailKey))?.trim() ?? '';

  Future<SavedSession?> read() async {
    final values = await _storage.readAll();
    final token = values[_tokenKey]?.trim() ?? '';
    if (token.isEmpty) return null;
    return SavedSession(
      token: token,
      email: values[_emailKey]?.trim() ?? '',
      name: values[_nameKey]?.trim() ?? '',
    );
  }

  Future<void> save(SavedSession session) async {
    await Future.wait([
      _storage.write(key: _tokenKey, value: session.token),
      _storage.write(key: _emailKey, value: session.email),
      _storage.write(key: _nameKey, value: session.name),
    ]);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _nameKey),
    ]);
  }

  Future<String> readUpdateUrl() async =>
      (await _storage.read(key: updateUrlKey))?.trim() ?? '';

  Future<void> saveUpdateUrl(String value) async {
    final url = value.trim();
    if (url.isEmpty) {
      await _storage.delete(key: updateUrlKey);
    } else {
      await _storage.write(key: updateUrlKey, value: url);
    }
  }

  Future<Set<String>?> readSeenAppointmentIds() async {
    final raw = await _storage.read(key: _seenAppointmentIdsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    } on FormatException {
      return <String>{};
    }
  }

  Future<void> saveSeenAppointmentIds(Iterable<String> ids) async {
    final normalized =
        ids
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    await _storage.write(
      key: _seenAppointmentIdsKey,
      value: jsonEncode(normalized),
    );
  }

  Future<String> readLastNotifiedUpdate() async =>
      (await _storage.read(key: _lastNotifiedUpdateKey))?.trim() ?? '';

  Future<void> saveLastNotifiedUpdate(String value) =>
      _storage.write(key: _lastNotifiedUpdateKey, value: value.trim());
}
