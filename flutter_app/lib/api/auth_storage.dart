import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'pb_auth_token';
  static const _refreshTokenKey = 'pb_refresh_token';

  static Future<String?> loadAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_accessTokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<String?> loadRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_refreshTokenKey);
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
