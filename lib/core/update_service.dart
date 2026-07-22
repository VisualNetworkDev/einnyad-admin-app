import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_config.dart';
import 'session_store.dart';
import 'value_helpers.dart';

class AppUpdate {
  const AppUpdate({
    required this.currentVersion,
    required this.currentBuild,
    required this.version,
    required this.buildNumber,
    required this.releaseNotes,
    required this.required,
    required this.downloadUrl,
    required this.sha256,
    required this.altStoreSourceUrl,
  });

  final String currentVersion;
  final int currentBuild;
  final String version;
  final int buildNumber;
  final String releaseNotes;
  final bool required;
  final String downloadUrl;
  final String sha256;
  final String altStoreSourceUrl;

  bool get available =>
      compareVersions(version, currentVersion) > 0 ||
      (compareVersions(version, currentVersion) == 0 &&
          buildNumber > currentBuild);
}

class UpdateService {
  UpdateService(this._store, {http.Client? client})
    : _client = client ?? http.Client();

  final SessionStore _store;
  final http.Client _client;

  Future<String> manifestUrl() async {
    final saved = await _store.readUpdateUrl();
    return saved.isNotEmpty ? saved : AppConfig.defaultUpdateManifestUrl;
  }

  Future<void> saveManifestUrl(String url) => _store.saveUpdateUrl(url);

  Future<AppUpdate?> check() async {
    final source = await manifestUrl();
    final uri = Uri.tryParse(source);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw const FormatException(
        'Configura una URL HTTPS para el manifiesto de actualizaciones.',
      );
    }
    final response = await _client
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'El manifiesto respondió con estado ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map) throw const FormatException('Manifiesto no válido.');
    final manifest = mapOf(decoded);
    final platform = Platform.isAndroid
        ? mapOf(manifest['android'])
        : Platform.isIOS
        ? mapOf(manifest['ios'])
        : <String, dynamic>{};
    if (platform.isEmpty) return null;
    final package = await PackageInfo.fromPlatform();
    final version = textOf(platform['version'], textOf(manifest['version']));
    final build = intOf(
      platform['buildNumber'],
      intOf(manifest['buildNumber']),
    );
    if (version.isEmpty || build < 1) {
      throw const FormatException(
        'El manifiesto necesita version y buildNumber.',
      );
    }
    final update = AppUpdate(
      currentVersion: package.version,
      currentBuild: int.tryParse(package.buildNumber) ?? 0,
      version: version,
      buildNumber: build,
      releaseNotes: textOf(
        platform['releaseNotes'],
        textOf(manifest['releaseNotes']),
      ),
      required: platform['required'] == true || manifest['required'] == true,
      downloadUrl: textOf(platform['downloadUrl']),
      sha256: textOf(platform['sha256']).toLowerCase(),
      altStoreSourceUrl: textOf(platform['altStoreSourceUrl']),
    );
    return update.available ? update : null;
  }

  Future<String> install(
    AppUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isIOS) {
      final target = update.altStoreSourceUrl.isNotEmpty
          ? update.altStoreSourceUrl
          : update.downloadUrl;
      final uri = Uri.tryParse(target);
      if (uri == null || uri.scheme != 'https') {
        throw const FormatException(
          'La actualización de iOS necesita la URL HTTPS del Source de AltStore.',
        );
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw Exception('No se pudo abrir AltStore o el enlace de IPA.');
      }
      return 'AltStore abierto. En Mis apps, pulsa Update para instalarla.';
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('Actualización disponible solo en Android/iOS.');
    }
    final uri = Uri.tryParse(update.downloadUrl);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Falta la URL HTTPS del APK.');
    }
    final request = http.Request('GET', uri);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'No se pudo descargar el APK (${response.statusCode}).',
      );
    }
    final total = response.contentLength ?? 0;
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      bytes.addAll(chunk);
      if (total > 0) onProgress?.call(bytes.length / total);
    }
    if (update.sha256.isNotEmpty) {
      final actual = sha256.convert(bytes).toString();
      if (actual != update.sha256) {
        throw const FormatException(
          'El APK descargado no coincide con su firma SHA-256.',
        );
      }
    }
    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}/EinnyadNails-Admin-${update.version}.apk');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
    return 'APK verificado. Confirma la instalación en Android.';
  }

  void close() => _client.close();
}

int compareVersions(String left, String right) {
  List<int> parts(String value) => value
      .split(RegExp(r'[-+]'))
      .first
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  final a = parts(left);
  final b = parts(right);
  final count = a.length > b.length ? a.length : b.length;
  for (var index = 0; index < count; index += 1) {
    final av = index < a.length ? a[index] : 0;
    final bv = index < b.length ? b[index] : 0;
    if (av != bv) return av.compareTo(bv);
  }
  return 0;
}
