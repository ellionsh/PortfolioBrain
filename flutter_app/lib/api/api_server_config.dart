import 'simple_prefs.dart';

class ApiServerConfig {
  static const _hostKey = 'api_server_host';
  static const _portKey = 'api_server_port';
  static const _schemeKey = 'api_server_scheme';

  final String host;
  final int port;
  final String scheme;
  final bool isConfigured;

  const ApiServerConfig({
    required this.host,
    required this.port,
    required this.scheme,
    required this.isConfigured,
  });

  String get baseUrl => '$scheme://$host:$port';

  static const defaults = ApiServerConfig(
    host: '192.168.71.31',
    port: 5000,
    scheme: 'http',
    isConfigured: false,
  );

  static Future<ApiServerConfig> load() async {
    final host = await SimplePrefs.getString(_hostKey);
    final port = await SimplePrefs.getInt(_portKey);
    final scheme = await SimplePrefs.getString(_schemeKey) ?? defaults.scheme;

    if (host == null || host.trim().isEmpty || port == null) {
      return defaults;
    }

    return ApiServerConfig(
      host: host,
      port: port,
      scheme: scheme,
      isConfigured: true,
    );
  }

  static Future<ApiServerConfig> save({
    required String host,
    required int port,
    String scheme = 'http',
  }) async {
    final normalizedHost = host.trim().replaceAll(RegExp(r'^https?://'), '');
    final config = ApiServerConfig(
      host: normalizedHost,
      port: port,
      scheme: scheme,
      isConfigured: true,
    );

    await SimplePrefs.setString(_hostKey, config.host);
    await SimplePrefs.setInt(_portKey, config.port);
    await SimplePrefs.setString(_schemeKey, config.scheme);
    return config;
  }

  static Future<void> clear() async {
    await SimplePrefs.remove(_hostKey);
    await SimplePrefs.remove(_portKey);
    await SimplePrefs.remove(_schemeKey);
  }
}
