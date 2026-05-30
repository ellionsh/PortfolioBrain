export 'simple_prefs_stub.dart'
    if (dart.library.html) 'simple_prefs_web.dart'
    if (dart.library.io) 'simple_prefs_io.dart';
