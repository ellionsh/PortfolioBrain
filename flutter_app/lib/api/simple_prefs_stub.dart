class SimplePrefs {
  static final Map<String, dynamic> _cache = {};

  static Future<String?> getString(String key) async {
    return _cache[key] as String?;
  }

  static Future<void> setString(String key, String value) async {
    _cache[key] = value;
  }

  static Future<int?> getInt(String key) async {
    return _cache[key] as int?;
  }

  static Future<void> setInt(String key, int value) async {
    _cache[key] = value;
  }

  static Future<bool?> getBool(String key) async {
    return _cache[key] as bool?;
  }

  static Future<void> setBool(String key, bool value) async {
    _cache[key] = value;
  }

  static Future<void> remove(String key) async {
    _cache.remove(key);
  }
}
