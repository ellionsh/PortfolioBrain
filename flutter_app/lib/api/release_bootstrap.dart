import 'package:flutter/foundation.dart';

import 'api_server_config.dart';
import 'auth_storage.dart';
import 'simple_prefs.dart';

class ReleaseBootstrap {
  static const _releaseInitKey = 'pb_release_init_done';
  static const _clearOnRelease = bool.fromEnvironment(
    'PB_CLEAR_RELEASE_PREFS',
    defaultValue: false,
  );

  static Future<void> ensureCleanStart() async {
    if (!kReleaseMode || !_clearOnRelease) return;
    final done = await SimplePrefs.getBool(_releaseInitKey) ?? false;
    if (done) return;
    await AuthStorage.clearTokens();
    await ApiServerConfig.clear();
    await SimplePrefs.setBool(_releaseInitKey, true);
  }
}
