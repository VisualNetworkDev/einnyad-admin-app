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

  final FlutterSecureStorage _storage;

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
}
