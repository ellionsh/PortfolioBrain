import 'dart:convert';
import 'dart:html';

class SimplePrefs {
  static const String _storageKey = 'pb_prefs';
  static Map<String, dynamic>? _cache;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final raw = window.localStorage[_storageKey];
    if (raw == null || raw.isEmpty) {
      _cache = {};
    } else {
      _cache = jsonDecode(raw) as Map<String, dynamic>;
    }
  }

  static Future<void> _save() async {
    await _ensureLoaded();
    window.localStorage[_storageKey] = jsonEncode(_cache);
  }

  static Future<String?> getString(String key) async {
    await _ensureLoaded();
    return _cache![key] as String?;
  }

  static Future<void> setString(String key, String value) async {
    await _ensureLoaded();
    _cache![key] = value;
    await _save();
  }

  static Future<int?> getInt(String key) async {
    await _ensureLoaded();
    final value = _cache![key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static Future<void> setInt(String key, int value) async {
    await _ensureLoaded();
    _cache![key] = value;
    await _save();
  }

  static Future<bool?> getBool(String key) async {
    await _ensureLoaded();
    return _cache![key] as bool?;
  }

  static Future<void> setBool(String key, bool value) async {
    await _ensureLoaded();
    _cache![key] = value;
    await _save();
  }

  static Future<void> remove(String key) async {
    await _ensureLoaded();
    _cache!.remove(key);
    await _save();
  }
}
