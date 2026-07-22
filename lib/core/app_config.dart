import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const appName = 'EinnyadNails Admin';
  static const businessName = 'EinnyadNails';
  static const currency = 'CAD';
  static const adminApiUrl = String.fromEnvironment(
    'EINNYAD_ADMIN_API_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbz1hX9WxBlPpAvrkn3_cZkWPTd6z6Uh1m0IpxaSDgtTzR1CN9yuKjKCCqOlaHQplK4J/exec',
  );
  static const defaultUpdateManifestUrl = String.fromEnvironment(
    'EINNYAD_UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/VisualNetworkDev/einnyad-admin-app/main/update-manifest.json',
  );

  static String get userAgent =>
      'EinnyadAdminMobile/1.0 (${defaultTargetPlatform.name})';
}
