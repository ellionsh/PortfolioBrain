import 'simple_prefs.dart';

class AuthStorage {
  static const _accessTokenKey = 'pb_auth_token';
  static const _refreshTokenKey = 'pb_refresh_token';

  static Future<String?> loadAccessToken() async {
    final token = await SimplePrefs.getString(_accessTokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<String?> loadRefreshToken() async {
    final token = await SimplePrefs.getString(_refreshTokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await SimplePrefs.setString(_accessTokenKey, accessToken);
    await SimplePrefs.setString(_refreshTokenKey, refreshToken);
  }

  static Future<void> clearTokens() async {
    await SimplePrefs.remove(_accessTokenKey);
    await SimplePrefs.remove(_refreshTokenKey);
  }
}
