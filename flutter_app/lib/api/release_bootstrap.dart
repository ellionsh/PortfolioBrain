import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_server_config.dart';
import 'auth_storage.dart';

class ReleaseBootstrap {
  static const _releaseInitKey = 'pb_release_init_done';
  static const _clearOnRelease = bool.fromEnvironment(
    'PB_CLEAR_RELEASE_PREFS',
    defaultValue: false,
  );

  static Future<void> ensureCleanStart() async {
    if (!kReleaseMode || !_clearOnRelease) return;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_releaseInitKey) ?? false;
    if (done) return;
    await AuthStorage.clearToken();
    await ApiServerConfig.clear();
    await prefs.setBool(_releaseInitKey, true);
  }
}
