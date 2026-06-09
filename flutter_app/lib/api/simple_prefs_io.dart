import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SimplePrefs {
  static const _prefsFileName = 'pb_prefs.json';
  static Map<String, dynamic>? _cache;
  static File? _file;

  static Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _file = File('${dir.path}/$_prefsFileName');
    final legacyFile = File('${Directory.systemTemp.path}/$_prefsFileName');
    if (!await _file!.exists() && await legacyFile.exists()) {
      try {
        await legacyFile.copy(_file!.path);
      } catch (_) {
        // If migration fails, fall back to an empty preference store.
      }
    }
    if (await _file!.exists()) {
      final content = await _file!.readAsString();
      _cache = jsonDecode(content) as Map<String, dynamic>;
    } else {
      _cache = {};
    }
  }

  static Future<void> _save() async {
    await _ensureLoaded();
    await _file!.writeAsString(jsonEncode(_cache));
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
    return _cache![key] as int?;
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
